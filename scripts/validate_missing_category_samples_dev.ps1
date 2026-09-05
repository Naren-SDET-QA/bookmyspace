[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot '.env.dev.local'
$expectedHost = 'db.zykxneztahxbjduagutv.supabase.co'

if (-not (Test-Path -LiteralPath $envFile)) {
  Write-Output 'DEV_DATABASE_URL: MISSING'
  Write-Output 'DEV_DATABASE_URL_MISSING'
  exit 2
}

$line = Get-Content -LiteralPath $envFile |
  Where-Object { $_ -match '^\s*DEV_DATABASE_URL\s*=' } |
  Select-Object -First 1
if (-not $line) {
  Write-Output 'DEV_DATABASE_URL: MISSING'
  Write-Output 'DEV_DATABASE_URL_MISSING'
  exit 2
}

$databaseUrl = ($line -replace '^\s*DEV_DATABASE_URL\s*=\s*', '').Trim().Trim('"').Trim("'")
try { $databaseUri = [Uri]$databaseUrl } catch {
  Write-Output 'DEV_DATABASE_URL: INVALID'
  exit 3
}
if ($databaseUri.Scheme -notin @('postgres', 'postgresql') -or
    $databaseUri.Host -ne $expectedHost) {
  Write-Output 'DEV_DATABASE_URL: INVALID_REMOTE_HOST'
  exit 4
}
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  Write-Output 'psql: MISSING'
  exit 5
}

$env:PGCONNECT_TIMEOUT = '10'
$fixture = Join-Path $repoRoot 'supabase\seed_missing_category_samples_dev.sql'

# The URL is passed directly to psql and is never echoed. bms_apply=0 selects
# the fixture's read-only branch; no INSERT/UPDATE/DELETE path is executed.
& psql $databaseUrl -X -v ON_ERROR_STOP=1 -v bms_apply=0 -f $fixture
if ($LASTEXITCODE -ne 0) {
  Write-Output 'DEV_DATABASE_URL: PRESENT'
  Write-Output 'Remote DEV database: FAIL'
  exit $LASTEXITCODE
}

Write-Output 'DEV_DATABASE_URL: PRESENT'
Write-Output 'Remote DEV database: VALID'
Write-Output 'Dry-run: PASS'
Write-Output 'Database writes: 0'
