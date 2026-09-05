[CmdletBinding()]
param([string]$ZipPath = 'C:\Users\windows\Downloads\PINCODES.zip', [switch]$Reset)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) 'bookmyspace-pincodes-audit'
if ($Reset -and (Test-Path $root)) { Remove-Item -LiteralPath $root -Recurse -Force }
New-Item -ItemType Directory -Path $root -Force | Out-Null
$stateFile = Join-Path $root 'state.json'; $extract = Join-Path $root 'pdfs'; New-Item -ItemType Directory -Path $extract -Force | Out-Null
if (-not (Test-Path -LiteralPath $ZipPath)) { Write-Output 'PINCODES_ZIP_MISSING'; exit 2 }
Add-Type -AssemblyName System.IO.Compression
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $ZipPath)); $groups=@{}
try { foreach($e in $archive.Entries){ if($e.FullName -notmatch '(?i)\.pdf$'){continue}; $tmp=Join-Path $extract ([IO.Path]::GetRandomFileName()); [IO.Compression.ZipFileExtensions]::ExtractToFile($e,$tmp,$true); $h=(Get-FileHash $tmp -Algorithm SHA256).Hash.ToLowerInvariant(); if(-not $groups.ContainsKey($h)){$groups[$h]=@()} $groups[$h]+=[pscustomobject]@{name=$e.FullName; path=$tmp; bytes=$e.Length} } } finally {$archive.Dispose()}
$state=@{files=@{}}; if(Test-Path $stateFile){try{$state=Get-Content -Raw $stateFile|ConvertFrom-Json -AsHashtable}catch{}}
$py=@'
import json, re, sys
from pypdf import PdfReader
pdf, out, start = sys.argv[1], sys.argv[2], int(sys.argv[3])
r=PdfReader(pdf)
for i in range(start,len(r.pages)):
 t=r.pages[i].extract_text() or ''
 pins=re.findall(r'(?<!\d)\d{6}(?!\d)',t)
 with open(out,'a',encoding='utf-8') as f: f.write(json.dumps({'page':i+1,'rows':len(pins),'pincodes':pins})+'\n')
 with open(out+'.state','w',encoding='utf-8') as f: json.dump({'page':i+1,'pages':len(r.pages)},f)
'@
$duplicates=0; $unique=0; $failed=0; $complete=0
foreach($h in $groups.Keys){ $members=$groups[$h]; $canonical=$members|Sort-Object name|Select-Object -First 1; $duplicates += $members.Count-1; $unique++; $rec=$state.files[$h]; if($rec -and $rec.status -eq 'COMPLETE' -and (Test-Path $rec.artifact) -and $rec.source_sha256 -eq $h -and ((Get-FileHash $rec.artifact -Algorithm SHA256).Hash.ToLowerInvariant() -eq $rec.artifact_sha256)){ $complete++; Write-Output "PINCODES_RESUME|$($canonical.name)|status=SKIPPED_CHECKPOINT"; continue }; $artifact=Join-Path $root (($canonical.name -replace '[^A-Za-z0-9_.-]','_')+'.jsonl'); $start=0; if(Test-Path ($artifact+'.state')){$start=[int]((Get-Content -Raw ($artifact+'.state')|ConvertFrom-Json).page)}; try { & python -c $py $canonical.path $artifact $start 2>$null; if($LASTEXITCODE -ne 0){throw 'pypdf page extraction failed'}; $meta=Get-Content ($artifact+'.state') -Raw|ConvertFrom-Json; $ah=(Get-FileHash $artifact -Algorithm SHA256).Hash.ToLowerInvariant(); $state.files[$h]=[pscustomobject]@{source_sha256=$h;status='COMPLETE';artifact=$artifact;artifact_sha256=$ah;pages=[int]$meta.pages;processed_pages=[int]$meta.page}; $complete++; Write-Output "PINCODES_DATASET|$($canonical.name)|pages=$($meta.pages)|status=COMPLETE" } catch { $failed++; $state.files[$h]=[pscustomobject]@{source_sha256=$h;status='PDF_PARSE_FAILED';error=$_.Exception.Message}; Write-Output "PINCODES_DATASET|$($canonical.name)|status=PDF_PARSE_FAILED" }; $state|ConvertTo-Json -Depth 8|Set-Content $stateFile -Encoding utf8 }
Write-Output "Postal PDFs: $($groups.Values.Count + $duplicates)"; Write-Output "Unique PDFs: $unique"; Write-Output "Completed: $complete"; Write-Output "Failed: $failed"; Write-Output "Duplicate source files: $duplicates"; Write-Output 'Database writes: 0'; Write-Output 'Import status: INDIA_POST_SOURCE_INCOMPLETE'
