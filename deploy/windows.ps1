#Requires -Version 7

Write-Host ''
Write-Host '  ███████╗███████╗ █████╗ ██╗ █████╗ '
Write-Host '     ███╔╝   ███╔╝██╔══██╗██║██╔══██╗'
Write-Host '    ███╔╝   ███╔╝ ███████║██║███████║ '
Write-Host '   ███╔╝   ███╔╝  ██╔══██║██║██╔══██║ '
Write-Host '  ███████╗███████╗██║  ██║██║██║  ██║ '
Write-Host '  ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝'
Write-Host ''
Write-Host '         ⚡  Agentic Workspace  ⚡'
Write-Host ''

# Check if bws is installed
if (-not (Get-Command bws -ErrorAction SilentlyContinue)) {
    Write-Error "bws (Bitwarden Secrets Manager) not found. Install from:"
    Write-Error "  https://bitwarden.com/help/secrets-manager/#download-the-cli"
    exit 1
}

try {
    # Prompt for Bitwarden Secrets Manager access token (if not set via environment)
    if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
        $BWS_ACCESS_TOKEN = Read-Host "Bitwarden Secrets Manager Access Token"
        if ([string]::IsNullOrWhiteSpace($BWS_ACCESS_TOKEN)) {
            Write-Error "Error: BWS_ACCESS_TOKEN is required"
            exit 1
        }
    } else {
        $BWS_ACCESS_TOKEN = $env:BWS_ACCESS_TOKEN
    }

    # Prompt for Vault Root Token
    if ([string]::IsNullOrWhiteSpace($env:VAULT_ROOT_TOKEN)) {
        $VAULT_ROOT_TOKEN = Read-Host "Vault Root Token (required — choose a strong value)"
        if ([string]::IsNullOrWhiteSpace($VAULT_ROOT_TOKEN)) {
            Write-Error "Error: VAULT_ROOT_TOKEN is required"
            exit 1
        }
    } else {
        $VAULT_ROOT_TOKEN = $env:VAULT_ROOT_TOKEN
    }

    # Fetch all secrets from Bitwarden Secrets Manager
    Write-Host "Fetching secrets from Bitwarden Secrets Manager..."
    $env:BWS_ACCESS_TOKEN = $BWS_ACCESS_TOKEN

    $secretsJson = bws secret list --output json 2>$null
    if (-not $secretsJson -or $secretsJson -eq "[]") {
        Write-Error "Error: No secrets returned from Bitwarden or bws failed"
        exit 1
    }

    $secrets = $secretsJson | ConvertFrom-Json

    # Helper function to extract a secret value by key
    function Get-SecretValue {
        param([Parameter(Mandatory)] [string] $key)
        $secret = $secrets | Where-Object { $_.key -eq $key } | Select-Object -First 1
        if ($secret) {
            return $secret.value
        }
        return ""
    }

    # Extract all required and optional secrets
    $WORKSPACE_NAME = Get-SecretValue "WORKSPACE_NAME"
    $SSH_PUBLIC_KEY = Get-SecretValue "SSH_PUBLIC_KEY"
    $ADMIN_PASSWORD = Get-SecretValue "ADMIN_PASSWORD"
    $VSCODE_PORT = Get-SecretValue "VSCODE_PORT"
    $SSH_PORT = Get-SecretValue "SSH_PORT"
    $ASPIRE_DASHBOARD_PORT = Get-SecretValue "ASPIRE_DASHBOARD_PORT"

    $ANTHROPIC_API_KEY = Get-SecretValue "ANTHROPIC_API_KEY"
    $CLAUDE_CODE_OAUTH_TOKEN = Get-SecretValue "CLAUDE_CODE_OAUTH_TOKEN"
    $OPENAI_API_KEY = Get-SecretValue "OPENAI_API_KEY"
    $GEMINI_API_KEY = Get-SecretValue "GEMINI_API_KEY"
    $GITHUB_PERSONAL_ACCESS_TOKEN = Get-SecretValue "GITHUB_PERSONAL_ACCESS_TOKEN"

    $AWS_ACCESS_KEY_ID = Get-SecretValue "AWS_ACCESS_KEY_ID"
    $AWS_SECRET_ACCESS_KEY = Get-SecretValue "AWS_SECRET_ACCESS_KEY"
    $AWS_REGION = Get-SecretValue "AWS_REGION"
    $ANTHROPIC_BEDROCK_BASE_URL = Get-SecretValue "ANTHROPIC_BEDROCK_BASE_URL"
    $CLAUDE_CODE_USE_VERTEX = Get-SecretValue "CLAUDE_CODE_USE_VERTEX"
    $ANTHROPIC_VERTEX_PROJECT_ID = Get-SecretValue "ANTHROPIC_VERTEX_PROJECT_ID"
    $CLOUD_ML_REGION = Get-SecretValue "CLOUD_ML_REGION"
    $CLAUDE_CODE_USE_FOUNDRY = Get-SecretValue "CLAUDE_CODE_USE_FOUNDRY"
    $AZURE_FOUNDRY_BASE_URL = Get-SecretValue "AZURE_FOUNDRY_BASE_URL"

    $TAVILY_API_KEY = Get-SecretValue "TAVILY_API_KEY"
    $ADO_MCP_AUTH_TOKEN = Get-SecretValue "ADO_MCP_AUTH_TOKEN"
    $AZURE_DEVOPS_ORGANIZATION = Get-SecretValue "AZURE_DEVOPS_ORGANIZATION"
    $POSTMAN_API_KEY = Get-SecretValue "POSTMAN_API_KEY"
    $NEW_RELIC_API_KEY = Get-SecretValue "NEW_RELIC_API_KEY"

    $DOCKER_REGISTRY = Get-SecretValue "DOCKER_REGISTRY"
    $DOCKER_USERNAME = Get-SecretValue "DOCKER_USERNAME"
    $DOCKER_PASSWORD = Get-SecretValue "DOCKER_PASSWORD"

    $DEPLOY_PROFILES = Get-SecretValue "DEPLOY_PROFILES"
    $GPU_ENABLED = Get-SecretValue "GPU_ENABLED"

    # Validate required secrets
    if ([string]::IsNullOrWhiteSpace($WORKSPACE_NAME)) {
        Write-Error "WORKSPACE_NAME secret not found in Bitwarden"
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($SSH_PUBLIC_KEY)) {
        Write-Error "SSH_PUBLIC_KEY secret not found in Bitwarden"
        exit 1
    }

    # Set defaults for optional values
    $VSCODE_PORT = if ([string]::IsNullOrWhiteSpace($VSCODE_PORT)) { "8080" } else { $VSCODE_PORT }
    $SSH_PORT = if ([string]::IsNullOrWhiteSpace($SSH_PORT)) { "2222" } else { $SSH_PORT }
    $ASPIRE_DASHBOARD_PORT = if ([string]::IsNullOrWhiteSpace($ASPIRE_DASHBOARD_PORT)) { "18888" } else { $ASPIRE_DASHBOARD_PORT }
    $ADMIN_PASSWORD = if ([string]::IsNullOrWhiteSpace($ADMIN_PASSWORD)) { "zzaia1234" } else { $ADMIN_PASSWORD }
    $GPU_ENABLED = if ([string]::IsNullOrWhiteSpace($GPU_ENABLED)) { "false" } else { $GPU_ENABLED }

    # Validate port numbers
    if (-not [int]::TryParse($VSCODE_PORT, [ref]0) -or $VSCODE_PORT -lt 1 -or $VSCODE_PORT -gt 65535) {
        Write-Error "Invalid VSCODE_PORT"
        exit 1
    }
    if (-not [int]::TryParse($SSH_PORT, [ref]0) -or $SSH_PORT -lt 1 -or $SSH_PORT -gt 65535) {
        Write-Error "Invalid SSH_PORT"
        exit 1
    }
    if (-not [int]::TryParse($ASPIRE_DASHBOARD_PORT, [ref]0) -or $ASPIRE_DASHBOARD_PORT -lt 1 -or $ASPIRE_DASHBOARD_PORT -gt 65535) {
        Write-Error "Invalid ASPIRE_DASHBOARD_PORT"
        exit 1
    }

    # Set environment variables for docker compose
    $env:WORKSPACE_NAME = $WORKSPACE_NAME
    $env:SSH_PUBLIC_KEY = $SSH_PUBLIC_KEY
    $env:ADMIN_PASSWORD = $ADMIN_PASSWORD
    $env:VSCODE_PORT = $VSCODE_PORT
    $env:SSH_PORT = $SSH_PORT
    $env:ASPIRE_DASHBOARD_PORT = $ASPIRE_DASHBOARD_PORT
    $env:VAULT_ROOT_TOKEN = $VAULT_ROOT_TOKEN

    $env:GPU_ENABLED = $GPU_ENABLED
    $env:DEPLOY_PROFILES = $DEPLOY_PROFILES
    $env:ANTHROPIC_API_KEY = $ANTHROPIC_API_KEY
    $env:CLAUDE_CODE_OAUTH_TOKEN = $CLAUDE_CODE_OAUTH_TOKEN
    $env:OPENAI_API_KEY = $OPENAI_API_KEY
    $env:GEMINI_API_KEY = $GEMINI_API_KEY
    $env:GITHUB_PERSONAL_ACCESS_TOKEN = $GITHUB_PERSONAL_ACCESS_TOKEN
    $env:AWS_ACCESS_KEY_ID = $AWS_ACCESS_KEY_ID
    $env:AWS_SECRET_ACCESS_KEY = $AWS_SECRET_ACCESS_KEY
    $env:AWS_REGION = $AWS_REGION
    $env:ANTHROPIC_BEDROCK_BASE_URL = $ANTHROPIC_BEDROCK_BASE_URL
    $env:CLAUDE_CODE_USE_VERTEX = $CLAUDE_CODE_USE_VERTEX
    $env:ANTHROPIC_VERTEX_PROJECT_ID = $ANTHROPIC_VERTEX_PROJECT_ID
    $env:CLOUD_ML_REGION = $CLOUD_ML_REGION
    $env:CLAUDE_CODE_USE_FOUNDRY = $CLAUDE_CODE_USE_FOUNDRY
    $env:AZURE_FOUNDRY_BASE_URL = $AZURE_FOUNDRY_BASE_URL
    $env:TAVILY_API_KEY = $TAVILY_API_KEY
    $env:ADO_MCP_AUTH_TOKEN = $ADO_MCP_AUTH_TOKEN
    $env:AZURE_DEVOPS_ORGANIZATION = $AZURE_DEVOPS_ORGANIZATION
    $env:POSTMAN_API_KEY = $POSTMAN_API_KEY
    $env:NEW_RELIC_API_KEY = $NEW_RELIC_API_KEY

    # Optional Docker registry login
    if ($DOCKER_REGISTRY -and $DOCKER_USERNAME -and $DOCKER_PASSWORD) {
        Write-Host "Logging in to Docker registry..."
        $DOCKER_PASSWORD | docker login $DOCKER_REGISTRY -u $DOCKER_USERNAME --password-stdin
    }

    # Build --profile flags
    $profileArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($DEPLOY_PROFILES)) {
        foreach ($p in ($DEPLOY_PROFILES -split '\s+')) {
            if ($p -match '^(vscode|devcontainer|jupyter|tunnel)$') {
                $profileArgs += '--profile'
                $profileArgs += $p
            } else {
                Write-Warning "Unknown server profile '$p' — valid: vscode, devcontainer, jupyter, tunnel"
            }
        }
    }

    # GPU compose flag
    $gpuComposeArgs = @()
    if ($GPU_ENABLED -eq "true") {
        $gpuComposeArgs = @('-f', "$PSScriptRoot\..\docker\docker-compose.gpu.yml")
    }

    Write-Host ""
    Write-Host "Starting workspace..."
    docker compose `
        -f "$PSScriptRoot\..\docker\docker-compose.yml" `
        @gpuComposeArgs `
        -p $env:WORKSPACE_NAME `
        @profileArgs `
        up -d

    Write-Host ""
    Write-Host "✓ Workspace started. Access:"
    Write-Host "  SSH: ssh -p $($env:SSH_PORT) user@localhost"
    if ($DEPLOY_PROFILES -match 'vscode') { Write-Host "  VS Code: http://localhost:$($env:VSCODE_PORT)" }
    if ($DEPLOY_PROFILES -match 'devcontainer') { Write-Host "  Dev Container: attach via VS Code Dev Containers extension" }
    if ($DEPLOY_PROFILES -match 'tunnel') { Write-Host "  VS Code Tunnel: Remote Tunnels extension → '$env:WORKSPACE_NAME' or https://vscode.dev/tunnel/$env:WORKSPACE_NAME" }
    Write-Host "  Vault UI: http://localhost:8200/ui"
    Write-Host "  AppHost Dashboard (when AppHost is running): http://localhost:$($env:ASPIRE_DASHBOARD_PORT)"
}
finally {
    # Cleanup: unset BWS_ACCESS_TOKEN and all secret env vars
    Remove-Item "Env:BWS_ACCESS_TOKEN" -ErrorAction SilentlyContinue
    
    @('WORKSPACE_NAME','SSH_PUBLIC_KEY','ADMIN_PASSWORD',
      'VSCODE_PORT','SSH_PORT','ASPIRE_DASHBOARD_PORT','VAULT_ROOT_TOKEN',
      'GPU_ENABLED','DEPLOY_PROFILES',
      'ANTHROPIC_API_KEY','CLAUDE_CODE_OAUTH_TOKEN',
      'OPENAI_API_KEY','GEMINI_API_KEY','GITHUB_PERSONAL_ACCESS_TOKEN',
      'AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AWS_REGION',
      'ANTHROPIC_BEDROCK_BASE_URL',
      'CLAUDE_CODE_USE_VERTEX','ANTHROPIC_VERTEX_PROJECT_ID','CLOUD_ML_REGION',
      'CLAUDE_CODE_USE_FOUNDRY','AZURE_FOUNDRY_BASE_URL',
      'TAVILY_API_KEY','ADO_MCP_AUTH_TOKEN','AZURE_DEVOPS_ORGANIZATION',
      'POSTMAN_API_KEY','NEW_RELIC_API_KEY') | ForEach-Object {
        Remove-Item "Env:$_" -ErrorAction SilentlyContinue
    }
}
