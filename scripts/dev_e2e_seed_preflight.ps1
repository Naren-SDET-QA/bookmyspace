[CmdletBinding()]
param(
  [switch]$RunSeed,
  [switch]$VerifyOnly,
  [int]$BmsDev = 0
)

$ErrorActionPreference = 'Stop'
$expectedRef = 'zykxneztahxbjduagutv'
$expectedHost = "db.$expectedRef.supabase.co"

if ([string]::IsNullOrWhiteSpace($env:DEV_DATABASE_URL)) {
  throw 'REFUSED: DEV_DATABASE_URL is not configured.'
}

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  throw 'REFUSED: psql is required but was not found on PATH.'
}

try {
  $connectionUri = [Uri]$env:DEV_DATABASE_URL
} catch {
  throw 'REFUSED: DEV_DATABASE_URL is not a valid PostgreSQL connection URI.'
}

if ($connectionUri.Scheme -notin @('postgres', 'postgresql')) {
  throw 'REFUSED: DEV_DATABASE_URL must use the postgres or postgresql scheme.'
}

if ($connectionUri.Host -ne $expectedHost) {
  throw "REFUSED: database host does not match the BookMySpace DEV project ref $expectedRef."
}

if (-not $RunSeed -and -not $VerifyOnly) {
  throw 'REFUSED: pass -RunSeed or -VerifyOnly explicitly.'
}

if ($RunSeed -and $BmsDev -ne 1) {
  throw 'REFUSED: pass -BmsDev 1 explicitly to authorize the DEV seed.'
}

$readOnlyQuery = @'
select json_build_object(
  'database', current_database(),
  'host', inet_server_addr()::text,
  'project_ref_host_match', (inet_server_addr() is not null)
)::text;
'@

# DEV_DATABASE_URL is passed through to psql without echoing it. The query is
# read-only and returns no credentials, password, token, or connection string.
$probe = & psql $env:DEV_DATABASE_URL -X -v ON_ERROR_STOP=1 -Atqc $readOnlyQuery 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($probe -join ''))) {
  throw 'REFUSED: read-only connection probe failed.'
}

Write-Host "DEV preflight passed for Supabase project ref $expectedRef."

if ($RunSeed) {
  & psql $env:DEV_DATABASE_URL -X -v ON_ERROR_STOP=1 -v bms_dev=1 -v bms_project_ref=$expectedRef -f (Join-Path $PSScriptRoot '..\supabase\seed_dev_e2e.sql')
  if ($LASTEXITCODE -ne 0) {
    throw 'DEV seed failed.'
  }
}

if ($RunSeed -or $VerifyOnly) {
  & psql $env:DEV_DATABASE_URL -X -v ON_ERROR_STOP=1 -f (Join-Path $PSScriptRoot '..\supabase\tests\dev_e2e_seed_verify.sql')
  if ($LASTEXITCODE -ne 0) {
    throw 'DEV seed verification failed.'
  }
}
