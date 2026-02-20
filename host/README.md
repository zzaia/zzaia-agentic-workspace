# Zzaia.AppHost

.NET Aspire orchestration template for running workspace applications with shared infrastructure during development and testing.

## Purpose

Agentic workspace template that spins up shared infrastructure (PostgreSQL, Redis, RabbitMQ) and wires workspace service projects for integrated validation and testing. Workspace project references are added dynamically per development session.

## Project Structure

```
Zzaia.AppHost/
├── Applications/
│   └── ApplicationInjection.cs    # Extension methods per application
├── Settings/
│   ├── AppHostSettings.cs         # Centralized settings root
│   ├── ApplicationSettings.cs     # Per-application settings
│   ├── ResourceSettings.cs        # Infrastructure resource settings
│   └── SettingsExtensions.cs      # Builder extension methods
├── Properties/
│   └── launchSettings.json
├── Program.cs                     # Orchestration entry point
├── appsettings.json               # Infrastructure & application config
└── Zzaia.AppHost.csproj
```

## Infrastructure Resources

| Resource   | Image                          | Lifecycle  |
|------------|--------------------------------|------------|
| PostgreSQL | postgres:16.2-alpine           | Persistent |
| Redis      | redis:7.2-alpine               | Persistent |
| RabbitMQ   | rabbitmq:3.13-management-alpine| Persistent |

All resource images and tags are driven by `appsettings.json` under the `AppHost` section.

## Adding Workspace Applications

1. Add `ProjectReference` to `.csproj` pointing to the workspace worktree service
2. Uncomment and configure the `ApplicationInjection.cs` extension method
3. Add application settings to `appsettings.json` under `AppHost.Applications`

Extension method pattern:

```csharp
public static IDistributedApplicationBuilder AddYourServiceApplication(
    this IDistributedApplicationBuilder builder,
    IResourceBuilder<PostgresServerResource> postgres,
    IResourceBuilder<RedisResource> redis,
    IResourceBuilder<RabbitMQServerResource> rabbitMq,
    RabbitMqSettings rabbitMqSettings,
    YourServiceSettings settings)
{
    // configure resources
    return builder;
}
```

## Dashboard

- HTTP: http://localhost:15000
- HTTPS: https://localhost:17001

## Dependencies

AppHost references workspace project paths directly. Workspace projects do NOT reference AppHost.
