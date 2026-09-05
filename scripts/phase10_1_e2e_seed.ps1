[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$SeedE2eDev,
  [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'
$expectedRef = 'zykxneztahxbjduagutv'
$expectedHost = "db.$expectedRef.supabase.co"
$repoRoot = Split-Path -Parent $PSScriptRoot
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
if (-not (Test-Path $psql)) { throw 'REFUSED: PostgreSQL client not found.' }
if (-not (Test-Path (Join-Path $repoRoot '.env.dev.local'))) { throw 'REFUSED: .env.dev.local missing.' }

$envValues = @{}
Get-Content (Join-Path $repoRoot '.env.dev.local') |
  Where-Object { $_ -match '^\s*[^#].+=.*$' } |
  ForEach-Object { $kv = $_ -split '=', 2; $envValues[$kv[0].Trim()] = $kv[1].Trim().Trim('"') }
$db = $envValues['DEV_DATABASE_URL']
if ([string]::IsNullOrWhiteSpace($db)) { throw 'REFUSED: DEV_DATABASE_URL missing.' }
$uri = [Uri]$db
if ($uri.Host -ne $expectedHost) { throw "REFUSED: database host is not $expectedHost." }
if ((@($DryRun, $SeedE2eDev, $Cleanup) | Where-Object { $_ }).Count -ne 1) {
  throw 'Choose exactly one of -DryRun, -SeedE2eDev, or -Cleanup.'
}

$seedPredicate = "slug like 'e2e-%' and description = 'Deterministic BookMySpace DEV E2E listing.'"
$countSql = "select count(*) from public.venues where $seedPredicate;"
$existing = (& $psql $db -X -v ON_ERROR_STOP=1 -Atqc $countSql).Trim()
Write-Host "DEV preflight passed for project $expectedRef. Existing E2E listings: $existing"

if ($DryRun) {
  Write-Host 'Expected listings: 110'
  Write-Host "New deterministic records: $([Math]::Max(0, 110 - [int]$existing))"
  Write-Host 'Skipped existing deterministic records: rerunnable by stable IDs'
  exit 0
}

if ($Cleanup) {
  $cleanup = @"
begin;
with doomed as (select id from public.venues where $seedPredicate)
delete from public.pricing_rules where venue_id in (select id from doomed);
with doomed as (select id from public.venues where $seedPredicate)
delete from public.venue_operating_hours where venue_id in (select id from doomed);
with doomed as (select id from public.venues where $seedPredicate)
delete from public.time_slots where venue_id in (select id from doomed);
with doomed as (select id from public.venues where $seedPredicate)
delete from public.venue_facilities where venue_id in (select id from doomed);
with doomed as (select id from public.venues where $seedPredicate)
delete from public.venue_images where venue_id in (select id from doomed);
delete from public.venues where $seedPredicate;
commit;
"@
  & $psql $db -X -v ON_ERROR_STOP=1 -c $cleanup
  exit $LASTEXITCODE
}

if ($SeedE2eDev) {
  & $psql $db -X -v ON_ERROR_STOP=1 -v bms_dev=1 -v bms_project_ref=$expectedRef -f (Join-Path $repoRoot 'supabase\seed_phase10_1_e2e_110.sql')
  if ($LASTEXITCODE -ne 0) { throw 'DEV E2E seed failed; transaction was rolled back.' }
  & $psql $db -X -v ON_ERROR_STOP=1 -Atqc "select count(*) from public.venues where $seedPredicate;"
}
