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
}
