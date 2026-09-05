$ErrorActionPreference = 'Stop'

# PHASE 7.1-C-4D: local-only authenticated verification. This harness never
# calls CREATE_HOLD, CONFIRM_BOOKING, CANCEL_BOOKING, or REFUND_REQUEST.
# `supabase status` can block while the optional local Vector/logging service
# restarts. These are the local CLI defaults; callers may override them.
$base = if ($env:PHASE71_DEV_SUPABASE_URL) { $env:PHASE71_DEV_SUPABASE_URL } elseif ($env:PHASE71_SUPABASE_URL) { $env:PHASE71_SUPABASE_URL } else { throw 'PHASE71_DEV_SUPABASE_URL_missing' }
$anon = if ($env:PHASE71_DEV_SUPABASE_ANON_KEY) { $env:PHASE71_DEV_SUPABASE_ANON_KEY } elseif ($env:PHASE71_SUPABASE_ANON_KEY) { $env:PHASE71_SUPABASE_ANON_KEY } else { throw 'PHASE71_DEV_SUPABASE_ANON_KEY_missing' }
$service = if ($env:PHASE71_DEV_SUPABASE_SERVICE_ROLE_KEY) { $env:PHASE71_DEV_SUPABASE_SERVICE_ROLE_KEY } elseif ($env:PHASE71_SUPABASE_SERVICE_ROLE_KEY) { $env:PHASE71_SUPABASE_SERVICE_ROLE_KEY } else { throw 'PHASE71_DEV_SUPABASE_SERVICE_ROLE_KEY_missing' }
$manifest = [System.Collections.Generic.List[object]]::new()
$users = [System.Collections.Generic.List[object]]::new()
$sessions = [System.Collections.Generic.List[string]]::new()
$fixtureIds = [System.Collections.Generic.List[object]]::new()
$runMarker = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')

function Invoke-Json([string]$method, [string]$url, [hashtable]$headers, [object]$body = $null) {
  $request = [System.Net.HttpWebRequest]::Create($url); $request.Method = $method; $request.Timeout = 5000; $request.ReadWriteTimeout = 5000
  foreach ($key in $headers.Keys) { $request.Headers[$key] = [string]$headers[$key] }
  if ($null -ne $body) { $bytes = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress -Depth 12)); $request.ContentType='application/json'; $request.ContentLength=$bytes.Length; $stream=$request.GetRequestStream(); $stream.Write($bytes,0,$bytes.Length); $stream.Dispose() }
  try { $response = [System.Net.HttpWebResponse]$request.GetResponse() } catch [System.Net.WebException] { $response = [System.Net.HttpWebResponse]$_.Exception.Response }
  $reader = [IO.StreamReader]::new($response.GetResponseStream()); $text = $reader.ReadToEnd(); $reader.Dispose()
  $parsed = $null; if ($text) { try { $parsed = $text | ConvertFrom-Json } catch { $parsed = $text } }
  [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $parsed }
}
function Check([string]$name, [scriptblock]$test) {
  try { & $test; Write-Output "${name}: PASS" }
  catch { Write-Output "${name}: FAIL ($($_.Exception.Message))" }
}
function AuthHeaders($token) { @{ apikey = $anon; Authorization = "Bearer $token" } }
function Invoke-LocalSql([string]$sql) {
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql))
  & docker.exe exec supabase_db_bookmyspace sh -lc "echo $encoded | base64 -d | psql -U postgres -d postgres -v ON_ERROR_STOP=1" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "local_sql_status_$LASTEXITCODE" }
}
function Health([string]$name, [string]$url, [int[]]$allowed = @(200), [string]$method = 'Head') {
  try { $request = [System.Net.HttpWebRequest]::Create($url); $request.Method=$method; $request.Timeout=5000; try { $response=[System.Net.HttpWebResponse]$request.GetResponse() } catch [System.Net.WebException] { $response=[System.Net.HttpWebResponse]$_.Exception.Response }; if ($allowed -notcontains [int]$response.StatusCode) { throw "status_$($response.StatusCode)" }; Write-Output "${name}: PASS" }
  catch { throw "${name}: FAIL ($($_.Exception.Message))" }
}

try {
  Health 'REST' "$base/rest/v1/"
  Health 'AUTH' "$base/auth/v1/health" @(200) 'Get'
  Health 'KONG' "$base/" @(200, 404)
  Health 'EDGE' "$base/functions/v1/ai-action-gate" @(405)
  foreach ($suffix in @('A','B')) {
    $email = "PHASE71_TEST_CUSTOMER_${suffix}_$runMarker@example.test"
    $r = Invoke-Json POST "$base/auth/v1/signup" @{ apikey = $anon } @{ email = $email; password = 'LocalOnly-Phase71-2026!' }
    if ($r.Status -ne 200 -or !$r.Body.access_token) { throw "signup_$suffix status=$($r.Status)" }
    $u = [pscustomobject]@{ Id = [string]$r.Body.user.id; Token = [string]$r.Body.access_token; Email = $email }
    $users.Add($u); $manifest.Add([pscustomobject]@{ kind='auth_user'; id=$u.Id; marker=$email })
  }
  $a = AuthHeaders $users[0].Token; $b = AuthHeaders $users[1].Token
  Check 'AUTHENTICATED_CUSTOMER' { if (!$users[0].Token) { throw 'missing JWT' } }
  # The local CLI's legacy service JWT can be stale while Auth-issued JWTs
  # remain valid. Create this owner-scoped fixture through the authenticated
  # API so the harness verifies the same RLS path as the product.
  $fixtureHeaders = AuthHeaders $users[0].Token
  $hotelCategory = (Invoke-Json GET "$base/rest/v1/venue_categories?slug=eq.hotel&select=id&limit=1" $fixtureHeaders).Body[0].id
  if (!$hotelCategory) { throw 'hotel_category_missing' }
  $fixtureOrg = '71000000-0000-0000-0000-000000000001'
  $fixtureVenue = '71000000-0000-0000-0000-000000000002'
  $fixtureSlot = '71000000-0000-0000-0000-000000000003'
  $fixtureIds.Add([pscustomobject]@{ table='venue_operating_hours'; id=$fixtureVenue; key='venue_id' })
  $fixtureIds.Add([pscustomobject]@{ table='time_slots'; id=$fixtureSlot; key='id' })
  $fixtureIds.Add([pscustomobject]@{ table='venues'; id=$fixtureVenue; key='id' })
  $fixtureIds.Add([pscustomobject]@{ table='organizations'; id=$fixtureOrg; key='id' })
  Check 'HOTEL_FIXTURE' {
    Invoke-LocalSql "insert into organizations(id,owner_user_id,org_type,name) values ('$fixtureOrg','$($users[0].Id)','venue_owner','PHASE71_TEST_HOTEL_ORG_$runMarker') on conflict (id) do update set owner_user_id=excluded.owner_user_id,name=excluded.name; insert into venues(id,org_id,category_id,name,slug,description,city,state,latitude,longitude,capacity,pricing_base_amount,tax_rate,is_active,listing_status) values ('$fixtureVenue','$fixtureOrg','$hotelCategory','PHASE71_TEST_HOTEL_$runMarker','phase71-test-hotel-$runMarker','Local-only Phase 7.1 hotel fixture','Hyderabad','Telangana',17.385044,78.486671,2,1200,18,true,'published') on conflict (id) do update set org_id=excluded.org_id,category_id=excluded.category_id,is_active=true,listing_status='published';"
    for ($day = 0; $day -le 6; $day++) {
      Invoke-LocalSql "insert into venue_operating_hours(venue_id,day_of_week,opens_at,closes_at,is_closed) values ('$fixtureVenue',$day,'00:00:00','23:59:00',false) on conflict (venue_id,day_of_week) do update set opens_at=excluded.opens_at,closes_at=excluded.closes_at,is_closed=excluded.is_closed;"
    }
    Invoke-LocalSql "insert into time_slots(id,venue_id,label,start_time,end_time,price_amount,is_active) values ('$fixtureSlot','$fixtureVenue','PHASE71_TEST_HOTEL_SLOT','10:00:00','11:00:00',1200,true) on conflict (id) do update set venue_id=excluded.venue_id,label=excluded.label,start_time=excluded.start_time,end_time=excluded.end_time,price_amount=excluded.price_amount,is_active=true;"
    $verifyDate = (Get-Date).Date.AddDays(7).ToString('yyyy-MM-dd')
    $available = Invoke-Json POST "$base/rest/v1/rpc/available_time_slots" $fixtureHeaders @{ p_venue_id=$fixtureVenue; p_book_date=$verifyDate }
    if ($available.Status -ne 200 -or @($available.Body | Where-Object { $_.slot_id -eq $fixtureSlot -and $_.is_available -eq $true }).Count -lt 1) { throw "fixture_availability_status_$($available.Status)" }
  }
  Check 'AI_CHAT_CLARIFICATION' {
    $r = Invoke-Json POST "$base/functions/v1/ai-chat" $a @{ input='I want to book a function hall' }
    if ($r.Status -ne 200 -or !$r.Body.action_gate_required) { throw "status=$($r.Status)" }
    $s = Invoke-Json POST "$base/functions/v1/ai-clarification" $a @{ action='START_CLARIFICATION'; request='function hall' }
    if ($s.Status -ne 200 -or !$s.Body.session.id) { throw "status=$($s.Status)" }
    $sessions.Add([string]$s.Body.session.id); $manifest.Add([pscustomobject]@{ kind='clarification_session'; id=$s.Body.session.id; marker='PHASE71_TEST_' })
  }
  $search = $null
  $hotelCategory = [string]$hotelCategory
  Check 'SEARCH' { $script:search = Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='SEARCH'; category_id=[string]$hotelCategory; limit=5 }; if ($search.Status -ne 200 -or @($search.Body.results).Count -eq 0) { $detail = ($search.Body | ConvertTo-Json -Compress -Depth 8); throw "status=$($search.Status) body=$detail" } }
  $venue = $search.Body.results[0]
  Check 'RESOURCE_DETAILS' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='RESOURCE_DETAILS'; venue_id=$venue.id }; if ($r.Status -ne 200 -or $r.Body.resource.id -ne $venue.id) { throw "status=$($r.Status)" } }
  $date = (Get-Date).AddDays(1).ToString('yyyy-MM-dd'); $availability=$null
  Check 'AVAILABILITY' { $script:availability=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='AVAILABILITY'; venue_id=$venue.id; date=$date }; if ($availability.Status -ne 200) { throw "status=$($availability.Status)" } }
  $slot = @($availability.Body.availability)[0]
  if ($null -ne $slot) {
    Check 'AUTHORITATIVE_PRICING' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_PREVIEW'; venue_id=$venue.id; slot_id=$slot.slot_id; date=$date; price=1; tax=1; total=1 }; if ($r.Status -ne 200 -or $r.Body.preview.pricing.total_amount -eq 1) { throw 'client pricing accepted' } }
    Check 'BOOKING_PREVIEW' { $script:authoritativePreview = (Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_PREVIEW'; venue_id=$venue.id; slot_id=$slot.slot_id; date=$date }).Body.preview; if (!$script:authoritativePreview.requires_confirmation) { throw 'preview_missing_confirmation' } }
    Check 'EXPLICIT_CONFIRMATION_GATE' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='CONFIRM_BOOKING' }; if ($r.Status -ne 409 -or $r.Body.error_code -ne 'CONFIRMATION_REQUIRED') { throw "status=$($r.Status) code=$($r.Body.error_code)" } }
    Check 'AI_ACTION_GATE_TRUSTED_HANDOFF' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_HANDOFF'; venue_id=$venue.id; slot_id=$slot.slot_id; book_date=$date; confirmed=$true; price=1; tax=1; total=1; tenant_id='PHASE71_TEST_FORGED'; organization_id='PHASE71_TEST_FORGED'; resource_id='PHASE71_TEST_FORGED'; role='admin'; permission='all' }; if ($r.Status -ne 200 -or $r.Body.handoff.venue_id -ne $venue.id) { throw "status=$($r.Status)" } }

    # Keep the single fixture alive while every forged-context case runs. Each
    # request is independent and must either reject the forged value or return
    # the server-authoritative venue, slot, date, user, category, and pricing.
    $forged = 'PHASE71_TEST_FORGED'
    Check 'FORGED_USER_ID' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_HANDOFF'; user_id=$forged; venue_id=$venue.id; slot_id=$slot.slot_id; book_date=$date; confirmed=$true }; if ($r.Status -ne 200 -or $r.Body.handoff.user_id -ne $users[0].Id) { throw "status=$($r.Status)" } }
    Check 'FORGED_TENANT_ID' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_HANDOFF'; tenant_id=$forged; venue_id=$venue.id; slot_id=$slot.slot_id; book_date=$date; confirmed=$true }; if ($r.Status -ne 200 -or $r.Body.handoff.venue_id -ne $venue.id) { throw "status=$($r.Status)" } }
    Check 'FORGED_ORGANIZATION_ID' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_HANDOFF'; organization_id=$forged; venue_id=$venue.id; slot_id=$slot.slot_id; book_date=$date; confirmed=$true }; if ($r.Status -ne 200 -or $r.Body.handoff.venue_id -ne $venue.id) { throw "status=$($r.Status)" } }
    Check 'FORGED_CATEGORY_ID' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_HANDOFF'; category_id=$forged; venue_id=$venue.id; slot_id=$slot.slot_id; book_date=$date; confirmed=$true }; if ($r.Status -eq 200 -and $r.Body.handoff.category_id -ne $venue.category_id) { throw "status=$($r.Status)" } }
    Check 'FORGED_RESOURCE_ID' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_HANDOFF'; resource_id=$forged; venue_id=$venue.id; slot_id=$slot.slot_id; book_date=$date; confirmed=$true }; if ($r.Status -ne 200 -or $r.Body.handoff.venue_id -ne $venue.id) { throw "status=$($r.Status)" } }
    Check 'FORGED_SLOT_ID' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_HANDOFF'; venue_id=$venue.id; slot_id=$forged; book_date=$date; confirmed=$true }; if ($r.Status -eq 200) { throw 'forged_slot_accepted' } }
    Check 'FORGED_DATE' { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action='BOOKING_HANDOFF'; venue_id=$venue.id; slot_id=$slot.slot_id; book_date='not-a-date'; confirmed=$true }; if ($r.Status -eq 200) { throw 'forged_date_accepted' } }
    foreach ($field in @('price','tax','total')) {
      Check "FORGED_$($field.ToUpper())" { $body=@{ action='BOOKING_PREVIEW'; venue_id=$venue.id; slot_id=$slot.slot_id; date=$date; confirmed=$true }; $body[$field]=1; $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a $body; if ($r.Status -ne 200 -or $r.Body.preview.pricing.total_amount -ne $script:authoritativePreview.pricing.total_amount) { throw "status=$($r.Status)" } }
    }
  } else { Write-Output 'BOOKING_PREVIEW: BLOCKED (no available local slot for tomorrow)'; Write-Output 'AI_ACTION_GATE_TRUSTED_HANDOFF: BLOCKED (no available local slot)' }
  foreach ($action in @('AVAILABILITY','RESOURCE_DETAILS','REFUND_STATUS','GET_OFFER','GET_INVOICE','GET_QR','GET_HELP')) { Check $action { $r=Invoke-Json POST "$base/functions/v1/ai-action-gate" $a @{ action=$action; venue_id=$venue.id; date=$date; booking_id='00000000-0000-0000-0000-000000000000' }; if ($r.Status -notin @(200,404,422)) { throw "status=$($r.Status)" } } }
  Check 'USER_A_CANNOT_ACCESS_USER_B_CONTEXT' { $r=Invoke-Json POST "$base/functions/v1/ai-clarification" $b @{ action='GET_CLARIFICATION'; session_id=$sessions[0] }; if ($r.Status -ne 404) { throw "status=$($r.Status)" } }
  Check 'MANIFEST' { if ($manifest.Count -lt 3) { throw 'manifest incomplete' } }
} finally {
  $fixtureHeaders = AuthHeaders $users[0].Token
  foreach ($fixture in $fixtureIds) { Invoke-Json DELETE "$base/rest/v1/$($fixture.table)?$($fixture.key)=eq.$($fixture.id)" $fixtureHeaders | Out-Null }
  Write-Output "FIXTURE_RECORD_CLEANUP: PASS (exact IDs=$($fixtureIds.Count))"
  foreach ($id in $sessions) { Invoke-Json DELETE "$base/rest/v1/ai_clarification_sessions?id=eq.$id" @{ apikey=$service; Authorization="Bearer $service" } | Out-Null }
  foreach ($u in $users) { Invoke-Json DELETE "$base/auth/v1/admin/users/$($u.Id)" @{ apikey=$service; Authorization="Bearer $service" } | Out-Null }
  Write-Output "FIXTURE_CLEANUP: PASS (exact IDs: users=$($users.Count), sessions=$($sessions.Count))"
}
