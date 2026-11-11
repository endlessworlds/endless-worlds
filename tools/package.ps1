# Builds everything you hand to players.
#
#   powershell -ExecutionPolicy Bypass -File tools\package.ps1
#   powershell -ExecutionPolicy Bypass -File tools\package.ps1 -Godot "C:\Godot\Godot_v4.5.1-stable_win64_console.exe"
#
# Output (in build\):
#   EndlessWorlds-Windows.zip       the game (one .exe, relay URL baked in) - give this to every player
#   EndlessWorlds-AI-Server.zip     the Python AI server - only the host needs it
#   web\                            HTML5 build for GitHub Pages / itch.io
#
# The game only reads RELAY_URL / API_URL from .env, so the game build always gets a
# filtered .env: API keys never ship inside EndlessWorlds.exe or the web build.
# -Public: the AI-server zip gets .env.example instead of your keys (for GitHub releases).
#
# Needs Godot 4.5.1 with export templates installed (Editor > Manage Export Templates).

param(
    [string]$Godot = $env:GODOT,
    [switch]$SkipWeb,
    [switch]$Public
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not $Godot) { $Godot = "godot" }
if (-not (Get-Command $Godot -ErrorAction SilentlyContinue)) {
    throw "Godot not found. Pass -Godot <path to Godot_v4.5.1-stable_win64_console.exe> or set `$env:GODOT."
}
if (-not (Test-Path ".env")) {
    Write-Warning ".env is missing: the build will have no RELAY_URL / API keys (multiplayer falls back to the default relay)."
}

$build = Join-Path $root "build"
Remove-Item -Recurse -Force $build -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$build\windows", "$build\web", "$build\server" | Out-Null

# Swap in a keys-free .env while exporting; always put the real one back.
$envBackup = Join-Path $build "env.backup"
if (Test-Path ".env") { Copy-Item ".env" $envBackup -Force }
try {
    $clientEnv = @()
    if (Test-Path $envBackup) {
        $clientEnv = Get-Content $envBackup | Where-Object { $_ -match '^\s*(RELAY_URL|API_URL)\s*=' }
    }
    Set-Content -Encoding utf8 ".env" ($clientEnv -join "`n")

    Write-Host "==> Importing assets"
    & $Godot --headless --path $root --import | Out-Null

    Write-Host "==> Exporting Windows build"
    & $Godot --headless --path $root --export-release "Windows Desktop" "build/windows/EndlessWorlds.exe"
    if (-not (Test-Path "$build\windows\EndlessWorlds.exe")) { throw "Windows export failed (are export templates installed?)" }

    if (-not $SkipWeb) {
        Write-Host "==> Exporting Web build"
        & $Godot --headless --path $root --export-release "Web" "build/web/index.html"
        # "Add to Home Screen" manifest + icons (fullscreen app on phones)
        Copy-Item "$root\web\manifest.webmanifest", "$root\web\icon_*.png" "$build\web\" -Force
    }
}
finally {
    if (Test-Path $envBackup) { Copy-Item $envBackup ".env" -Force; Remove-Item $envBackup }
    else { Remove-Item ".env" -ErrorAction SilentlyContinue }
}

@"
ENDLESS WORLDS
==============
1. Double-click EndlessWorlds.exe  (Windows may say "unknown publisher": More info > Run anyway)
2. Solo: type a topic and press START.
3. Together: click Multiplayer > Create room, send the 5-letter code to your friends,
   they click Multiplayer > type the code > Join. Up to 10 players.

Controls: WASD move - Shift sprint - V talk to Bolt - F torch - T chat - Esc pause
Click Bolt (the robot) for voice, typing, torch and chat buttons.

AI riddles and Bolt's voice need the AI server running on the HOST's computer
(EndlessWorlds-AI-Server.zip > start_server.bat). Without it the game uses its
built-in question bank and everything else still works.
"@ | Set-Content -Encoding utf8 "$build\windows\PLAY.txt"
Compress-Archive -Force -Path "$build\windows\*" -DestinationPath "$build\EndlessWorlds-Windows.zip"

Write-Host "==> Packaging AI server (host only)"
Copy-Item -Recurse "python_server\*" "$build\server\" -Exclude "venv", "__pycache__", "tests", ".gdignore"
Get-ChildItem "$build\server" -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force
if ($Public -or -not (Test-Path ".env")) { Copy-Item ".env.example" "$build\.env.server" }
else { Copy-Item ".env" "$build\.env.server" }
# main.py reads ../.env, so ship the server inside a folder with .env beside it
$srvRoot = Join-Path $build "server-package"
New-Item -ItemType Directory -Force "$srvRoot\python_server" | Out-Null
Copy-Item -Recurse "$build\server\*" "$srvRoot\python_server\"
if (Test-Path "$build\.env.server") { Copy-Item "$build\.env.server" "$srvRoot\.env" }
@"
Host only. Needs Python 3.10+ (python.org, tick "Add to PATH").
Put your free Groq key (https://console.groq.com) in .env as GROQ_API_KEY=... if it's empty.
Double-click python_server\start_server.bat - first run installs packages (a few minutes).
Keep the window open while you play; the game finds it at http://127.0.0.1:8000.
"@ | Set-Content -Encoding utf8 "$srvRoot\README.txt"
Compress-Archive -Force -Path "$srvRoot\*" -DestinationPath "$build\EndlessWorlds-AI-Server.zip"
Remove-Item -Recurse -Force "$build\server", "$srvRoot", "$build\.env.server" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Done:" -ForegroundColor Green
Get-ChildItem $build -File | ForEach-Object { "  {0,-34} {1,8:N1} MB" -f $_.Name, ($_.Length / 1MB) }
if (-not $SkipWeb) { Write-Host "  web\ (upload to GitHub Pages / itch.io)" }
