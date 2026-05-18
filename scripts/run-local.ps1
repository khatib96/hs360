# Runs Flutter with local Supabase credentials.
# If the key is passed manually once, it is cached under ignored supabase/.temp.
param(
  [string]$Device = "windows",
  [string]$SupabaseUrl = "http://127.0.0.1:54321",
  [string]$SupabaseAnonKey = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$localEnvPath = Join-Path $repoRoot "supabase\.temp\local-run.env"
$apiUrl = $SupabaseUrl
$anonKey = $SupabaseAnonKey

if ([string]::IsNullOrWhiteSpace($anonKey) -and (Test-Path $localEnvPath)) {
  foreach ($line in Get-Content $localEnvPath) {
    $cleanLine = $line.Trim()
    if ($cleanLine -match '^API_URL="?([^"]+)"?$') { $apiUrl = $Matches[1] }
    if ($cleanLine -match '^ANON_KEY="?([^"]+)"?$') { $anonKey = $Matches[1] }
  }
}

if ([string]::IsNullOrWhiteSpace($anonKey)) {
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $statusOutput = npx --yes supabase status -o env 2>&1 | Out-String
  $statusExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference

  if ($statusExitCode -ne 0) {
    Write-Error "supabase status failed. Run: npx --yes supabase start"
  }

  foreach ($line in $statusOutput -split "`n") {
    $cleanLine = $line.Trim()
    if ($cleanLine -match '^API_URL="?([^"]+)"?$') { $apiUrl = $Matches[1] }
    if ($cleanLine -match '^ANON_KEY="?([^"]+)"?$') { $anonKey = $Matches[1] }
  }

  if ([string]::IsNullOrWhiteSpace($anonKey)) {
    $statusPreview = ($statusOutput -split "`n" | Select-Object -First 12) -join "`n"
    Write-Error "ANON_KEY not found in supabase status output. Output preview:`n$statusPreview"
  }
}

if (-not [string]::IsNullOrWhiteSpace($anonKey)) {
  New-Item -ItemType Directory -Force (Split-Path -Parent $localEnvPath) | Out-Null
  @(
    "API_URL=""$apiUrl"""
    "ANON_KEY=""$anonKey"""
  ) | Set-Content -Path $localEnvPath -Encoding UTF8
}

Write-Host "Using API_URL=$apiUrl"
Write-Host "Starting Flutter on device: $Device"

flutter run -d $Device `
  --dart-define=SUPABASE_URL=$apiUrl `
  --dart-define=SUPABASE_ANON_KEY=$anonKey
