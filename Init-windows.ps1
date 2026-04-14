# Init-windows.ps1 - ZZAIA Workspace Launcher (Windows PowerShell)
param(
    [Parameter(Mandatory)][string]$SessionName,
    [switch]$FullAutomatic,
    [switch]$Tmux
)

$s = bw login --raw
$env:TAVILY_API_KEY = bw get password tavily --session $s
$env:ADO_MCP_AUTH_TOKEN = bw get password azure-devops-pat --session $s
$env:AZURE_DEVOPS_ORGANIZATION = bw get password azure-devops-org --session $s
$env:POSTMAN_API_KEY = bw get password postman --session $s
$env:NEW_RELIC_API_KEY = bw get password new-relic --session $s
bw logout 2>$null | Out-Null; Remove-Variable s

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
