# M3 SQL pollution gate: Phase A (baseline) -> Phase B (M3) -> Phase C (baseline).
# Run after: npx --yes supabase db reset
param(
  [string]$ContainerName = "supabase_db_hs360"
)

$ErrorActionPreference = "Stop"

$utf8 = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $utf8
[Console]::OutputEncoding = $utf8

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

$phaseAAllowlist = @(
  "supabase/tests/phase_1d_rls.sql"
  "supabase/tests/phase_3_products_inventory.sql"
  "supabase/tests/phase_4_customers_suppliers_coa.sql"
  "supabase/tests/phase_4_customer_service_locations.sql"
  "supabase/tests/phase_4_service_location_coordinates.sql"
  "supabase/tests/phase_5_finance_foundation.sql"
  "supabase/tests/phase_5_asset_identity.sql"
  "supabase/tests/phase_5_m1_m2_hardening.sql"
)

$denylist = @(
  "supabase/tests/phase_3_inventory_performance_seed.sql"
  "supabase/tests/phase_5_document_templates.sql"
  "supabase/tests/phase_5_document_templates_validation.sql"
)

$phaseBSuites = @(
  "supabase/tests/phase_5_document_templates.sql"
  "supabase/tests/phase_5_document_templates_validation.sql"
)

function Test-SuiteAllowed {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SuitePath
  )

  foreach ($denied in $denylist) {
    if ($SuitePath -eq $denied) {
      return $false
    }
    if ($SuitePath -like "*performance*seed*") {
      return $false
    }
  }

  return $true
}

function Invoke-SqlSuite {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SuitePath,
    [switch]$AllowDenylisted
  )

  if (-not $AllowDenylisted -and -not (Test-SuiteAllowed -SuitePath $SuitePath)) {
    throw "suite is denylisted: $SuitePath"
  }

  $fullPath = Join-Path $repoRoot $SuitePath
  if (-not (Test-Path $fullPath)) {
    throw "suite not found: $SuitePath"
  }

  Write-Host "Running $SuitePath ..."
  $sql = Get-Content -Raw -Encoding utf8 $fullPath
  $sql | docker exec -i $ContainerName psql -U postgres -d postgres -v ON_ERROR_STOP=1
  if ($LASTEXITCODE -ne 0) {
    throw "suite failed: $SuitePath"
  }
}

Write-Host "Phase A: baseline regression (excluding M3 suites)"
foreach ($suite in $phaseAAllowlist) {
  Invoke-SqlSuite -SuitePath $suite
}

Write-Host "Phase B: M3 document template suites"
foreach ($suite in $phaseBSuites) {
  Invoke-SqlSuite -SuitePath $suite -AllowDenylisted
}

Write-Host "Phase C: baseline regression (pollution gate)"
foreach ($suite in $phaseAAllowlist) {
  Invoke-SqlSuite -SuitePath $suite
}

Write-Host "All SQL suite phases passed."
