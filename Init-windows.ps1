# Init-windows.ps1 - ZZAIA Workspace Launcher (Windows PowerShell)
bw login 2>$null
$s = bw unlock --raw
$env:TAVILY_API_KEY = bw get password tavily --session $s
$env:ADO_MCP_AUTH_TOKEN = bw get password azure-devops-pat --session $s
$env:AZURE_DEVOPS_ORGANIZATION = bw get password azure-devops-org --session $s
$env:POSTMAN_API_KEY = bw get password postman --session $s
$env:NEW_RELIC_API_KEY = bw get password new-relic --session $s
bw lock --session $s 2>$null | Out-Null; Remove-Variable s
claude --enable-auto-mode
