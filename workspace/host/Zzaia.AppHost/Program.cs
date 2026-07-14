using Zzaia.AppHost.Applications;
using Zzaia.AppHost.Applications.MiniStack;
using Zzaia.AppHost.Settings;

IDistributedApplicationBuilder builder = DistributedApplication.CreateBuilder(args);

AppHostSettings settings = builder.LoadSettings();

IResourceBuilder<PostgresServerResource> postgres = builder.AddPostgresWithSettings(settings.Postgres);
IResourceBuilder<RedisResource> redis = builder.AddRedisWithSettings(settings.Redis).WithRedisMcp(builder);
IResourceBuilder<RabbitMQServerResource> rabbitMq = builder.AddRabbitMqWithSettings(settings.RabbitMq);

// Local AWS-service emulation (SQS/DynamoDB/S3/SNS) with an MCP proxy for agent introspection
IResourceBuilder<ContainerResource> ministack = builder.AddMiniStackApplication().WithMiniStackMcp(builder);

// Add applications to the distributed application runtime
builder = builder.AddDomainServiceApplication(postgres, redis, rabbitMq, settings.RabbitMq, settings.Applications.DomainService);

builder.Build().Run();
