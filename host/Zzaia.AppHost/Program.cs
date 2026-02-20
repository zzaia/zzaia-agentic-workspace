using Zzaia.AppHost.Applications;
using Zzaia.AppHost.Settings;

IDistributedApplicationBuilder builder = DistributedApplication.CreateBuilder(args);

AppHostSettings settings = builder.LoadSettings();

IResourceBuilder<PostgresServerResource> postgres = builder.AddPostgresWithSettings(settings.Postgres);
IResourceBuilder<RedisResource> redis = builder.AddRedisWithSettings(settings.Redis);
IResourceBuilder<RabbitMQServerResource> rabbitMq = builder.AddRabbitMqWithSettings(settings.RabbitMq);

// Add applications to the distributed application runtime
builder = builder.AddDomainServiceApplication(postgres, redis, rabbitMq, settings.RabbitMq, settings.Applications.DomainService);

builder.Build().Run();
