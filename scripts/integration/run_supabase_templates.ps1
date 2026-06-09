# Runs integration tests against local Supabase with platform-specific API URL.
param(
  [ValidateSet('windows', 'android')]
  [string]$Platform = 'windows',
  [string]$DeviceId = 'windows',
  [string]$AdbPath = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

function Resolve-Adb {
  if (-not [string]::IsNullOrWhiteSpace($AdbPath)) {
    if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
      throw "Configured adb path does not exist: $AdbPath"
    }
    return (Resolve-Path -LiteralPath $AdbPath).Path
  }

  $command = Get-Command adb -ErrorAction SilentlyContinue
  if ($null -ne $command) { return $command.Source }

  $candidates = @(
    $(if ($env:ANDROID_SDK_ROOT) { Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe' }),
    $(if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe' }),
    $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe' }),
    $(if ($env:USERPROFILE) { Join-Path $env:USERPROFILE 'AppData\Local\Android\sdk\platform-tools\adb.exe' })
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  throw 'adb not found; add Android SDK platform-tools to PATH or set ANDROID_SDK_ROOT'
}

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$raw = (npx supabase status -o env 2>&1 | Out-String)
$statusCode = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($statusCode -ne 0) { throw "supabase status failed: $raw" }
$lines = $raw -split "`r?`n"
foreach ($line in $lines) {
  if ($line -match '^ANON_KEY=(.+)$') {
    $anonKey = $Matches[1].Trim().Trim('"')
  }
  if ($line -match '^API_URL=(.+)$') {
    $apiUrl = $Matches[1].Trim().Trim('"')
  }
}
if ([string]::IsNullOrWhiteSpace($anonKey)) { throw 'ANON_KEY missing from supabase status' }
if ([string]::IsNullOrWhiteSpace($apiUrl)) {
  $apiUrl = 'http://127.0.0.1:54321'
  Write-Host 'API_URL missing from supabase status; using default local URL'
}

$resolvedUrl = switch ($Platform) {
  'windows' { $apiUrl }
  'android' {
    $adb = Resolve-Adb
    $reverseOutput = & $adb -s $DeviceId reverse tcp:54321 tcp:54321 2>&1
    $reverseExitCode = $LASTEXITCODE
    if ($reverseExitCode -ne 0) {
      throw "adb reverse failed: $reverseOutput"
    }
    'http://127.0.0.1:54321'
  }
}

Write-Host "Using SUPABASE_URL=$resolvedUrl (status API_URL=$apiUrl)"
Write-Host "Running integration tests on device: $DeviceId"

flutter test integration_test/documents/supabase_seeded_templates_test.dart -d $DeviceId `
  --dart-define=SUPABASE_ANON_KEY=$anonKey `
  --dart-define=SUPABASE_URL=$resolvedUrl

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
