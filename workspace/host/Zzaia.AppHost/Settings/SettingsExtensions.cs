using Microsoft.Extensions.Configuration;

namespace Zzaia.AppHost.Settings;

/// <summary>
/// Extension methods for configuring AppHost settings.
/// </summary>
public static class SettingsExtensions
{
    /// <summary>
    /// Loads AppHost settings from configuration.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <returns>The AppHost settings instance.</returns>
    public static AppHostSettings LoadSettings(this IDistributedApplicationBuilder builder)
    {
        string localSettingsPath = Path.Combine(builder.AppHostDirectory, "appsettings.Local.json");
        builder.Configuration.AddJsonFile(localSettingsPath, optional: true);

        AppHostSettings settings = new();
        builder.Configuration.GetSection(AppHostSettings.SectionName).Bind(settings);
        return settings;
    }

    /// <summary>
    /// Configures a PostgreSQL resource with settings.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="settings">The PostgreSQL settings.</param>
    /// <returns>The PostgreSQL resource builder.</returns>
    public static IResourceBuilder<PostgresServerResource> AddPostgresWithSettings(
        this IDistributedApplicationBuilder builder,
        PostgresSettings settings)
    {
        return builder.AddPostgres(settings.ResourceName)
            .WithImage(settings.Image)
            .WithImageTag(settings.Tag)
            .WithLifetime(ContainerLifetime.Persistent);
    }

    /// <summary>
    /// Adds a PostgreSQL database with MCP support.
    /// </summary>
#pragma warning disable ASPIREPOSTGRES001
    public static IResourceBuilder<PostgresDatabaseResource> AddDatabaseWithMcp(
        this IResourceBuilder<PostgresServerResource> postgres,
        string databaseResourceName,
        string databaseName)
    {
        return postgres.AddDatabase(databaseResourceName, databaseName).WithPostgresMcp();
    }
#pragma warning restore ASPIREPOSTGRES001

    /// <summary>
    /// Configures a Redis resource with settings.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="settings">The Redis settings.</param>
    /// <returns>The Redis resource builder.</returns>
    public static IResourceBuilder<RedisResource> AddRedisWithSettings(
        this IDistributedApplicationBuilder builder,
        RedisSettings settings)
    {
        return builder.AddRedis(settings.ResourceName)
            .WithImage(settings.Image)
            .WithImageTag(settings.Tag)
            .WithLifetime(ContainerLifetime.Persistent);
    }

    /// <summary>
    /// Adds an MCP proxy sidecar exposing Redis to MCP-capable clients.
    /// </summary>
    public static IResourceBuilder<RedisResource> WithRedisMcp(
        this IResourceBuilder<RedisResource> redis,
        IDistributedApplicationBuilder builder)
    {
#pragma warning disable ASPIREMCP001
        builder.AddContainer("redis-mcp-server", "node", "22-alpine")
            .WithArgs("sh", "-c",
                "H=$(echo $REDIS_CONN | cut -d: -f1) && " +
                "P=$(echo $REDIS_CONN | cut -d: -f2 | cut -d, -f1) && " +
                "PW=$(echo $REDIS_CONN | sed 's/.*password=//;s/,.*//' ) && " +
                "if echo $REDIS_CONN | grep -q ssl=true; then SCHEME=rediss; else SCHEME=redis; fi && " +
                "npx -y supergateway --port 8080 --stdio \"npx -y @modelcontextprotocol/server-redis ${SCHEME}://:${PW}@${H}:${P}\"")
            .WithHttpEndpoint(targetPort: 8080, name: "http")
            .WithEnvironment("REDIS_CONN", redis.Resource.ConnectionStringExpression)
            .WithEnvironment("NODE_TLS_REJECT_UNAUTHORIZED", "0")
            .WaitFor(redis)
            .WithMcpServer();
#pragma warning restore ASPIREMCP001

        return redis;
    }

    /// <summary>
    /// Configures a RabbitMQ resource with settings.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="settings">The RabbitMQ settings.</param>
    /// <returns>The RabbitMQ resource builder.</returns>
    public static IResourceBuilder<RabbitMQServerResource> AddRabbitMqWithSettings(
        this IDistributedApplicationBuilder builder,
        RabbitMqSettings settings)
    {
        IResourceBuilder<ParameterResource> username = builder.AddParameter("rabbitmq-username", settings.Username);
        IResourceBuilder<ParameterResource> password = builder.AddParameter("rabbitmq-password", settings.Password, secret: true);
        IResourceBuilder<ParameterResource> hostParameter = builder.AddParameter("rabbitmq-host", settings.Host);
        IResourceBuilder<ParameterResource> portParameter = builder.AddParameter("rabbitmq-port", settings.Port);
        return builder.AddRabbitMQ(settings.ResourceName, username, password)
            .WithImage(settings.Image)
            .WithImageTag(settings.Tag)
            .WithEndpoint("tcp", endpoint => endpoint.Port = int.Parse(settings.Port))
            .WithLifetime(ContainerLifetime.Persistent);
    }

    /// <summary>
    /// Loads per-application settings from Applications/{folder}/appsettings.json.
    /// </summary>
    /// <typeparam name="T">The settings type to deserialize.</typeparam>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="folder">The application subfolder name.</param>
    /// <returns>The deserialized settings instance.</returns>
    public static T LoadApplicationSettings<T>(this IDistributedApplicationBuilder builder, string folder) where T : new()
    {
        string path = Path.Combine(builder.AppHostDirectory, "Applications", folder, "appsettings.json");
        IConfigurationRoot config = new ConfigurationBuilder().AddJsonFile(path).Build();
        T settings = new();
        config.Bind(settings);
        return settings;
    }

    /// <summary>
    /// Applies environment variables parsed from a .env file, if it exists.
    /// </summary>
    /// <typeparam name="T">The resource type.</typeparam>
    /// <param name="builder">The resource builder.</param>
    /// <param name="envFilePath">The path to the .env file.</param>
    /// <returns>The resource builder with applied environment variables.</returns>
    public static IResourceBuilder<T> WithEnvFile<T>(this IResourceBuilder<T> builder, string envFilePath) where T : IResourceWithEnvironment
    {
        if (!File.Exists(envFilePath)) return builder;
        string[] lines = File.ReadAllLines(envFilePath);
        foreach (string line in lines)
        {
            if (string.IsNullOrWhiteSpace(line) || line.TrimStart().StartsWith('#')) continue;
            int eq = line.IndexOf('=');
            if (eq <= 0) continue;
            builder = builder.WithEnvironment(line[..eq].Trim(), line[(eq + 1)..].Trim());
        }
        return builder;
    }

    /// <summary>
    /// Applies a dictionary of environment variables to a resource.
    /// </summary>
    /// <typeparam name="T">The resource type.</typeparam>
    /// <param name="builder">The resource builder.</param>
    /// <param name="env">The environment variable dictionary.</param>
    /// <returns>The resource builder with applied environment variables.</returns>
    public static IResourceBuilder<T> WithEnvSettings<T>(this IResourceBuilder<T> builder, Dictionary<string, string> env) where T : IResourceWithEnvironment
    {
        foreach ((string key, string value) in env)
            builder = builder.WithEnvironment(key, value);
        return builder;
    }
}
