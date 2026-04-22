namespace Zzaia.AppHost.Settings;

/// <summary>
/// Centralized configuration settings for the AppHost distributed application.
/// </summary>
public sealed class AppHostSettings
{
    /// <summary>
    /// Configuration section name in appsettings.json.
    /// </summary>
    public const string SectionName = "AppHost";

    /// <summary>
    /// PostgreSQL resource settings.
    /// </summary>
    public PostgresSettings Postgres { get; init; } = new();

    /// <summary>
    /// Redis resource settings.
    /// </summary>
    public RedisSettings Redis { get; init; } = new();

    /// <summary>
    /// RabbitMQ resource settings.
    /// </summary>
    public RabbitMqSettings RabbitMq { get; init; } = new();

    /// <summary>
    /// Application-specific settings.
    /// </summary>
    public ApplicationSettings Applications { get; init; } = new();
}
