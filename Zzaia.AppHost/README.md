# Zzaia.AppHost

.NET Aspire orchestration host for managing multi-service development environments.

## Architecture

This AppHost project orchestrates the FiatService microservice infrastructure using .NET Aspire, providing:

- Shared infrastructure resources (PostgreSQL, Redis, RabbitMQ)
- Service configuration and dependency management
- Local development environment orchestration

## Project Structure

```
Zzaia.AppHost/
├── Applications/
│   └── ApplicationInjection.cs    # Application-specific configuration
├── Properties/
│   └── launchSettings.json          # Launch profiles
├── Program.cs                       # Main orchestration configuration
├── appsettings.json                 # Application settings
├── appsettings.Development.json     # Development settings
└── Zzaia.AppHost.csproj            # Project file
```

## Infrastructure Resources

### PostgreSQL
- Image: postgres:16.2-alpine
- Database: fiatdb
- Lifecycle: Persistent

### Redis
- Image: redis:7.2-alpine
- Lifecycle: Persistent

### RabbitMQ
- Image: rabbitmq:3.13-management-alpine
- Lifecycle: Persistent

```

The Aspire dashboard will be available at:
- HTTP: http://localhost:15000
- HTTPS: https://localhost:17001

## Adding New Services

To add additional services, create extension methods in the `Applications/` directory following the pattern in `ApplicationInjection.cs`:

```csharp
public static IDistributedApplicationBuilder AddYourService(
    this IDistributedApplicationBuilder builder,
    IResourceBuilder<PostgresServerResource> postgres,
    IResourceBuilder<RedisResource> redis,
    IResourceBuilder<RabbitMQServerResource> rabbitMq)
{
    // Configure your service here
    return builder;
}
```

## Dependencies

The AppHost references workspace projects but workspace projects do NOT reference the AppHost. This maintains proper architectural boundaries.

## Clean Architecture Compliance

- Explicit type usage throughout
- Self-documenting code structure
- Clear separation of concerns
- Extension-based service configuration
