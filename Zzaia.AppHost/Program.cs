using Zzaia.AppHost.Applications;

IDistributedApplicationBuilder builder = DistributedApplication.CreateBuilder(args);

IResourceBuilder<PostgresServerResource> postgres = builder.AddPostgres("postgres")
    .WithImage("postgres")
    .WithImageTag("16.2-alpine")
    .WithLifetime(ContainerLifetime.Persistent);

IResourceBuilder<RedisResource> redis = builder.AddRedis("redis")
    .WithImage("redis")
    .WithImageTag("7.2-alpine")
    .WithLifetime(ContainerLifetime.Persistent);

IResourceBuilder<RabbitMQServerResource> rabbitMq = builder.AddRabbitMQ("rabbitmq")
    .WithImage("rabbitmq")
    .WithImageTag("3.13-management-alpine")
    .WithLifetime(ContainerLifetime.Persistent);

// Add applications to the distributed application runtime
builder = builder.AddExampleApplication(postgres, redis, rabbitMq);

builder.Build().Run();
