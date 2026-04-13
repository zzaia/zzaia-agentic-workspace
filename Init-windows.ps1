# Init-windows.ps1 - ZZAIA Workspace Launcher (Windows PowerShell)
param(
    [string]$SessionName = "",
    [string]$Email = "",
    [switch]$FullAutomatic,
    [switch]$Tmux
)

if ($Email) { bw login "$Email" 2>$null } else { bw login 2>$null }
$s = bw unlock --raw
$env:TAVILY_API_KEY = bw get password tavily --session $s
$env:ADO_MCP_AUTH_TOKEN = bw get password azure-devops-pat --session $s
$env:AZURE_DEVOPS_ORGANIZATION = bw get password azure-devops-org --session $s
$env:POSTMAN_API_KEY = bw get password postman --session $s
$env:NEW_RELIC_API_KEY = bw get password new-relic --session $s
bw lock --session $s 2>$null | Out-Null; Remove-Variable s

$claudeFlags = if ($FullAutomatic) { "--dangerously-skip-permissions" } else { "--enable-auto-mode" }

$sessionUuid = ""
if ($SessionName) {
    $sessionUuid = python -c "import uuid, sys; print(uuid.uuid5(uuid.NAMESPACE_DNS, sys.argv[1]))" $SessionName
}

if ($Tmux) {
    $tmuxSession = if ($SessionName) { $SessionName } else { "zzaia" }
    tmux has-session -t $tmuxSession 2>$null
    if ($LASTEXITCODE -eq 0) {
        tmux attach-session -t $tmuxSession
        exit 0
    }
    if ($sessionUuid) {
        $cmd = "if ! claude $claudeFlags --resume $sessionUuid; then claude $claudeFlags --session-id $sessionUuid; fi; exec bash"
    } else {
        $cmd = "claude $claudeFlags; exec bash"
    }
    tmux new-session -s $tmuxSession $cmd
} elseif ($sessionUuid) {
    & claude $claudeFlags --resume $sessionUuid
    if ($LASTEXITCODE -ne 0) {
        & claude $claudeFlags --session-id $sessionUuid
    }
} else {
    & claude $claudeFlags
}
