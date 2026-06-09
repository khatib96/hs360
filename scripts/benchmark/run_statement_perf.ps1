# M3 statement render benchmark wrapper (plan section 10.1).
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('windows', 'android')]
  [string]$Platform,

  [Parameter(Mandatory = $true)]
  [string]$DeviceId,

  [int]$StatementRowCap = 0,
  [int]$WarmupRuns = 1,
  [int]$MeasuredRuns = 3,
  [string]$ContainerName = 'supabase_db_hs360',
  [int]$TimeoutSeconds = 1800
)

$ErrorActionPreference = 'Stop'

$utf8 = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $utf8
[Console]::OutputEncoding = $utf8

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot
$benchmarkStartedAt = [DateTime]::UtcNow

function Get-FlutterVersion {
  $raw = flutter --version --machine 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to read Flutter version: $raw"
  }
  try {
    return (($raw | Out-String) | ConvertFrom-Json).frameworkVersion
  } catch {
    throw "Unable to parse Flutter version: $raw"
  }
}

function Get-GitSha {
  $raw = git rev-parse --short HEAD 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to read git SHA: $raw"
  }
  return ($raw | Out-String).Trim()
}

function Resolve-Adb {
  $command = Get-Command adb -ErrorAction SilentlyContinue
  if ($null -ne $command) {
    return $command.Source
  }

  $candidates = @(
    $(if ($env:LOCALAPPDATA) {
      Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    }),
    $(if ($env:ANDROID_HOME) {
      Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
    }),
    $(if ($env:ANDROID_SDK_ROOT) {
      Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
    })
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  throw 'adb.exe was not found on PATH or in the configured Android SDK'
}

function Get-DbStatementRowCap {
  param([string]$Container)
  $sql = 'select public.m3_statement_row_limit();'
  $raw = $sql | docker exec -i $Container psql -U postgres -d postgres -t -A 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to read m3_statement_row_limit from DB: $raw"
  }
  $value = [int]($raw.Trim())
  if ($value -le 0) {
    throw "Invalid m3_statement_row_limit value from DB: $raw"
  }
  return $value
}

$resolvedCap = $StatementRowCap
if ($resolvedCap -le 0) {
  $resolvedCap = Get-DbStatementRowCap -Container $ContainerName
  Write-Host "StatementRowCap resolved from DB: $resolvedCap"
} else {
  $dbCap = Get-DbStatementRowCap -Container $ContainerName
  if ($resolvedCap -ne $dbCap) {
    throw "StatementRowCap mismatch: parameter=$resolvedCap DB=$dbCap"
  }
  Write-Host "StatementRowCap confirmed against DB: $resolvedCap"
}

$driveArgs = @(
  'drive',
  '--profile',
  '-d', $DeviceId,
  '--driver=test_driver/benchmark_driver.dart',
  '--target=integration_test/documents/statement_perf_test.dart',
  "--dart-define=STATEMENT_ROW_CAP=$resolvedCap",
  "--dart-define=BENCHMARK_WARMUP_RUNS=$WarmupRuns",
  "--dart-define=BENCHMARK_MEASURED_RUNS=$MeasuredRuns",
  "--dart-define=BENCHMARK_FLUTTER_VERSION=$(Get-FlutterVersion)",
  "--dart-define=BENCHMARK_GIT_SHA=$(Get-GitSha)"
)

if ($Platform -eq 'android') {
  $driveArgs += "--dart-define=BENCHMARK_ADB_PATH=$(Resolve-Adb)"
}

Write-Host "Running: flutter $($driveArgs -join ' ')"

$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$quotedArgs = $driveArgs | ForEach-Object {
  '"' + $_.Replace('"', '\"') + '"'
}
$commandLine = '""' + $flutterCommand + '" ' + ($quotedArgs -join ' ') + '"'

$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $env:ComSpec
$startInfo.Arguments = '/d /s /c ' + $commandLine
$startInfo.WorkingDirectory = $repoRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $startInfo
if (-not $proc.Start()) {
  throw 'Unable to start flutter drive benchmark process'
}
$stdoutTask = $proc.StandardOutput.ReadToEndAsync()
$stderrTask = $proc.StandardError.ReadToEndAsync()
if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
  $proc.Kill()
  throw "Benchmark timed out after ${TimeoutSeconds}s"
}
$proc.WaitForExit()

$stdout = $stdoutTask.Result
$stderr = $stderrTask.Result
if (-not [string]::IsNullOrWhiteSpace($stdout)) {
  Write-Host $stdout.TrimEnd()
}
if (-not [string]::IsNullOrWhiteSpace($stderr)) {
  Write-Host $stderr.TrimEnd()
}

$exitCode = $proc.ExitCode
if ($exitCode -ne 0) {
  throw "flutter drive benchmark failed with exit code $exitCode"
}

$result = Get-ChildItem -Path (Join-Path $repoRoot 'scripts\benchmark\results') `
  -Filter "statement_perf_${Platform}_*.json" -File -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTimeUtc -ge $benchmarkStartedAt.AddSeconds(-2) } |
  Sort-Object LastWriteTimeUtc -Descending |
  Select-Object -First 1

if ($null -eq $result) {
  throw 'Benchmark process exited without producing a new result artifact'
}

$json = Get-Content -Raw -Encoding utf8 $result.FullName | ConvertFrom-Json
if ($json.passed -ne $true) {
  throw "Benchmark artifact reports failure: $($result.FullName)"
}
if ([int]$json.statement_row_cap -ne $resolvedCap) {
  throw "Benchmark artifact cap mismatch: artifact=$($json.statement_row_cap) expected=$resolvedCap"
}
if ([int]$json.measured_runs -ne $MeasuredRuns) {
  throw "Benchmark artifact measured run mismatch: artifact=$($json.measured_runs) expected=$MeasuredRuns"
}
if ([int]$json.warmup_runs -ne $WarmupRuns) {
  throw "Benchmark artifact warmup run mismatch: artifact=$($json.warmup_runs) expected=$WarmupRuns"
}
if (@($json.runs | Where-Object { $_.kind -eq 'measured' }).Count -ne $MeasuredRuns) {
  throw 'Benchmark artifact does not contain the expected measured run records'
}
if (@($json.runs | Where-Object { $_.kind -eq 'warmup' }).Count -ne $WarmupRuns) {
  throw 'Benchmark artifact does not contain the expected warmup run records'
}
if ($json.platform -ne $Platform) {
  throw "Benchmark artifact platform mismatch: artifact=$($json.platform) expected=$Platform"
}
if ([string]::IsNullOrWhiteSpace($json.flutter_version) -or $json.flutter_version -eq 'unknown') {
  throw 'Benchmark artifact is missing flutter_version'
}
if ([string]::IsNullOrWhiteSpace($json.git_sha) -or $json.git_sha -eq 'unknown') {
  throw 'Benchmark artifact is missing git_sha'
}

Write-Host "Benchmark completed for $Platform (cap=$resolvedCap): $($result.Name)"
