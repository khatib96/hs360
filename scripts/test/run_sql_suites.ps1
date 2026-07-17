# SQL pollution gate:
# Phase A (baseline) -> Phase B (M3) -> Phase H (Phase 6 M1) -> Phase C (baseline).
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

Write-Host "Phase H: Phase 6 M1 contract settings and permissions"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_contract_settings_permissions.sql"

Write-Host "Phase I: Phase 6 M2 pricing and profit engine"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_contract_pricing_profit_engine.sql"

Write-Host "Phase J: Phase 6 M3 contract creation RPCs"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_contract_creation_rpc.sql"

Write-Host "Phase K: Phase 6 M4 contract lifecycle RPCs"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_contract_lifecycle_rpc.sql"

Write-Host "Phase L: Phase 6 M5 rental collection and billing engine"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_rental_collection_billing_engine.sql"

Write-Host "Phase K.5: Phase 6 M10b schedule consumable change RPCs"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_schedule_consumable_change_rpc.sql"

Write-Host "Phase M: Phase 6 M8 contract read RPCs"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_contract_read_rpc.sql"

Write-Host "Phase M11: Phase 6 contract PDF"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_contract_pdf.sql"

Write-Host "Phase M12: Phase 6 contract calendar handoff"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_contract_calendar_handoff.sql"
Write-Host "M12 concurrency gate is Bash/CI-only."

Write-Host "Phase N: Phase 6 M13 consolidated gap cases"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_contracts.sql"

Write-Host "Phase N.5: Phase 6 M13 list covered rental months RPC (092)"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_6_list_covered_rental_months_rpc.sql"

Write-Host "Phase O: Phase 7 M1 calendar working schedule"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_7_calendar_working_schedule.sql"

Write-Host "Phase P: Phase 7 M2 calendar event generation engine"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_7_calendar_event_generation_engine.sql"
& "$repoRoot/supabase/tests/phase_7_calendar_event_generation_engine_concurrency.sh" $ContainerName

Write-Host "Phase Q: Phase 7 M3 calendar reminders"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_7_calendar_reminders.sql"
& "$repoRoot/supabase/tests/phase_7_calendar_reminders_concurrency.sh" $ContainerName
& "$repoRoot/supabase/tests/phase_7_calendar_reminders_reconcile_concurrency.sh" $ContainerName

Write-Host "Phase R: Phase 7 M4 calendar read RPCs"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_7_calendar_read_rpc.sql"

Write-Host "Phase S: Phase 7 M7A manual business events"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_7_manual_business_events.sql"
& "$repoRoot/supabase/tests/phase_7_manual_meeting_notice_concurrency.sh" $ContainerName

Write-Host "Phase T: Phase 7 M7B working-date exceptions"
Invoke-SqlSuite -SuitePath "supabase/tests/phase_7_working_date_exceptions.sql"
& "$repoRoot/supabase/tests/phase_7_working_date_exceptions_concurrency.sh" $ContainerName
& "$repoRoot/supabase/tests/phase_7_working_date_exceptions_idempotency_concurrency.sh" $ContainerName

Write-Host "Phase C: baseline regression (pollution gate)"
foreach ($suite in $phaseAAllowlist) {
  Invoke-SqlSuite -SuitePath $suite
}

Write-Host "All SQL suite phases passed."
