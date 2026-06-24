using Zzaia.AppHost.Settings;

namespace Zzaia.AppHost.Applications;

/// <summary>
/// Extension methods for configuring microservices in the application host.
/// </summary>
public static class ApplicationInjection_Services
{
    /// <summary>
    /// Adds LocalStack container to the distributed application.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="settings">The LocalStack configuration settings.</param>
    /// <returns>The LocalStack container resource builder.</returns>
    public static IResourceBuilder<ContainerResource> AddLocalStackApplication(
        this IDistributedApplicationBuilder builder,
        LocalStackSettings settings)
    {
        return builder.AddContainer(settings.ResourceName, settings.Image, settings.Tag)
            .WithEnvironment("SERVICES", "sqs,dynamodb,s3,sns")
            .WithEnvironment("AWS_DEFAULT_REGION", "us-east-1")
            .WithHttpEndpoint(port: settings.Port, targetPort: settings.Port, name: "localstack")
            .WithBindMount("/var/run/docker.sock", "/var/run/docker.sock");
    }

    /// <summary>
    /// Adds the Order Service API to the distributed application.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="postgres">The PostgreSQL server resource builder.</param>
    /// <param name="redis">The Redis resource builder.</param>
    /// <param name="rabbitMq">The RabbitMQ server resource builder.</param>
    /// <param name="rabbitMqSettings">The RabbitMQ configuration settings.</param>
    /// <param name="settings">The Order Service configuration settings.</param>
    /// <returns>The distributed application builder for chaining.</returns>
    public static IDistributedApplicationBuilder AddOrderServiceApplication(
        this IDistributedApplicationBuilder builder,
        IResourceBuilder<PostgresServerResource> postgres,
        IResourceBuilder<RedisResource> redis,
        IResourceBuilder<RabbitMQServerResource> rabbitMq,
        RabbitMqSettings rabbitMqSettings,
        OrderServiceSettings settings)
    {
        // NOTE: Requires project reference to be uncommented in .csproj
        // var database = postgres.AddDatabase(settings.DatabaseResourceName, settings.DatabaseName);
        // builder.AddProject<Projects.BGX_OrderService_API>(settings.ApiResourceName)
        //     .WithReference(database)
        //     .WithReference(redis)
        //     .WithReference(rabbitMq)
        //     .WithEnvironment("RabbitMQ__Host", rabbitMqSettings.Host)
        //     .WithEnvironment("RabbitMQ__Port", rabbitMqSettings.Port)
        //     .WithEnvironment("RabbitMQ__Username", rabbitMqSettings.Username)
        //     .WithEnvironment("RabbitMQ__Password", rabbitMqSettings.Password)
        //     .WaitFor(database)
        //     .WaitFor(redis)
        //     .WaitFor(rabbitMq);

        return builder;
    }

    /// <summary>
    /// Adds the Fiat Service API to the distributed application.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="postgres">The PostgreSQL server resource builder.</param>
    /// <param name="redis">The Redis resource builder.</param>
    /// <param name="rabbitMq">The RabbitMQ server resource builder.</param>
    /// <param name="rabbitMqSettings">The RabbitMQ configuration settings.</param>
    /// <param name="settings">The Fiat Service configuration settings.</param>
    /// <returns>The distributed application builder for chaining.</returns>
    public static IDistributedApplicationBuilder AddFiatServiceApplication(
        this IDistributedApplicationBuilder builder,
        IResourceBuilder<PostgresServerResource> postgres,
        IResourceBuilder<RedisResource> redis,
        IResourceBuilder<RabbitMQServerResource> rabbitMq,
        RabbitMqSettings rabbitMqSettings,
        FiatServiceSettings settings)
    {
        // NOTE: Requires project reference to be uncommented in .csproj
        // var database = postgres.AddDatabase(settings.DatabaseResourceName, settings.DatabaseName);
        // builder.AddProject<Projects.Bloquo_FiatService_API>(settings.ApiResourceName)
        //     .WithReference(database)
        //     .WithReference(redis)
        //     .WithReference(rabbitMq)
        //     .WithEnvironment("RabbitMQ__Host", rabbitMqSettings.Host)
        //     .WithEnvironment("RabbitMQ__Port", rabbitMqSettings.Port)
        //     .WithEnvironment("RabbitMQ__Username", rabbitMqSettings.Username)
        //     .WithEnvironment("RabbitMQ__Password", rabbitMqSettings.Password)
        //     .WaitFor(database)
        //     .WaitFor(redis)
        //     .WaitFor(rabbitMq);

        return builder;
    }

    /// <summary>
    /// Adds the Customer Service API to the distributed application.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="postgres">The PostgreSQL server resource builder.</param>
    /// <param name="redis">The Redis resource builder.</param>
    /// <param name="rabbitMq">The RabbitMQ server resource builder.</param>
    /// <param name="rabbitMqSettings">The RabbitMQ configuration settings.</param>
    /// <param name="settings">The Customer Service configuration settings.</param>
    /// <returns>The distributed application builder for chaining.</returns>
    public static IDistributedApplicationBuilder AddCustomerServiceApplication(
        this IDistributedApplicationBuilder builder,
        IResourceBuilder<PostgresServerResource> postgres,
        IResourceBuilder<RedisResource> redis,
        IResourceBuilder<RabbitMQServerResource> rabbitMq,
        RabbitMqSettings rabbitMqSettings,
        CustomerServiceSettings settings)
    {
        // NOTE: Requires project reference to be uncommented in .csproj
        // var database = postgres.AddDatabase(settings.DatabaseResourceName, settings.DatabaseName);
        // builder.AddProject<Projects.BGX_CustomerService_API>(settings.ApiResourceName)
        //     .WithReference(database)
        //     .WithReference(redis)
        //     .WithReference(rabbitMq)
        //     .WithEnvironment("RabbitMQ__Host", rabbitMqSettings.Host)
        //     .WithEnvironment("RabbitMQ__Port", rabbitMqSettings.Port)
        //     .WithEnvironment("RabbitMQ__Username", rabbitMqSettings.Username)
        //     .WithEnvironment("RabbitMQ__Password", rabbitMqSettings.Password)
        //     .WaitFor(database)
        //     .WaitFor(redis)
        //     .WaitFor(rabbitMq);

        return builder;
    }

    /// <summary>
    /// Adds all Node.js connector services to the distributed application.
    /// </summary>
    /// <param name="builder">The distributed application builder.</param>
    /// <param name="localstack">The LocalStack container resource builder.</param>
    /// <param name="settings">The application settings containing all Node.js service configurations.</param>
    /// <returns>The distributed application builder for chaining.</returns>
    public static IDistributedApplicationBuilder AddNodeServicesApplications(
        this IDistributedApplicationBuilder builder,
        IResourceBuilder<ContainerResource> localstack,
        ApplicationSettings settings)
    {
        var localstackHost = "localstack";
        var localstackPort = settings.LocalStack.Port.ToString();
        var localstackUrl = $"http://{localstackHost}:{localstackPort}";

        // Wirex Service
        builder.AddNpmApp("wirex-service", "../../../workspace/wirex-service.worktrees/release/validate-order-creation", "dev")
            .WithHttpEndpoint(port: settings.WirexService.Port, env: "PORT")
            .WithEnvironment("AWS_ENDPOINT_URL", localstackUrl);

        // Pockyt Service
        builder.AddNpmApp("pockyt-service", "../../../workspace/pockyt-service.worktrees/release/validate-order-creation", "dev")
            .WithHttpEndpoint(port: settings.PockytService.Port, env: "PORT")
            .WithEnvironment("AWS_ENDPOINT_URL", localstackUrl);

        // Celcoin Service
        builder.AddNpmApp("celcoin-service", "../../../workspace/celcoin-service.worktrees/release/validate-order-creation", "dev")
            .WithHttpEndpoint(port: settings.CelcoinService.Port, env: "PORT")
            .WithEnvironment("AWS_ENDPOINT_URL", localstackUrl)
            .WithEnvironment("REDIS_URL", "redis://redis:6379");

        // Semear Service
        builder.AddNpmApp("semear-service", "../../../workspace/semear-service.worktrees/release/validate-order-creation", "dev")
            .WithHttpEndpoint(port: settings.SemearService.Port, env: "PORT")
            .WithEnvironment("AWS_ENDPOINT_URL", localstackUrl);

        // Genial Service
        builder.AddNpmApp("genial-service", "../../../workspace/genial-service.worktrees/release/validate-order-creation", "dev")
            .WithHttpEndpoint(port: settings.GenialService.Port, env: "PORT")
            .WithEnvironment("AWS_ENDPOINT_URL", localstackUrl);

        // T0 Service (dual ports: main HTTP + gRPC callback)
        builder.AddNpmApp("t0-service", "../../../workspace/t0-service.worktrees/release/validate-order-creation", "dev")
            .WithHttpEndpoint(port: settings.T0Service.Port, env: "PORT")
            .WithEnvironment("CALLBACK_PORT", settings.T0Service.CallbackPort.ToString())
            .WithEnvironment("AWS_ENDPOINT_URL", localstackUrl);

        return builder;
    }
}
