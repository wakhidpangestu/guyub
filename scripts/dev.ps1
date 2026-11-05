<#
.SYNOPSIS
  Starts the Guyub development stack on Windows.

.DESCRIPTION
  1. Checks Node, Java, and Flutter.
  2. Installs npm dependencies on first run and builds Cloud Functions.
  3. Starts the Firebase emulators in a separate window (skipped if already running).
  4. Seeds demo accounts on first run, or when -Seed is passed.
  5. Runs the Flutter web app in Chrome against the emulators.

  Stop the emulators with Ctrl+C in their window. That saves accounts and
  data to .emulator-data so the next run starts where you left off.

.EXAMPLE
  .\scripts\dev.ps1
  Emulators + app. Seeds demo accounts the first time.

.EXAMPLE
  .\scripts\dev.ps1 -Seed
  Also recreate the demo accounts and their roles.

.EXAMPLE
  .\scripts\dev.ps1 -NoApp
  Emulators only, for example to run tests or the app yourself.
#>
param(
  [switch]$Seed,
  [switch]$NoApp
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Assert-Command([string]$Name, [string]$Hint) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name was not found on PATH. $Hint See README.md > Development setup."
  }
}

function Test-Port([int]$Port) {
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $client.Connect('127.0.0.1', $Port)
    $client.Close()
    return $true
  } catch {
    return $false
  }
}

Assert-Command 'node' 'Install Node.js 22 or newer.'
Assert-Command 'java' 'Install Java 21 or newer (needed by the Firestore and Storage emulators).'
if (-not $NoApp) { Assert-Command 'flutter' 'Install Flutter 3.47.9 and add flutter\bin to PATH.' }

if (-not (Test-Path 'node_modules')) {
  Write-Host '> Installing root dev tools (Firebase CLI, rules test kit)...'
  npm install --no-audit --no-fund
}
if (-not (Test-Path 'functions/node_modules')) {
  Write-Host '> Installing Cloud Functions dependencies...'
  npm --prefix functions install --no-audit --no-fund
}

Write-Host '> Building Cloud Functions...'
npm --prefix functions run build
if ($LASTEXITCODE -ne 0) { throw 'Cloud Functions build failed.' }

# Auth 9099, Firestore 8080, Functions 5001, Storage 9199.
$ports = 9099, 8080, 5001, 9199
$firstRun = -not (Test-Path '.emulator-data')

if (-not (Test-Port 9099)) {
  Write-Host '> Starting Firebase emulators in a new window...'
  Start-Process powershell -ArgumentList '-NoExit', '-Command', "Set-Location '$root'; npm run emulators"

  $deadline = (Get-Date).AddMinutes(3)
  while (@($ports | Where-Object { -not (Test-Port $_) }).Count -gt 0) {
    if ((Get-Date) -gt $deadline) { throw 'Emulators did not start within 3 minutes. Check the emulator window for errors.' }
    Start-Sleep -Seconds 2
  }
} else {
  Write-Host '> Emulators already running.'
}
Write-Host '  Emulator UI: http://localhost:4000'

if ($Seed -or $firstRun) {
  Write-Host '> Seeding demo accounts...'
  npm run seed
  if ($LASTEXITCODE -ne 0) { throw 'Seeding failed.' }
}

if ($NoApp) {
  Write-Host '> Done. Run the app with:'
  Write-Host '  cd apps/dashboard; flutter run -d chrome --web-port 8090 --dart-define-from-file=env/emulator.json'
  return
}

Write-Host '> Starting the Flutter web app (r = hot reload, R = hot restart, q = quit)...'
Set-Location (Join-Path $root 'apps/dashboard')
flutter run -d chrome --web-port 8090 --dart-define-from-file=env/emulator.json
