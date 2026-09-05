[CmdletBinding()]
param([string]$SourceRoot='data\location\sources',[string]$AuditRoot='',[string]$ZipPath='',[int]$MaxZips=0,[int]$MaxWorkbooks=0,[int]$MaxRowsPerRun=0,[switch]$DryRun,[switch]$ValidateCheckpoint)
$ErrorActionPreference='Stop';$root=if($AuditRoot){[IO.Path]::GetFullPath($AuditRoot)}else{Join-Path ([IO.Path]::GetTempPath()) 'bookmyspace-lgd-audit'};$stage=Join-Path $root 'lgd-staging';New-Item $stage -ItemType Directory -Force|Out-Null;$statePath=Join-Path $root 'lgd-state.json';$state=[pscustomobject]@{files=$null};if(Test-Path $statePath){try{$state=Get-Content -Raw -LiteralPath $statePath|ConvertFrom-Json}catch{Write-Output ('STATE_LOAD_FAILED|'+$_.Exception.Message);exit 2}};if($null -eq $state.files){$state.files=[pscustomobject]@{}}
function Save-State{$lockPath="$statePath.lock";$lockStream=$null;$acquired=$false;$deadline=(Get-Date).AddSeconds(30);try{while(!$acquired){try{$lockStream=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$acquired=$true}catch{if((Get-Date)-gt$deadline){throw 'STATE_WRITE_LOCK_TIMEOUT'};Start-Sleep -Milliseconds 25}};if($lockStream){$lockStream.Dispose();$lockStream=$null};$latest=[pscustomobject]@{files=[pscustomobject]@{}};if(Test-Path -LiteralPath $statePath){$latest=Get-Content -Raw -LiteralPath $statePath|ConvertFrom-Json};if($null -eq $latest.files){$latest.files=[pscustomobject]@{}};$latest.files|Add-Member -NotePropertyName $id -NotePropertyValue $r -Force;$tmp="$statePath.$PID.tmp";$latest|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $tmp -Encoding utf8;Move-Item $tmp $statePath -Force}finally{if($lockStream){$lockStream.Dispose()};if($acquired -and (Test-Path -LiteralPath $lockPath)){Remove-Item -LiteralPath $lockPath -Force}}}
function Get-Id($path,$sha){(([IO.Path]::GetFullPath($path).ToLowerInvariant())+'|'+$sha)}
function Get-Zips{$base=(Resolve-Path $SourceRoot).Path;if($ZipPath){if(!(Test-Path -LiteralPath $ZipPath -PathType Leaf)){Write-Output "ZIP_INVALID|$ZipPath";exit 2};$target=(Resolve-Path -LiteralPath $ZipPath).Path;if([IO.Path]::GetExtension($target).ToLowerInvariant() -ne '.zip'){Write-Output "ZIP_INVALID|$target";exit 2};$items=@(Get-ChildItem -LiteralPath $base -Filter '*.zip'|% FullName);if($target -notin $items){Write-Output "ZIP_INVALID|$target";exit 2};$sha=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant();return @([pscustomobject]@{path=$target;relative=$target.Substring($base.Length).TrimStart('');sha=$sha;id=(Get-Id $target $sha)})};@(Get-ChildItem -LiteralPath $base -Filter '*.zip'|Sort-Object FullName|%{$sha=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant();[pscustomobject]@{path=$_.FullName;relative=$_.FullName.Substring($base.Length).TrimStart('');sha=$sha;id=(Get-Id $_.FullName $sha)}})}
function Get-Rec($id){$p=$state.files.PSObject.Properties[$id];if($p){$p.Value}else{$null}}
function Test-Workbook($w,$r){if(!$r){return $false};$a=[string]$r.artifact_path;if($r.status-ne'COMPLETE'-or !$r.workbook_sha256-or $r.workbook_sha256-ne$w.sha-or !$a-or !(Test-Path -LiteralPath $a -PathType Leaf)){return $false};try{$n=0;Get-Content $a|%{$_|ConvertFrom-Json;$n++};return $n -eq [int]$r.records_processed -and (Get-FileHash -LiteralPath $a -Algorithm SHA256).Hash.ToLowerInvariant() -eq [string]$r.artifact_sha256}catch{return $false}}
function Test-WorkbookCheckpoint($w,$r){
 if(!$r){return [pscustomobject]@{Status='MISSING';Record=$null;Reason='CHECKPOINT_MISSING'}}
 $artifact=[string]$r.artifact_path
 $exists=($artifact -and (Test-Path -LiteralPath $artifact -PathType Leaf))
 $shaOk=$false
 if($exists){try{$shaOk=((Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant() -eq [string]$r.artifact_sha256)}catch{$shaOk=$false}}
 $rowsTotal=0;$rowsCompleted=0
 [void][int]::TryParse([string]$r.rows_total,[ref]$rowsTotal);[void][int]::TryParse([string]$r.rows_completed,[ref]$rowsCompleted)
 $errorNull=($null -eq $r.error -or [string]::IsNullOrWhiteSpace([string]$r.error))
 $valid=($r.status -eq 'COMPLETE' -and $r.workbook_sha256 -eq $w.sha -and $exists -and $shaOk -and $rowsCompleted -eq $rowsTotal -and $errorNull)
 $partial=($r.status -eq 'PARTIAL' -and $rowsCompleted -lt $rowsTotal -and $exists -and $shaOk -and $errorNull)
 $status=if($valid){'VALID'}elseif($partial){'PARTIAL'}else{'INVALID'}
 [pscustomobject]@{Status=$status;Record=$r;Reason=if($valid){$null}elseif($partial){$null}elseif(!$exists){'ARTIFACT_MISSING'}elseif(!$shaOk){'ARTIFACT_SHA_MISMATCH'}elseif(!$errorNull){'EXTRACTION_ERROR'}else{'CHECKPOINT_INVALID'}}
}
function Get-ZipWorkbookReport($z){
 $items=@();foreach($w in @(Get-WorkbookEntries $z)){$r=Get-Rec (Get-Id $z.id $w.sha);$v=Test-WorkbookCheckpoint $w $r;$items+=[pscustomobject]@{Workbook=$w;Validation=$v}}
 $valid=@($items|?{$_.Validation.Status -eq 'VALID'});$partial=@($items|?{$_.Validation.Status -eq 'PARTIAL'});$bad=@($items|?{$_.Validation.Status -in @('INVALID','MISSING')})
 [pscustomobject]@{Items=$items;Complete=$valid;Partial=$partial;Invalid=$bad}
}
function Get-LgdCheckpointClassification($all){$complete=@();$incomplete=@();foreach($z in $all){$r=Get-Rec $z.id;$zipComplete=($r -and $r.status -eq 'COMPLETE' -and $r.source_sha256 -eq $z.sha -and $r.artifact_path -and (Test-Path -LiteralPath $r.artifact_path -PathType Leaf));if($zipComplete){$complete+=$z}else{$incomplete+=$z}};if($script:ValidateCheckpoint){Write-CheckpointReport $all;exit 0};[pscustomobject]@{All=$all;Complete=$complete;Incomplete=$incomplete;Candidates=$incomplete;ProcessedCount=$complete.Count;RemainingCount=$incomplete.Count}}
function Write-CheckpointReport($all){foreach($z in $all){$wr=Get-ZipWorkbookReport $z;Write-Output "ZIP|$($z.relative)|workbooks=$($wr.Items.Count)|complete=$($wr.Complete.Count)|partial=$($wr.Partial.Count)|invalid=$($wr.Invalid.Count)";foreach($i in $wr.Items){$r=$i.Validation.Record;switch($i.Validation.Status){'VALID'{Write-Output "WORKBOOK_VALID|$($i.Workbook.name)|status=$($r.status)|rows=$($r.rows_completed)/$($r.rows_total)|resume=$($r.resume_row)|records=$($r.records_processed)|artifact=VALID|error=NULL"};'PARTIAL'{Write-Output "WORKBOOK_PARTIAL|$($i.Workbook.name)|status=$($r.status)|rows=$($r.rows_completed)/$($r.rows_total)|resume=$($r.resume_row)|records=$($r.records_processed)"};'MISSING'{Write-Output "WORKBOOK_MISSING|$($i.Workbook.name)"};default{Write-Output "WORKBOOK_INVALID|$($i.Workbook.name)|reason=$($i.Validation.Reason)"}}}}}
function Get-WorkbookEntries($z){$a=[IO.Compression.ZipFile]::OpenRead($z.path);try{@($a.Entries|?{$_.FullName.ToLower().EndsWith('.xls')})|%{[pscustomobject]@{name=$_.FullName;sha=(Get-EntryHash $_);zip=$z}}}finally{$a.Dispose()}}
function Get-EntryHash($e){$h=[Security.Cryptography.SHA256]::Create();$s=$e.Open();try{([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','').ToLowerInvariant()}finally{$s.Dispose();$h.Dispose()}}
function Process-Workbook($z,$w){$dir=Join-Path $stage $z.sha;New-Item $dir -ItemType Directory -Force|Out-Null;$artifact=Join-Path $dir (($w.name -replace '[^A-Za-z0-9_.-]','_')+'.jsonl');$runDir=Join-Path $dir ('run-'+[guid]::NewGuid().ToString('N'));New-Item $runDir -ItemType Directory -Force|Out-Null;$source=Join-Path $runDir (($w.name -replace '[^A-Za-z0-9_.-]','_')+'.xls');$id=Get-Id $z.id $w.sha;$old=Get-Rec $id;$resume=if($old){[int]$old.rows_completed}else{0};$archive=[IO.Compression.ZipFile]::OpenRead($z.path);try{$entry=$archive.Entries|? FullName -eq $w.name;if($null -eq $entry){throw 'LGD workbook entry not found'};$input=$entry.Open();try{$output=[IO.File]::Open($source,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$input.CopyTo($output)}finally{$output.Dispose()}}finally{$input.Dispose()}}finally{$archive.Dispose()};$limit=if($MaxRowsPerRun){$MaxRowsPerRun}else{0};$py=@'
import json,sys,os,xml.etree.ElementTree as ET
src,out,start,limit=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4]);row=0;written=0;finished=False
seen=set()
if start and os.path.exists(out):
 with open(out,encoding='utf-8') as existing:
  for line in existing:
   try:
    value=json.loads(line).get('source_record')
    if isinstance(value,int): seen.add(value)
   except (ValueError,TypeError): pass
with open(out,'a' if start else 'w',encoding='utf-8') as w:
 for _,e in ET.iterparse(src,events=('end',)):
  if e.tag.endswith('Row'):
   vals=[(d.text or '').strip() for d in e.iter() if d.tag.endswith('Data')]
   if vals and any(vals):
    row+=1
    if row>start and row not in seen and (not limit or written<limit): seen.add(row);written+=1;w.write(json.dumps({'source_zip':src,'source_workbook':src,'source_record':row,'entity_type':'lgd'})+'\n')
   e.clear()
   if limit and written>=limit: finished=True; break
print(row,written,finished)
'@
;$out=& python -c $py $source $artifact $resume $limit;if($LASTEXITCODE-ne 0){throw 'LGD workbook parser failed'};$parts=$out -split '\s+';$rows=[int]$parts[0];$written=[int]$parts[1];$complete=(!$limit -or ([string]$parts[2] -eq 'False'));$lines=@(Get-Content $artifact|%{$_|ConvertFrom-Json});$r=[pscustomobject]@{source_path=$z.path;source_sha256=$z.sha;workbook_name=$w.name;workbook_sha256=$w.sha;status=if($complete){'COMPLETE'}else{'PARTIAL'};rows_total=$rows;rows_completed=($resume+$written);resume_row=($resume+$written+1);records_processed=$lines.Count;artifact_path=$artifact;artifact_sha256=(Get-FileHash $artifact -Algorithm SHA256).Hash.ToLowerInvariant();error=$null};$state.files|Add-Member -NotePropertyName $id -NotePropertyValue $r -Force;Save-State;Write-Output "WORKBOOK_PROGRESS|$($w.name)|rows=$($r.rows_completed)|rows_this_run=$written|status=$($r.status)"}$all=Get-Zips;$class=Get-LgdCheckpointClassification $all;Write-Output "TOTAL LGD ZIPS: $($class.All.Count)";Write-Output "COMPLETE: $($class.Complete.Count)";Write-Output "INCOMPLETE: $($class.Incomplete.Count)";if($DryRun-or$ValidateCheckpoint){foreach($z in @($class.Candidates|Select-Object -First $(if($MaxZips){$MaxZips}else{$class.Candidates.Count}))){Write-Output "PROCESS_CANDIDATE|$($z.relative)"};exit 0};$zs=@($class.Candidates|Select-Object -First $(if($MaxZips){$MaxZips}else{$class.Candidates.Count}));$limit=if($MaxWorkbooks){$MaxWorkbooks}else{[int]::MaxValue};$done=0;foreach($z in $zs){foreach($w in Get-WorkbookEntries $z){if(Test-Workbook $w (Get-Rec (Get-Id $z.id $w.sha))){Write-Output "WORKBOOK_SKIPPED_COMPLETE|$($w.name)";continue};if($done-ge$limit){break};Write-Output "WORKBOOK_CANDIDATE|$($w.name)";Process-Workbook $z $w;$done++};if($done-ge$limit){break}};Write-Output "WORKBOOKS_PROCESSED_THIS_RUN=$done";Write-Output 'Database writes: 0';Write-Output 'Production: UNTOUCHED'
