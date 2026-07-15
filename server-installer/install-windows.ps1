param(
    [string]$InstallRoot = "C:\ARKAIOS-SERVER",
    [string]$Repo = "https://github.com/djklmr2025/arkaios-retro-launcher-wii.git",
    [int]$Port = 8787
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git no esta instalado."
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js no esta instalado."
}

$serverDir = Join-Path $InstallRoot "server"
$dataDir = Join-Path $InstallRoot "data"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

if (Test-Path (Join-Path $serverDir ".git")) {
    git -C $serverDir pull --ff-only
}
else {
    git clone $Repo $serverDir
}

Push-Location $serverDir
npm install --omit=dev
Pop-Location

$runner = Join-Path $InstallRoot "start-arkaios-node.ps1"
@"
`$env:ARKAIOS_NODE_HOST='0.0.0.0'
`$env:ARKAIOS_NODE_PORT='$Port'
`$env:ARKAIOS_NODE_DATA='$dataDir'
Set-Location '$serverDir'
node server\arkaios-node-server.mjs
"@ | Set-Content -LiteralPath $runner -Encoding UTF8

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "ARKAIOS Node Server" -Action $action -Trigger $trigger -Description "ARKAIOS Wii Node Server" -Force | Out-Null

Write-Host "Instalacion Windows completada."
Write-Host "Ejecuta ahora: powershell -ExecutionPolicy Bypass -File `"$runner`""
