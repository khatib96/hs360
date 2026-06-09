param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('windows', 'android')]
  [string]$Platform,

  [Parameter(Mandatory = $true)]
  [string]$DeviceId,

  [switch]$UpdateGoldens,
  [int]$TimeoutSeconds = 1200
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

$driveArgs = @(
  'drive',
  '--driver=test_driver/pdf_golden_driver.dart',
  '--target=integration_test/documents/pdf_golden_test.dart',
  '-d', $DeviceId,
  '--dart-define=PDF_GOLDEN_DRIVER_MODE=true',
  "--dart-define=GOLDEN_PLATFORM=$Platform"
)
if ($UpdateGoldens) {
  $driveArgs += '--dart-define=UPDATE_PDF_GOLDENS=true'
}

Write-Host "Running PDF goldens for $Platform on $DeviceId (update=$UpdateGoldens)"

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

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
if (-not $process.Start()) {
  throw 'Unable to start PDF golden process'
}
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
  $process.Kill()
  throw "PDF goldens timed out after ${TimeoutSeconds}s"
}
$process.WaitForExit()

$stdout = $stdoutTask.Result
$stderr = $stderrTask.Result
if (-not [string]::IsNullOrWhiteSpace($stdout)) {
  Write-Host $stdout.TrimEnd()
}
if (-not [string]::IsNullOrWhiteSpace($stderr)) {
  Write-Host $stderr.TrimEnd()
}

if ($process.ExitCode -ne 0) {
  throw "PDF goldens failed with exit code $($process.ExitCode)"
}

Write-Host "PDF goldens passed for $Platform (update=$UpdateGoldens)"
