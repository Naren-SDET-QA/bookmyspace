# Reports DEV E2E credential availability without printing secret values.
# This is a guard only; it does not authenticate, create users, or write data.
[CmdletBinding()]
param(
  [string]$EnvFile = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
  $EnvFile = Join-Path $PSScriptRoot '..\.env.dev.local'
}

function Get-ConfiguredValue([string]$Name, [hashtable]$FileValues) {
  $processValue = [Environment]::GetEnvironmentVariable($Name)
  if (-not [string]::IsNullOrWhiteSpace($processValue)) { return $processValue }
  if ($FileValues.ContainsKey($Name)) { return $FileValues[$Name] }
  return $null
}

$fileValues = @{}
if (Test-Path -LiteralPath $EnvFile) {
  foreach ($line in Get-Content -LiteralPath $EnvFile) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
      $fileValues[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
    }
  }
}

$customerEmail = Get-ConfiguredValue 'DEV_E2E_CUSTOMER_EMAIL' $fileValues
$customerPassword = Get-ConfiguredValue 'DEV_E2E_CUSTOMER_PASSWORD' $fileValues
$ownerEmail = Get-ConfiguredValue 'DEV_E2E_OWNER_EMAIL' $fileValues
$ownerPhone = Get-ConfiguredValue 'DEV_E2E_OWNER_PHONE' $fileValues
$adminEmail = Get-ConfiguredValue 'DEV_E2E_ADMIN_EMAIL' $fileValues

$customer = (-not [string]::IsNullOrWhiteSpace($customerEmail)) -and (-not [string]::IsNullOrWhiteSpace($customerPassword))
$owner = (-not [string]::IsNullOrWhiteSpace($ownerEmail)) -or (-not [string]::IsNullOrWhiteSpace($ownerPhone))
$admin = -not [string]::IsNullOrWhiteSpace($adminEmail)

Write-Output "CUSTOMER_CREDENTIALS: $(if ($customer) { 'AVAILABLE' } else { 'MISSING' })"
Write-Output "OWNER_CREDENTIALS: $(if ($owner) { 'AVAILABLE' } else { 'MISSING' })"
Write-Output "ADMIN_CREDENTIALS: $(if ($admin) { 'AVAILABLE' } else { 'MISSING' })"

if (-not ($customer -and $owner)) {
  Write-Output 'AUTH_FIXTURE_UNAVAILABLE'
  exit 2
}

exit 0
