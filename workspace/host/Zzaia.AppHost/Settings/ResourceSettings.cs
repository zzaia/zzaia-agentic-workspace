namespace Zzaia.AppHost.Settings;

/// <summary>
/// Configuration settings for PostgreSQL resource.
/// </summary>
public sealed class PostgresSettings
{
    /// <summary>
    /// Docker image name for PostgreSQL.
    /// </summary>
    public string Image { get; init; } = string.Empty;

    /// <summary>
    /// Docker image tag for PostgreSQL.
    /// </summary>
    public string Tag { get; init; } = string.Empty;

    /// <summary>
    /// Resource name in the distributed application.
    /// </summary>
    public string ResourceName { get; init; } = string.Empty;
}

/// <summary>
/// Configuration settings for Redis resource.
/// </summary>
public sealed class RedisSettings
{
    /// <summary>
    /// Docker image name for Redis.
    /// </summary>
    public string Image { get; init; } = string.Empty;

    /// <summary>
    /// Docker image tag for Redis.
    /// </summary>
    public string Tag { get; init; } = string.Empty;

    /// <summary>
    /// Resource name in the distributed application.
    /// </summary>
    public string ResourceName { get; init; } = string.Empty;
}

/// <summary>
/// Configuration settings for RabbitMQ resource.
/// </summary>
public sealed class RabbitMqSettings
{
    /// <summary>
    /// Docker image name for RabbitMQ.
    /// </summary>
    public string Image { get; init; } = string.Empty;

    /// <summary>
    /// Docker image tag for RabbitMQ.
    /// </summary>
    public string Tag { get; init; } = string.Empty;

    /// <summary>
    /// Resource name in the distributed application.
    /// </summary>
    public string ResourceName { get; init; } = string.Empty;

    /// <summary>
    /// RabbitMQ host address.
    /// </summary>
    public string Host { get; init; } = string.Empty;

    /// <summary>
    /// RabbitMQ port number.
    /// </summary>
    public string Port { get; init; } = string.Empty;

    /// <summary>
    /// RabbitMQ username.
    /// </summary>
    public string Username { get; init; } = string.Empty;

    /// <summary>
    /// RabbitMQ password.
    /// </summary>
    public string Password { get; init; } = string.Empty;
}
