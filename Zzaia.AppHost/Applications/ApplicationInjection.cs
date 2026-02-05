namespace Zzaia.AppHost.Applications;

/// <summary>
/// Extension methods for configuring example application resources in the application host.
/// </summary>
public static class ApplicationInjection
{
    /// <summary>
    /// Adds the example application API and Background Services to the distributed application.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="postgres">The PostgreSQL server resource builder.</param>
    /// <param name="redis">The Redis resource builder.</param>
    /// <param name="rabbitMq">The RabbitMQ server resource builder.</param>
    /// <returns>The distributed application builder for chaining.</returns>
    public static IDistributedApplicationBuilder AddExampleApplication(
        this IDistributedApplicationBuilder builder,
        IResourceBuilder<PostgresServerResource> postgres,
        IResourceBuilder<RedisResource> redis,
        IResourceBuilder<RabbitMQServerResource> rabbitMq)
    {
        // IResourceBuilder<PostgresDatabaseResource> exampleDatabase = postgres.AddDatabase("db-example");
        // builder.AddProject<Projects.Example_API>("example-api")
        //     .WithReference(exampleDatabase)
        //     .WithReference(redis)
        //     .WithReference(rabbitMq)
        //     .WaitFor(exampleDatabase)
        //     .WaitFor(redis)
        //     .WaitFor(rabbitMq);

        // builder.AddProject<Projects.Example_BackgroundServices>("example-background")
        //     .WithReference(exampleDatabase)
        //     .WithReference(redis)
        //     .WithReference(rabbitMq)
        //     .WaitFor(exampleDatabase)
        //     .WaitFor(redis)
        //     .WaitFor(rabbitMq);

        return builder;
    }
}
