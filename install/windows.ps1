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

if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Error "Bitwarden CLI 'bw' not found. Install from: https://bitwarden.com/help/cli"
    exit 1
}

try {
    Write-Host "Logging in to Bitwarden..."
    $bwStatus = (bw status 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue).status
    if ($bwStatus -eq "unauthenticated" -or -not $bwStatus) {
        $s = bw login --raw
    } else {
        $s = bw unlock --raw
    }
    if ($LASTEXITCODE -ne 0 -or -not $s) {
        Write-Error "Bitwarden login/unlock failed."
        exit 1
    }

    $env:BW_SESSION = $s
    $items = bw list items 2>$null | ConvertFrom-Json
    $env:BW_SESSION = $null
    Remove-Variable s

    function Get-VaultSecret {
        param([Parameter(Mandatory)] $items, [Parameter(Mandatory)] [string] $name)
        $item = $items | Where-Object { $_.name -eq $name }
        $val = $item.login.password ?? $item.sshKey.publicKey ?? $item.notes ?? ""
        return $val -as [string] ?? ""
    }

    $WORKSPACE_NAME = Get-VaultSecret $items "workspace-name"
    $SSH_PUBLIC_KEY = Get-VaultSecret $items "ssh-public-key"
    $ADMIN_PASSWORD = Get-VaultSecret $items "admin-password"
    $VSCODE_PORT = Get-VaultSecret $items "vscode-port"
    $SSH_PORT = Get-VaultSecret $items "ssh-port"
    $ASPIRE_DASHBOARD_PORT = Get-VaultSecret $items "aspire-dashboard-port"

    $ANTHROPIC_API_KEY = Get-VaultSecret $items "anthropic-api-key"
    $CLAUDE_CODE_OAUTH_TOKEN = Get-VaultSecret $items "claude-code-oauth-token"
    $OPENAI_API_KEY = Get-VaultSecret $items "openai-api-key"
    $GEMINI_API_KEY = Get-VaultSecret $items "gemini-api-key"
    $GITHUB_PERSONAL_ACCESS_TOKEN = Get-VaultSecret $items "github-pat"
    $TAVILY_API_KEY = Get-VaultSecret $items "tavily"
    $ADO_MCP_AUTH_TOKEN = Get-VaultSecret $items "azure-devops-pat"
    $AZURE_DEVOPS_ORGANIZATION = Get-VaultSecret $items "azure-devops-org"
    $POSTMAN_API_KEY = Get-VaultSecret $items "postman"
    $NEW_RELIC_API_KEY = Get-VaultSecret $items "new-relic"
    $DOCKER_REGISTRY = Get-VaultSecret $items "docker-registry"
    $DOCKER_USERNAME = Get-VaultSecret $items "docker-username"
    $DOCKER_PASSWORD = Get-VaultSecret $items "docker-password"
    $DEPLOY_PROFILES = Get-VaultSecret $items "server-profiles"
    $GPU_ENABLED = Get-VaultSecret $items "gpu-enabled"

    Remove-Variable items

    if ([string]::IsNullOrWhiteSpace($WORKSPACE_NAME)) {
        Write-Error "WORKSPACE_NAME (vault: workspace-name) not found or empty"
        exit 1
    }

    $VSCODE_PORT = if ([string]::IsNullOrWhiteSpace($VSCODE_PORT)) { "8080" } else { $VSCODE_PORT }
    $SSH_PORT = if ([string]::IsNullOrWhiteSpace($SSH_PORT)) { "2222" } else { $SSH_PORT }
    $ASPIRE_DASHBOARD_PORT = if ([string]::IsNullOrWhiteSpace($ASPIRE_DASHBOARD_PORT)) { "18888" } else { $ASPIRE_DASHBOARD_PORT }

    if (-not [int]::TryParse($VSCODE_PORT, [ref]0) -or $VSCODE_PORT -lt 1 -or $VSCODE_PORT -gt 65535) {
        $VSCODE_PORT = "8080"
    }
    if (-not [int]::TryParse($SSH_PORT, [ref]0) -or $SSH_PORT -lt 1 -or $SSH_PORT -gt 65535) {
        $SSH_PORT = "2222"
    }
    if (-not [int]::TryParse($ASPIRE_DASHBOARD_PORT, [ref]0) -or $ASPIRE_DASHBOARD_PORT -lt 1 -or $ASPIRE_DASHBOARD_PORT -gt 65535) {
        $ASPIRE_DASHBOARD_PORT = "18888"
    }

    $env:WORKSPACE_NAME = $WORKSPACE_NAME
    $env:SSH_PUBLIC_KEY = $SSH_PUBLIC_KEY
    $env:ADMIN_PASSWORD = $ADMIN_PASSWORD
    $env:VSCODE_PORT = $VSCODE_PORT
    $env:SSH_PORT = $SSH_PORT
    $env:ASPIRE_DASHBOARD_PORT = $ASPIRE_DASHBOARD_PORT

    $env:ANTHROPIC_API_KEY = $ANTHROPIC_API_KEY
    $env:CLAUDE_CODE_OAUTH_TOKEN = $CLAUDE_CODE_OAUTH_TOKEN
    $env:OPENAI_API_KEY = $OPENAI_API_KEY
    $env:GEMINI_API_KEY = $GEMINI_API_KEY
    $env:GITHUB_PERSONAL_ACCESS_TOKEN = $GITHUB_PERSONAL_ACCESS_TOKEN
    $env:TAVILY_API_KEY = $TAVILY_API_KEY
    $env:ADO_MCP_AUTH_TOKEN = $ADO_MCP_AUTH_TOKEN
    $env:AZURE_DEVOPS_ORGANIZATION = $AZURE_DEVOPS_ORGANIZATION
    $env:POSTMAN_API_KEY = $POSTMAN_API_KEY
    $env:NEW_RELIC_API_KEY = $NEW_RELIC_API_KEY

    $env:AWS_ACCESS_KEY_ID = ""
    $env:AWS_SECRET_ACCESS_KEY = ""
    $env:AWS_REGION = ""
    $env:ANTHROPIC_BEDROCK_BASE_URL = ""
    $env:CLAUDE_CODE_USE_VERTEX = ""
    $env:ANTHROPIC_VERTEX_PROJECT_ID = ""
    $env:CLOUD_ML_REGION = ""
    $env:CLAUDE_CODE_USE_FOUNDRY = ""
    $env:AZURE_FOUNDRY_BASE_URL = ""
    $GPU_ENABLED = if ([string]::IsNullOrWhiteSpace($GPU_ENABLED)) { "false" } else { $GPU_ENABLED }
    $env:GPU_ENABLED = $GPU_ENABLED

    if ($DOCKER_REGISTRY -and $DOCKER_USERNAME -and $DOCKER_PASSWORD) {
        $DOCKER_PASSWORD | docker login $DOCKER_REGISTRY -u $DOCKER_USERNAME --password-stdin
    }

    # Build --profile flags from the server-profiles secret
    $profileArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($DEPLOY_PROFILES)) {
        foreach ($p in ($DEPLOY_PROFILES -split '\s+')) {
            if ($p -match '^(vscode|devcontainer|jupyter)$') {
                $profileArgs += '--profile'
                $profileArgs += $p
            } else {
                Write-Warning "Unknown server profile '$p' — valid: vscode, devcontainer, jupyter"
            }
        }
    }

    $gpuComposeArgs = @()
    if ($GPU_ENABLED -eq "true") {
        $gpuComposeArgs = @('-f', "$PSScriptRoot\..\docker\docker-compose.gpu.yml")
    }

    Write-Host ""
    Write-Host "Starting workspace with docker compose..."
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
    Write-Host "  AppHost Dashboard (when AppHost is running): http://localhost:$($env:ASPIRE_DASHBOARD_PORT)"
}
finally {
    & bw logout 2>$null | Out-Null

    @('WORKSPACE_NAME','SSH_PUBLIC_KEY','ADMIN_PASSWORD',
      'VSCODE_PORT','SSH_PORT','ASPIRE_DASHBOARD_PORT',
      'ANTHROPIC_API_KEY','CLAUDE_CODE_OAUTH_TOKEN',
      'OPENAI_API_KEY','GEMINI_API_KEY','GITHUB_PERSONAL_ACCESS_TOKEN',
      'TAVILY_API_KEY','ADO_MCP_AUTH_TOKEN','AZURE_DEVOPS_ORGANIZATION',
      'POSTMAN_API_KEY','NEW_RELIC_API_KEY','DOCKER_REGISTRY','DOCKER_USERNAME','DOCKER_PASSWORD',
      'DEPLOY_PROFILES','GPU_ENABLED',
      'AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AWS_REGION','ANTHROPIC_BEDROCK_BASE_URL',
      'CLAUDE_CODE_USE_VERTEX','ANTHROPIC_VERTEX_PROJECT_ID','CLOUD_ML_REGION',
      'CLAUDE_CODE_USE_FOUNDRY','AZURE_FOUNDRY_BASE_URL') | ForEach-Object {
        Remove-Item "Env:$_" -ErrorAction SilentlyContinue
    }
}
