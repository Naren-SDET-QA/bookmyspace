[CmdletBinding()]
param(
  [ValidateSet('DRY_RUN','VALIDATE_ONLY','IMPORT_STAGING')]
  [string]$Mode = 'VALIDATE_ONLY',
  [string]$LgdRoot = '',
  [string]$PostalRoot = '',
  [string]$OutputRoot = (Join-Path ([IO.Path]::GetTempPath()) 'bookmyspace-india-staging')
)

$ErrorActionPreference = 'Stop'
$mappingStatus = 'INCOMPLETE'

function Fail-Gate {
  param([string]$Message)
  Write-Output "IMPORT_READINESS=NOT_READY"
  Write-Output "POSTAL_LGD_MAPPING_STATUS=$mappingStatus"
  Write-Output "IMPORT_BLOCKED|$Message"
  exit 2
}

function Get-JsonlRecords {
  param([string]$Root)
  if ([string]::IsNullOrWhiteSpace($Root) -or !(Test-Path -LiteralPath $Root -PathType Container)) {
    return @()
  }
  $records = @()
  Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.jsonl' | ForEach-Object {
    $source = $_.FullName
    Get-Content -LiteralPath $source | ForEach-Object {
      if ([string]::IsNullOrWhiteSpace($_)) { return }
      try { $records += ($_ | ConvertFrom-Json) } catch { throw "INVALID_JSONL|$source" }
    }
  }
  return $records
}

function Test-RequiredRecord {
  param($Record, [string]$Kind)
  if ($Kind -eq 'LGD') {
    return (![string]::IsNullOrWhiteSpace([string]$Record.source_id) -and
      ![string]::IsNullOrWhiteSpace([string]$Record.source_name) -and
      ![string]::IsNullOrWhiteSpace([string]$Record.source_provenance))
  }
  return (![string]::IsNullOrWhiteSpace([string]$Record.pincode) -and
    [string]$Record.pincode -match '^[0-9]{6}$' -and
    ![string]::IsNullOrWhiteSpace([string]$Record.source_pdf) -and
    $null -ne $Record.source_page)
}

if ($Mode -eq 'IMPORT_STAGING') { Fail-Gate 'POSTAL_LGD_MAPPING_INCOMPLETE' }

$lgd = @(Get-JsonlRecords $LgdRoot)
$postal = @(Get-JsonlRecords $PostalRoot)
$lgdIds = @($lgd | ForEach-Object { [string]$_.source_id })
$postalKeys = @($postal | ForEach-Object { "$(($_.office_name).ToString().ToLowerInvariant())|$($_.pincode)|$(($_.circle).ToString().ToLowerInvariant())" })
$invalidLgd = @($lgd | Where-Object { !(Test-RequiredRecord $_ 'LGD') }).Count
$invalidPostal = @($postal | Where-Object { !(Test-RequiredRecord $_ 'POSTAL') }).Count
$duplicateLgd = $lgdIds.Count - (@($lgdIds | Where-Object { $_ } | Sort-Object -Unique).Count)
$duplicatePostal = $postalKeys.Count - (@($postalKeys | Where-Object { $_ -notmatch '^\|\|$' } | Sort-Object -Unique).Count)

Write-Output "LGD_RECORDS=$($lgd.Count)"
Write-Output "POSTAL_RECORDS=$($postal.Count)"
Write-Output "DUPLICATE_LGD_SOURCE_IDS=$duplicateLgd"
Write-Output "DUPLICATE_POSTAL_KEYS=$duplicatePostal"
Write-Output "INVALID_LGD_RECORDS=$invalidLgd"
Write-Output "INVALID_POSTAL_RECORDS=$invalidPostal"
Write-Output 'TARGET_LOCATION_NODES=location_nodes'
Write-Output 'TARGET_POSTAL_LINKS=location_postal_codes'

if ($invalidLgd -gt 0 -or $invalidPostal -gt 0 -or $duplicateLgd -gt 0 -or $duplicatePostal -gt 0) {
  Write-Output 'VALIDATION=FAIL'
} else {
  Write-Output 'VALIDATION=PASS'
}
Write-Output "MODE=$Mode"
Write-Output 'SUPABASE_CONNECTION=NOT_CONTACTED'
Write-Output 'DATABASE_WRITES=0'
Write-Output "POSTAL_LGD_MAPPING_STATUS=$mappingStatus"
Write-Output 'IMPORT_READINESS=NOT_READY'
