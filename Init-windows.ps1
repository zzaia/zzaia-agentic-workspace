# Init-windows.ps1 - ZZAIA Workspace Launcher (Windows PowerShell)
param(
    [Parameter(Mandatory)][string]$SessionName,
    [switch]$FullAutomatic,
    [switch]$Tmux
)

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
$s = bw login --raw
$items = bw list items --session $s | ConvertFrom-Json
$env:TAVILY_API_KEY = ($items | Where-Object { $_.name -eq "tavily" }).login.password
$env:ADO_MCP_AUTH_TOKEN = ($items | Where-Object { $_.name -eq "azure-devops-pat" }).login.password
$env:AZURE_DEVOPS_ORGANIZATION = ($items | Where-Object { $_.name -eq "azure-devops-org" }).login.password
$env:POSTMAN_API_KEY = ($items | Where-Object { $_.name -eq "postman" }).login.password
$env:NEW_RELIC_API_KEY = ($items | Where-Object { $_.name -eq "new-relic" }).login.password
bw logout 2>$null | Out-Null; Remove-Variable s, items

$claudeFlags = if ($FullAutomatic) { "--dangerously-skip-permissions" } else { "--enable-auto-mode" }

$sessionUuid = python -c "import uuid, sys; print(uuid.uuid5(uuid.NAMESPACE_DNS, sys.argv[1]))" $SessionName

if ($Tmux) {
    tmux has-session -t $SessionName 2>$null
    if ($LASTEXITCODE -eq 0) {
        tmux attach-session -t $SessionName
        exit 0
    }
    $cmd = "if ! claude $claudeFlags --resume $sessionUuid; then claude $claudeFlags --session-id $sessionUuid; fi; exec bash"
    tmux new-session -s $SessionName $cmd
} else {
    & claude $claudeFlags --resume $sessionUuid
    if ($LASTEXITCODE -ne 0) {
        & claude $claudeFlags --session-id $sessionUuid
    }
}
