namespace Zzaia.AppHost.Settings;

/// <summary>
/// Configuration settings for application endpoints.
/// </summary>
public sealed class ApplicationSettings
{
    /// <summary>
    /// Domain Service application settings.
    /// </summary>
    public DomainServiceSettings DomainService { get; init; } = new();
}

/// <summary>
/// Configuration settings for Domain Service.
/// </summary>
public sealed class DomainServiceSettings
{
    /// <summary>
    /// API resource name in the distributed application.
    /// </summary>
    public string ApiResourceName { get; init; } = string.Empty;

    /// <summary>
    /// Background Services resource name in the distributed application.
    /// </summary>
    public string BackgroundResourceName { get; init; } = string.Empty;

    /// <summary>
    /// Database name for Fiat Service.
    /// </summary>
    public string DatabaseName { get; init; } = string.Empty;

    /// <summary>
    /// Database resource name in PostgreSQL.
    /// </summary>
    public string DatabaseResourceName { get; init; } = string.Empty;
}