using Zzaia.AppHost.Settings;

namespace Zzaia.AppHost.Applications;

/// <summary>
/// Extension methods for configuring Domain Service application resources in the application host.
/// </summary>
public static class ApplicationInjection
{
    /// <summary>
    /// Adds the Domain Service API and Background Services to the distributed application.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="postgres">The PostgreSQL server resource builder.</param>
    /// <param name="redis">The Redis resource builder.</param>
    /// <param name="rabbitMq">The RabbitMQ server resource builder.</param>
    /// <param name="rabbitMqSettings">The RabbitMQ configuration settings.</param>
    /// <param name="settings">The Domain Service configuration settings.</param>
    /// <returns>The distributed application builder for chaining.</returns>
    public static IDistributedApplicationBuilder AddDomainServiceApplication(
        this IDistributedApplicationBuilder builder,
        IResourceBuilder<PostgresServerResource> postgres,
        IResourceBuilder<RedisResource> redis,
        IResourceBuilder<RabbitMQServerResource> rabbitMq,
        RabbitMqSettings rabbitMqSettings,
        DomainServiceSettings settings)
    {

        // IResourceBuilder<PostgresDatabaseResource> orderDatabase = postgres.AddDatabase(settings.DatabaseResourceName, settings.DatabaseName);
        // builder.AddProject<Projects.DomainService_API>(settings.ApiResourceName)
        //     .WithReference(orderDatabase)
        //     .WithReference(rabbitMq)
        //     .WithReference(redis)
        //     .WithEnvironment("RabbitMQ__Host", rabbitMqSettings.Host)
        //     .WithEnvironment("RabbitMQ__Port", rabbitMqSettings.Port)
        //     .WithEnvironment("RabbitMQ__Username", rabbitMqSettings.Username)
        //     .WithEnvironment("RabbitMQ__Password", rabbitMqSettings.Password)
        //     .WaitFor(orderDatabase)
        //     .WaitFor(redis)
        //     .WaitFor(rabbitMq);
        // builder.AddProject<Projects.DomainService_BackgroundServices>(settings.BackgroundResourceName)
        //     .WithReference(orderDatabase)
        //     .WithReference(rabbitMq)
        //     .WithReference(redis)
        //     .WithEnvironment("RabbitMQ__Host", rabbitMqSettings.Host)
        //     .WithEnvironment("RabbitMQ__Port", rabbitMqSettings.Port)
        //     .WithEnvironment("RabbitMQ__Username", rabbitMqSettings.Username)
        //     .WithEnvironment("RabbitMQ__Password", rabbitMqSettings.Password)
        //     .WaitFor(orderDatabase)
        //     .WaitFor(redis)
        //     .WaitFor(rabbitMq);

        return builder;
    }
}
