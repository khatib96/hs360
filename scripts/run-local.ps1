# Runs Flutter with local Supabase credentials from `supabase status` (never writes keys to disk).
param(
  [string]$Device = "windows"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$statusOutput = npx supabase status -o env 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
  Write-Error "supabase status failed. Run: npx supabase start"
}

$apiUrl = "http://127.0.0.1:54321"
$anonKey = ""

foreach ($line in $statusOutput -split "`n") {
  if ($line -match '^API_URL="(.+)"$') { $apiUrl = $Matches[1] }
  if ($line -match '^ANON_KEY="(.+)"$') { $anonKey = $Matches[1] }
}

if ([string]::IsNullOrWhiteSpace($anonKey)) {
  Write-Error "ANON_KEY not found in supabase status output."
}

Write-Host "Using API_URL=$apiUrl"
Write-Host "Starting Flutter on device: $Device"

flutter run -d $Device `
  --dart-define=SUPABASE_URL=$apiUrl `
  --dart-define=SUPABASE_ANON_KEY=$anonKey
