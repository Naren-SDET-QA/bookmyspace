[CmdletBinding()]
param(
  [switch]$ResetCheckpoint,
  [int]$MaxSources = 0,
  [ValidateSet('inventory','extract','all')]
  [string]$Stage = 'all'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot '.env.dev.local'
$expectedHost = 'db.zykxneztahxbjduagutv.supabase.co'

function Stop-Safely([string]$message) {
  Write-Output $message
  exit 2
}

if (-not (Test-Path -LiteralPath $envFile)) { Stop-Safely 'DEV_DATABASE_URL_MISSING' }
$line = Get-Content -LiteralPath $envFile |
  Where-Object { $_ -match '^\s*DEV_DATABASE_URL\s*=' } |
  Select-Object -First 1
if (-not $line) { Stop-Safely 'DEV_DATABASE_URL_MISSING' }

$databaseUrl = ($line -replace '^\s*DEV_DATABASE_URL\s*=\s*', '').Trim().Trim('"').Trim("'")
try { $databaseUri = [Uri]$databaseUrl } catch { Stop-Safely 'DEV_DATABASE_URL_INVALID' }
if ($databaseUri.Scheme -notin @('postgres', 'postgresql') -or
    $databaseUri.Host -ne $expectedHost) {
  Stop-Safely 'REMOTE_DEV_DATABASE_INVALID'
}
$psqlCommand = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlCommand -and (Test-Path 'C:\Program Files\PostgreSQL\18\bin\psql.exe')) {
  $psqlCommand = Get-Item 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
}
if (-not $psqlCommand) {
  Stop-Safely 'PSQL_MISSING'
}

$sourceRoot = Join-Path $repoRoot 'data\location\sources'
$checkpointRoot = Join-Path ([IO.Path]::GetTempPath()) 'bookmyspace-india-audit'
$checkpointFile = Join-Path $checkpointRoot 'source-metadata.json'
$inventoryFile = Join-Path $checkpointRoot 'lgd-inventory.json'
$extractRoot = Join-Path $checkpointRoot 'extracted'
if ($ResetCheckpoint -and (Test-Path -LiteralPath $checkpointRoot)) {
  Remove-Item -LiteralPath $checkpointRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $checkpointRoot -Force | Out-Null
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
$completed = @{}
if (Test-Path -LiteralPath $checkpointFile) {
  try { (Get-Content -Raw -LiteralPath $checkpointFile | ConvertFrom-Json).records | ForEach-Object { $completed[$_.key] = $_ } } catch { $completed = @{} }
}
function Test-ValidCheckpoint($record, [string]$sourceHash) {
  if (-not $record -or $record.source_sha256 -ne $sourceHash -or
      $record.status -ne 'COMPLETE' -or $null -eq $record.records -or
      $record.records -notmatch '^\d+$' -or -not (Test-Path -LiteralPath $record.artifact)) { return $false }
  $artifactHash = (Get-FileHash -LiteralPath $record.artifact -Algorithm SHA256).Hash.ToLowerInvariant()
  return $artifactHash -eq $record.artifact_sha256 -and -not $record.error
}
$sources = if (Test-Path -LiteralPath $sourceRoot) {
  Get-ChildItem -LiteralPath $sourceRoot -Recurse -File |
    Where-Object { $_.Extension -in @('.zip','.xls','.xlsx','.csv','.json','.pdf') }
} else { @() }

Write-Output 'Script: CREATED'
Write-Output 'DEV_DATABASE_URL: PRESENT'
Write-Output 'Remote DEV: VALID'
Write-Output ('Source files found: ' + $sources.Count)
foreach ($source in $sources) {
  $hash = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  $relative = $source.FullName.Substring($repoRoot.Length).TrimStart('\')
  Write-Output ("SOURCE|$relative|$($source.Extension.TrimStart('.').ToUpperInvariant())|RECORD_COUNT=UNKNOWN|SHA256=$hash")
}

# Stage 1: lightweight ZIP inventory. This never opens workbook contents.
$inventory = @()
foreach ($zip in ($sources | Where-Object Extension -eq '.zip')) {
  $archive = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
  try {
    $entries = @($archive.Entries | ForEach-Object {
      [pscustomobject]@{ name = $_.FullName; size = $_.Length; level = if ($_.FullName -match '(?i)village') {'village'} elseif ($_.FullName -match '(?i)subdistrict') {'subdistrict'} elseif ($_.FullName -match '(?i)district') {'district'} elseif ($_.FullName -match '(?i)(town|city|urban)') {'town_city'} else {'other'} }
    })
    $inventory += [pscustomobject]@{ file = $zip.Name; sha256 = (Get-FileHash -LiteralPath $zip.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); file_count = $entries.Count; uncompressed_size = ($entries | Measure-Object size -Sum).Sum; entries = $entries }
  } finally { $archive.Dispose() }
}
$inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $inventoryFile -Encoding utf8
Write-Output ("LGD_INVENTORY|file=$inventoryFile|zips=$($inventory.Count)")
if ($Stage -eq 'inventory') { Write-Output 'Database writes: 0'; exit 0 }

# Stage 2: extract one relevant workbook at a time and checkpoint its result.
$ss = 'urn:schemas-microsoft-com:office:spreadsheet'
$lgdTotals = @{ district = 0; subdistrict = 0; village = 0; town_city = 0; other = 0 }
$lgdFiles = 0
foreach ($zip in ($sources | Where-Object Extension -eq '.zip')) {
  $zipHash = (Get-FileHash -LiteralPath $zip.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  if (($completed.Keys | Where-Object { $_ -like "$zipHash/*" } | ForEach-Object { Test-ValidCheckpoint $completed[$_] $zipHash } | Where-Object { $_ }).Count -gt 0) {
    Write-Output ("LGD_RESUME|$($zip.Name)|status=SKIPPED_CHECKPOINT")
    continue
  }
  $archive = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
  try {
    foreach ($entry in $archive.Entries) {
      if ($entry.FullName -notmatch '\.(xls|xlsx|csv|json)$') { continue }
      # Ignore LGD mapping/ward workbooks for the administrative coverage
      # totals; they are inventoried above but are not source levels requested
      # by this audit and can be hundreds of MB each.
      if ($entry.FullName -notmatch '(?i)(district|subdistrict|village|town|city|urban)') { continue }
      $sourceKey = "$zipHash/$($entry.FullName)"
      $existing = $completed[$sourceKey]
      if (Test-ValidCheckpoint $existing $zipHash) { continue }
      if ($existing) { Write-Output ("LGD_RESUME|$($zip.Name)|$($entry.FullName)|status=REPROCESS_REQUIRED") }
      $safeName = (($zip.BaseName + '_' + $entry.Name) -replace '[^A-Za-z0-9_.-]','_')
      $tempFile = Join-Path $extractRoot $safeName
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tempFile, $true)
      $stream = [IO.File]::OpenRead($tempFile); $reader = [System.IO.StreamReader]::new($stream)
      $level = if ($entry.FullName -match '(?i)village') { 'village' }
        elseif ($entry.FullName -match '(?i)subdistrict') { 'subdistrict' }
        elseif ($entry.FullName -match '(?i)district') { 'district' }
        elseif ($entry.FullName -match '(?i)(town|city|urban)') { 'town_city' }
        else { 'other' }
      # These are XML Spreadsheet 2003 files. Count rows incrementally so
      # large village/ward workbooks do not require a multi-hundred-MB DOM.
      $rowCount = 0
      try {
        while (($line = $reader.ReadLine()) -ne $null) {
          if ($line -match '<(?:ss:)?Row(?:\s|>)') { $rowCount++ }
        }
      } finally { $reader.Dispose(); $stream.Dispose() }
      $dataRows = [Math]::Max(0, $rowCount - 1)
      $artifactHash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash.ToLowerInvariant()
      $lgdTotals[$level] += $dataRows
      $lgdFiles++
      Write-Output ("LGD_DATASET|$($zip.Name)|$($entry.FullName)|$level|records=$dataRows")
    }
  } finally { $archive.Dispose() }
      $completed[$sourceKey] = [pscustomobject]@{ key = $sourceKey; source_sha256 = $zipHash; file = $zip.Name; entry = $entry.FullName; kind = 'LGD_SOURCE'; status = 'COMPLETE'; records = $dataRows; artifact = $tempFile; artifact_sha256 = $artifactHash; level = $level; parsed_at = (Get-Date).ToUniversalTime().ToString('o') }
      [pscustomobject]@{ records = @($completed.Values) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $checkpointFile -Encoding utf8
  if ($MaxSources -gt 0 -and $completed.Count -ge $MaxSources) { break }
}
Write-Output ("LGD_PARSED_FILES=$lgdFiles")
Write-Output ("LGD_RECORDS|district=$($lgdTotals.district)|subdistrict=$($lgdTotals.subdistrict)|village=$($lgdTotals.village)|town_city=$($lgdTotals.town_city)")

$postals = $sources | Where-Object { $_.FullName -match '(?i)india-post.*\.pdf$' }
$postalGroups = @($postals | ForEach-Object {
  [pscustomobject]@{ file = $_; hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
} | Group-Object hash)
$postalDuplicates = @()
$postalUnique = @()
foreach ($group in $postalGroups) {
  $members = @($group.Group | Sort-Object { if ($_.file.Name -eq 'Kerala Circle.pdf') { 0 } else { 1 } }, { $_.file.Name })
  $canonical = $members[0]
  $postalUnique += $canonical
  foreach ($duplicate in ($members | Select-Object -Skip 1)) {
    $postalDuplicates += $duplicate
    Write-Output ("INDIA_POST_DUPLICATE|$($duplicate.file.Name)|canonical=$($canonical.file.Name)|sha256=$($group.Name)|status=DUPLICATE_SOURCE_FILE")
  }
}
Write-Output ("INDIA_POST_FILES_DISCOVERED=$($postals.Count)")
Write-Output ("INDIA_POST_FILES_UNIQUE=$($postalUnique.Count)")
Write-Output ("INDIA_POST_DUPLICATE_FILES=$($postalDuplicates.Count)")
foreach ($item in $postalUnique) {
  $pdf = $item.file
  $pdfHash = $item.hash
  if (Test-ValidCheckpoint $completed[$pdfHash] $pdfHash) { Write-Output ("INDIA_POST_RESUME|$($pdf.Name)|status=SKIPPED_CHECKPOINT"); continue }
  if ($completed[$pdfHash]) { Write-Output ("INDIA_POST_RESUME|$($pdf.Name)|status=REPROCESS_REQUIRED") }
  $artifact = Join-Path $extractRoot (($pdf.BaseName -replace '[^A-Za-z0-9_.-]','_') + '_' + $pdfHash.Substring(0,12) + '.json')
  $pythonCode = @'
import json, re, sys
from pypdf import PdfReader
pdf, out = sys.argv[1], sys.argv[2]
r = PdfReader(pdf)
text = '\n'.join((p.extract_text() or '') for p in r.pages)
lines = [x.strip() for x in text.splitlines() if x.strip()]
pins = re.findall(r'(?<!\d)\d{6}(?!\d)', text)
json.dump({'pages': len(r.pages), 'records': len(lines), 'unique_pincodes': len(set(pins)), 'duplicate_pincodes': len(pins)-len(set(pins)), 'text_lines': len(lines)}, open(out, 'w', encoding='utf-8'))
'@
  $pythonOut = Join-Path $extractRoot (($pdf.BaseName -replace '[^A-Za-z0-9_.-]','_') + '_' + $pdfHash.Substring(0,12) + '.parse.json')
  $parseError = $null
  try { & python -c $pythonCode $pdf.FullName $pythonOut 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { $parseError = 'pypdf parser failed' } } catch { $parseError = $_.Exception.Message }
  if (-not $parseError -and (Test-Path -LiteralPath $pythonOut)) {
    try {
      $parsed = Get-Content -Raw -LiteralPath $pythonOut | ConvertFrom-Json
      if ([int]$parsed.records -le 0) { $parseError = 'no extractable records' }
    } catch { $parseError = 'parser artifact invalid' }
  }
  if ($parseError) {
    $completed[$pdfHash] = [pscustomobject]@{ key = $pdfHash; source_sha256 = $pdfHash; file = $pdf.Name; kind = 'INDIA_POST_PDF'; status = 'PDF_PARSE_FAILED'; error = $parseError; records = $null; parsed_at = (Get-Date).ToUniversalTime().ToString('o') }
    Write-Output ("INDIA_POST_DATASET|$($pdf.Name)|records=UNPARSED|status=PDF_PARSE_FAILED|reason=$parseError")
  } else {
    $artifactHash = (Get-FileHash -LiteralPath $pythonOut -Algorithm SHA256).Hash.ToLowerInvariant()
    $completed[$pdfHash] = [pscustomobject]@{ key = $pdfHash; source_sha256 = $pdfHash; file = $pdf.Name; kind = 'INDIA_POST_PDF'; status = 'COMPLETE'; records = [int]$parsed.records; artifact = $pythonOut; artifact_sha256 = $artifactHash; pages = [int]$parsed.pages; unique_pincodes = [int]$parsed.unique_pincodes; duplicate_pincodes = [int]$parsed.duplicate_pincodes; parsed_at = (Get-Date).ToUniversalTime().ToString('o') }
    Write-Output ("INDIA_POST_DATASET|$($pdf.Name)|records=$($parsed.records)|pages=$($parsed.pages)|unique_pincodes=$($parsed.unique_pincodes)|status=COMPLETE")
  }
  [pscustomobject]@{ records = @($completed.Values) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $checkpointFile -Encoding utf8
}
Write-Output ('INDIA_POST_RECORDS=' + (($completed.Values | Where-Object { $_.kind -eq 'INDIA_POST_PDF' -and $_.status -eq 'COMPLETE' } | Measure-Object records -Sum).Sum))
Write-Output 'INDIA_POST_COVERAGE=INCOMPLETE_SOURCE_SET'

$env:PGCONNECT_TIMEOUT = '10'
$query = @'
select json_build_object(
  'database', current_database(),
  'host', inet_server_addr()::text,
  'location_nodes', (select count(*) from public.location_nodes),
  'location_postal_codes', case when to_regclass('public.location_postal_codes') is null then null else (select count(*) from public.location_postal_codes) end,
  'states_ut', (select count(*) from public.location_nodes where level = 'state_province'),
  'districts', (select count(*) from public.location_nodes where level = 'district_county'),
  'subdistricts', (select count(*) from public.location_nodes where level in ('sub_district','mandal','taluk','tehsil','block')),
  'villages', (select count(*) from public.location_nodes where level = 'village'),
  'towns_cities', (select count(*) from public.location_nodes where level = 'city_town'),
  'localities', (select count(*) from public.location_nodes where level = 'area_locality')
)::text;
'@
$probe = & $psqlCommand.Source $databaseUrl -X -v ON_ERROR_STOP=1 -Atqc $query 2>$null
if ($LASTEXITCODE -ne 0) { Stop-Safely 'REMOTE_DEV_READ_ONLY_CHECK_FAILED' }
Write-Output ('DEV_BASELINE|' + ($probe -join ''))

# Source record counts remain UNKNOWN until the XML Spreadsheet/PDF parsers
# validate official IDs and parent relationships. This is intentionally a
# completeness gate: it cannot report IMPORT_READY from filenames alone.
Write-Output 'LGD: INCOMPLETE'
Write-Output 'India Post: INCOMPLETE'
Write-Output 'States/UT: EXPECTED / UNKNOWN'
Write-Output 'Districts: EXPECTED / UNKNOWN'
Write-Output 'Sub-districts: EXPECTED / UNKNOWN'
Write-Output 'Villages: EXPECTED / UNKNOWN'
Write-Output 'Town/City: EXPECTED / UNKNOWN'
Write-Output 'Pincodes: EXPECTED / UNKNOWN'
Write-Output 'Duplicates: UNKNOWN'
Write-Output 'Orphans: UNKNOWN'
Write-Output 'Invalid: UNKNOWN'
Write-Output 'Would insert: UNKNOWN'
Write-Output 'Would update: UNKNOWN'
Write-Output 'Would skip: UNKNOWN'
Write-Output 'Import status: INDIA_SOURCE_DATA_INCOMPLETE'
Write-Output 'Database writes: 0'
Write-Output 'Production: UNTOUCHED'
Write-Output 'Commit: NONE'
Write-Output 'Push: NONE'
