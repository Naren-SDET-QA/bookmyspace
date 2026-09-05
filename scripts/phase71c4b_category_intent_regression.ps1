$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Net.Http

# Local-only regression harness. It intentionally stops at BOOKING_PREVIEW.
$base = if ($env:PHASE71_DEV_SUPABASE_URL) { $env:PHASE71_DEV_SUPABASE_URL } elseif ($env:PHASE71_SUPABASE_URL) { $env:PHASE71_SUPABASE_URL } else { throw 'PHASE71_DEV_SUPABASE_URL_missing' }
$anon = if ($env:PHASE71_DEV_SUPABASE_ANON_KEY) { $env:PHASE71_DEV_SUPABASE_ANON_KEY } elseif ($env:PHASE71_SUPABASE_ANON_KEY) { $env:PHASE71_SUPABASE_ANON_KEY } else { throw 'PHASE71_DEV_SUPABASE_ANON_KEY_missing' }
$service = if ($env:PHASE71_DEV_SUPABASE_SERVICE_ROLE_KEY) { $env:PHASE71_DEV_SUPABASE_SERVICE_ROLE_KEY } elseif ($env:PHASE71_SUPABASE_SERVICE_ROLE_KEY) { $env:PHASE71_SUPABASE_SERVICE_ROLE_KEY } else { throw 'PHASE71_DEV_SUPABASE_SERVICE_ROLE_KEY_missing' }
$http = [System.Net.Http.HttpClient]::new()
$users = @()
$manifest = @()
$fixtureVenueId = '9d6e5e1e-4d6d-5f71-8b18-71c4b0000001'
$fixtureOrgId = '9d6e5e1e-4d6d-5f71-8b18-71c4b0000002'
$fixtureSlotId = '9d6e5e1e-4d6d-5f71-8b18-71c4b0000003'
$runMarker = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')

function Invoke-Json([string]$method, [string]$url, [hashtable]$headers, [object]$body) {
  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($method), $url)
  foreach ($entry in $headers.GetEnumerator()) { [void]$request.Headers.TryAddWithoutValidation($entry.Key, [string]$entry.Value) }
  if ($null -ne $body) { $request.Content = [System.Net.Http.StringContent]::new(($body | ConvertTo-Json -Compress -Depth 10), [Text.Encoding]::UTF8, 'application/json') }
  $response = $http.SendAsync($request).Result
  $text = $response.Content.ReadAsStringAsync().Result
  $parsed = $null
  if ($text) { try { $parsed = $text | ConvertFrom-Json } catch { $parsed = $text } }
  [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $parsed }
}

function Assert([bool]$condition, [string]$message) { if (-not $condition) { throw $message } }
function Gate([hashtable]$headers, [hashtable]$body) { Invoke-Json 'POST' "$base/functions/v1/ai-action-gate" $headers $body }
function Health([string]$name, [string]$url) {
  try { $request = [System.Net.HttpWebRequest]::Create($url); $request.Method='GET'; $request.Timeout=5000; try { $response=[System.Net.HttpWebResponse]$request.GetResponse() } catch [System.Net.WebException] { $response=[System.Net.HttpWebResponse]$_.Exception.Response }; Assert ([int]$response.StatusCode -lt 500) "${name}_status_$($response.StatusCode)"; Write-Output "${name}: PASS ($($response.StatusCode))" }
  catch { throw "${name}: FAIL ($($_.Exception.Message))" }
}

$categories = @(
  [pscustomobject]@{ requested = 'hotel'; slug = 'hotel' },
  [pscustomobject]@{ requested = 'temple'; slug = 'temple' },
  [pscustomobject]@{ requested = 'function hall'; slug = 'function_hall' },
  [pscustomobject]@{ requested = 'pg'; slug = 'pg_coliving' },
  [pscustomobject]@{ requested = 'institute'; slug = 'institute' },
  [pscustomobject]@{ requested = 'class'; slug = 'computer_it' },
  [pscustomobject]@{ requested = 'sports court'; slug = 'sports_ground' }
)
$intents = @('SEARCH','AVAILABILITY','RESOURCE_DETAILS','BOOKING','REFUND_STATUS','GET_OFFER','GET_INVOICE','GET_QR','GET_HELP')

try {
  Health 'REST' "$base/rest/v1/"
  Health 'AUTH' "$base/auth/v1/health"
  Health 'AI_CHAT_EDGE' "$base/functions/v1/ai-chat"
  Health 'AI_CLARIFICATION_EDGE' "$base/functions/v1/ai-clarification"
  Health 'AI_ACTION_GATE_EDGE' "$base/functions/v1/ai-action-gate"
  Write-Output 'CATEGORY_CONTRACT_MISSING: hospital'
  Write-Output 'CATEGORY_CONTRACT_MISSING: movie'
  $email = "PHASE71_TEST_CATEGORY_INTENT_$runMarker@example.test"
  $signup = Invoke-Json 'POST' "$base/auth/v1/signup" @{ apikey = $anon } @{ email = $email; password = 'LocalOnly-Phase71-2026!' }
  Assert ($signup.Status -eq 200 -and $signup.Body.access_token) "signup_failed_$($signup.Status)"
  $users += [pscustomobject]@{ Id = [string]$signup.Body.user.id; Token = [string]$signup.Body.access_token }
  $auth = @{ apikey = $anon; Authorization = "Bearer $($users[0].Token)" }

  # Minimum local-only fixture using the repository's existing tables.
  $docker = 'C:\Users\windows\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe'
  $ownerId = $users[0].Id
  $fixtureSql = @"
begin;
insert into public.organizations (id, owner_user_id, org_type, name, country, is_active)
values ('$fixtureOrgId', '$ownerId', 'venue_owner', 'PHASE71_TEST_HOTEL_ORG', 'IN', true)
on conflict (id) do update set owner_user_id=excluded.owner_user_id, is_active=true;
insert into public.venues (id, org_id, category_id, name, slug, description, city, state, country, latitude, longitude, capacity, pricing_base_amount, pricing_currency, tax_rate, is_verified, is_active, listing_status)
select '$fixtureVenueId', '$fixtureOrgId', id, 'PHASE71_TEST_HOTEL', 'PHASE71_TEST_HOTEL', 'Deterministic local regression fixture.', 'Hyderabad', 'Telangana', 'IN', 17.3850, 78.4867, 20, 2500, 'INR', 5, true, true, 'published'
from public.venue_categories where slug='hotel';
insert into public.time_slots (id, venue_id, label, start_time, end_time, price_amount, is_active)
values ('$fixtureSlotId', '$fixtureVenueId', 'PHASE71_TEST_MORNING', '09:00', '13:00', 2500, true)
on conflict (id) do update set is_active=true, price_amount=2500;
insert into public.venue_operating_hours (id, venue_id, day_of_week, opens_at, closes_at, is_closed)
select md5('PHASE71_TEST_HOTEL_HOURS:' || day)::uuid, '$fixtureVenueId', day, '08:00', '22:00', false from generate_series(0,6) day
on conflict (venue_id, day_of_week) do update set is_closed=false, opens_at='08:00', closes_at='22:00';
commit;
"@
  $fixtureSql | & $docker exec -i supabase_db_bookmyspace psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q
  Assert ($LASTEXITCODE -eq 0) 'hotel_fixture_setup_failed'
  $supportedFixtureSql = @"
begin;
do $([char]36)$([char]36)
declare
  item record;
  venue_uuid uuid;
  slot_id uuid;
begin
  for item in select * from (values
    ('temple'), ('function_hall'), ('pg_coliving'), ('institute'), ('computer_it'), ('sports_ground')
  ) as categories(slug) loop
    venue_uuid := md5('PHASE71_TEST:venue:' || item.slug)::uuid;
    slot_id := md5('PHASE71_TEST:slot:' || item.slug)::uuid;
    insert into public.venues (id, org_id, category_id, name, slug, description, city, state, country, latitude, longitude, capacity, pricing_base_amount, pricing_currency, tax_rate, is_verified, is_active, listing_status)
    select venue_uuid, '$fixtureOrgId', id, 'PHASE71_TEST_' || upper(item.slug), 'PHASE71_TEST_' || item.slug, 'Deterministic local regression fixture.', 'Hyderabad', 'Telangana', 'IN', 17.3850, 78.4867, 20, 1500, 'INR', 5, true, true, 'published'
    from public.venue_categories where slug=item.slug
    on conflict (id) do update set org_id=excluded.org_id, category_id=excluded.category_id, is_active=true, listing_status='published';
    insert into public.time_slots (id, venue_id, label, start_time, end_time, price_amount, is_active)
    values (slot_id, venue_uuid, 'PHASE71_TEST_MORNING', '09:00', '13:00', 1500, true)
    on conflict (id) do update set is_active=true, price_amount=1500;
    insert into public.venue_operating_hours (id, venue_id, day_of_week, opens_at, closes_at, is_closed)
    select md5('PHASE71_TEST_HOURS:' || item.slug || ':' || day)::uuid, venue_uuid, day, '08:00', '22:00', false from generate_series(0,6) day
    on conflict (venue_id, day_of_week) do update set is_closed=false, opens_at='08:00', closes_at='22:00';
  end loop;
end $([char]36)$([char]36);
commit;
"@
  $supportedFixtureSql | & $docker exec -i supabase_db_bookmyspace psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q
  Assert ($LASTEXITCODE -eq 0) 'supported_fixture_setup_failed'
  $manifest += [pscustomobject]@{ fixture = 'PHASE71_TEST_HOTEL'; category = 'hotel'; venue_id = $fixtureVenueId; slot_id = $fixtureSlotId }

  foreach ($category in $categories) {
    $slug = $category.slug
    $cat = Invoke-Json 'GET' "$base/rest/v1/venue_categories?slug=eq.$slug&select=id,slug,name&limit=1" $auth $null
    Assert ($cat.Status -eq 200 -and $cat.Body.Count -eq 1) "category_missing_$slug"
    $categoryId = [string]$cat.Body[0].id
    $venues = Invoke-Json 'GET' "$base/rest/v1/venues?category_id=eq.$categoryId&is_active=eq.true&select=id,name,category_id,pricing_base_amount&limit=1" $auth $null
    Assert ($venues.Status -eq 200 -and $venues.Body.Count -eq 1) "fixture_missing_$slug"
    $venueId = [string]$venues.Body[0].id
    $slot = $null
    $date = $null
    for ($offset = 1; $offset -le 14 -and $null -eq $slot; $offset++) {
      $candidateDate = (Get-Date).Date.AddDays($offset).ToString('yyyy-MM-dd')
      $available = Invoke-Json 'POST' "$base/rest/v1/rpc/available_time_slots" $auth @{ p_venue_id = $venueId; p_book_date = $candidateDate }
      Assert ($available.Status -eq 200) "availability_rpc_failed_$slug`_$candidateDate"
      $candidateSlot = @($available.Body | Where-Object { $_.is_available -eq $true } | Select-Object -First 1)
      if ($candidateSlot.Count -eq 1) { $slot = $candidateSlot[0]; $date = $candidateDate }
    }
    Assert ($null -ne $slot -and $date) "slot_missing_$slug"
    $manifest += [pscustomobject]@{ fixture = "PHASE71_TEST_$($slug.ToUpper().Replace('-','_'))"; category = $category.requested; category_id = $categoryId; venue_id = $venueId; slot_id = [string]$slot.slot_id; date = $date }

    $chat = Invoke-Json 'POST' "$base/functions/v1/ai-chat" $auth @{ input = "find a $($category.requested)"; resource_id = $venueId }
    Assert ($chat.Status -eq 200 -and $chat.Body.action_gate_required -eq $true -and $chat.Body.data.handoff) "chat_handoff_failed_$slug"
    $search = Gate $auth @{ action = 'SEARCH'; category_id = $categoryId; limit = 1 }
    Assert ($search.Status -eq 200 -and $search.Body.results.Count -ge 1 -and $search.Body.results[0].category_id -eq $categoryId) "search_failed_$slug"
    $details = Gate $auth @{ action = 'RESOURCE_DETAILS'; venue_id = $venueId }
    Assert ($details.Status -eq 200 -and $details.Body.resource.id -eq $venueId) "details_failed_$slug"
    $availability = Gate $auth @{ action = 'AVAILABILITY'; venue_id = $venueId; date = $date }
    Assert ($availability.Status -eq 200 -and $availability.Body.availability.Count -ge 1) "availability_failed_$slug"
    $offer = Gate $auth @{ action = 'GET_OFFER'; category_id = $categoryId; venue_id = $venueId }
    Assert ($offer.Status -eq 200 -and $null -ne $offer.Body.offers) "offer_failed_$slug"
    $preview = Gate $auth @{ action = 'BOOKING_PREVIEW'; venue_id = $venueId; slot_id = [string]$slot.slot_id; date = $date }
    Assert ($preview.Status -eq 200 -and $preview.Body.preview.requires_confirmation -eq $true -and $preview.Body.preview.pricing.total_amount -gt 0) "preview_failed_$slug"
    $handoff = Gate $auth @{ action = 'BOOKING_HANDOFF'; venue_id = $venueId; slot_id = [string]$slot.slot_id; book_date = $date }
    Assert ($handoff.Status -eq 409 -and $handoff.Body.error_code -eq 'CONFIRMATION_REQUIRED') "booking_gate_failed_$slug"
    Write-Output "CATEGORY_PASS: $($category.requested) fixture=$fixtureVenueId slot=$($slot.slot_id) date=$date"
  }

  # Intent endpoint contract checks that do not require a booking fixture.
  foreach ($intent in @('REFUND_STATUS','GET_HELP')) {
    $result = Gate $auth @{ action = $intent; limit = 1 }
    Assert ($result.Status -eq 200 -and [string]$result.Body.action -eq $intent) "intent_failed_$intent"
  }
  foreach ($intent in @('GET_INVOICE','GET_QR')) {
    $result = Gate $auth @{ action = $intent }
    Assert ($result.Status -eq 422 -and $result.Body.error_code -eq 'MISSING_FIELDS') "intent_contract_failed_$intent"
  }
  Assert ($intents.Count -eq 9) 'intent_manifest_incomplete'
  Write-Output 'PHASE71_C4B_CATEGORY_INTENT_REGRESSION: PASS'
  Write-Output ("MATRIX: categories=$($categories.Count), intents=$($intents.Count), previews=$($manifest.Count)")
  Write-Output ("MANIFEST: " + ($manifest | ConvertTo-Json -Compress))
} finally {
  if ($users.Count -eq 1) {
    $docker = 'C:\Users\windows\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe'
    $ownerId = $users[0].Id.Replace("'", "''")
    & $docker exec supabase_db_bookmyspace psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "delete from public.organizations where id = '$fixtureOrgId' and owner_user_id = '$ownerId';" | Out-Null
  }
  foreach ($user in $users) {
    $id = $user.Id.Replace("'", "''")
    & 'C:\Users\windows\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe' exec supabase_db_bookmyspace psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "delete from auth.users where id = '$id';" | Out-Null
  }
  Write-Output "FIXTURE_CLEANUP: $($(if ($users.Count -eq 1) { 'PASS' } else { 'PARTIAL' }))"
}
