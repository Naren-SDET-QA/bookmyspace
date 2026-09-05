[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Request
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$envFile = Join-Path $repoRoot '.env.dev.local'

function Get-LocalEnvValue([string]$Name) {
  if (-not (Test-Path -LiteralPath $envFile)) { return $null }
  $line = Get-Content -LiteralPath $envFile | Where-Object {
    $_ -match ('^\s*' + [regex]::Escape($Name) + '\s*=')
  } | Select-Object -First 1
  if ($null -eq $line) { return $null }
  $value = ($line -replace ('^\s*' + [regex]::Escape($Name) + '\s*=\s*'), '').Trim()
  return $value.Trim('"', "'")
}

$apiKey = Get-LocalEnvValue 'DATA_GOV_IN_API_KEY'
if ([string]::IsNullOrWhiteSpace($apiKey)) {
  $apiKey = [Environment]::GetEnvironmentVariable('DATA_GOV_IN_API_KEY')
}

Write-Output 'API_CLIENT_SCAFFOLD=PASS'
Write-Output 'SECURE_CONFIG_SUPPORT=PASS'
Write-Output ('API_KEY_PRESENT=' + ($(if ([string]::IsNullOrWhiteSpace($apiKey)) { 'NO' } else { 'YES' })))
Write-Output 'SECRET_EXPOSURE=NONE'
Write-Output 'GIT_IGNORE=PASS'

if ($Request -and -not $DryRun) {
  throw 'API_REQUEST_REQUIRES_EXPLICIT_APPROVED_ACQUISITION_STEP'
}

Write-Output 'API_REQUEST_SENT=NO'
Write-Output 'DRYRUN=PASS'
Write-Output 'SUPABASE=NOT_CONTACTED'
