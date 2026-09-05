$ErrorActionPreference = 'Stop'

# PHASE 16.9 - REAL LOCAL E2E BOOKING FLOW (REST/RPC-driven, local Docker
# Supabase only). This drives the exact backend endpoints, RPCs, RLS
# policies, and Edge Functions the Flutter app calls - real password
# signups, real acquire_booking_hold, real create-payment-order (which
# contacts Razorpay's TEST-mode API for a real sandbox order - no real
# money ever moves), a correctly HMAC-signed simulated Razorpay webhook
# delivery (standard way to test payment-captured without driving
# Checkout.js), real owner-booking-manage approve/reject.
#
# This is NOT an Appium/Flutter-UI run: no Appium config or
# flutter integration_test suite exists anywhere in this repository, and
# this script does not exercise Flutter widget rendering, gestures,
# navigation, or the Android app's real Razorpay Checkout SDK screen. It
# proves the real backend chain the app calls (same RPCs/RLS/Edge
# Functions), which is the same pattern already used by
# scripts/phase71c4d_authenticated_local_e2e.ps1 in this repo.
#
# Local CLI defaults; callers may override via env vars or -RazorpayWebhookSecret.
param(
  [string]$RazorpayWebhookSecret = $(if ($env:PHASE169_RAZORPAY_WEBHOOK_SECRET) { $env:PHASE169_RAZORPAY_WEBHOOK_SECRET } else { 'rzp_test_dev_webhook' })
)

$base = if ($env:PHASE169_SUPABASE_URL) { $env:PHASE169_SUPABASE_URL } else { throw 'PHASE169_SUPABASE_URL_missing' }
$anon = if ($env:PHASE169_SUPABASE_ANON_KEY) { $env:PHASE169_SUPABASE_ANON_KEY } else { throw 'PHASE169_SUPABASE_ANON_KEY_missing' }
$service = if ($env:PHASE169_SUPABASE_SERVICE_ROLE_KEY) { $env:PHASE169_SUPABASE_SERVICE_ROLE_KEY } else { throw 'PHASE169_SUPABASE_SERVICE_ROLE_KEY_missing' }

$runMarker = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
$results = [System.Collections.Generic.List[object]]::new()
$users = [System.Collections.Generic.List[object]]::new()
$fixtureIds = [System.Collections.Generic.List[object]]::new()
$paymentOrderCreated = $false

function Invoke-Json([string]$method, [string]$url, [hashtable]$headers, [object]$body = $null) {
  $request = [System.Net.HttpWebRequest]::Create($url); $request.Method = $method; $request.Timeout = 15000; $request.ReadWriteTimeout = 15000
  foreach ($key in $headers.Keys) { $request.Headers[$key] = [string]$headers[$key] }
  if ($null -ne $body) { $bytes = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress -Depth 12)); $request.ContentType = 'application/json'; $request.ContentLength = $bytes.Length; $stream = $request.GetRequestStream(); $stream.Write($bytes, 0, $bytes.Length); $stream.Dispose() }
  try { $response = [System.Net.HttpWebResponse]$request.GetResponse() } catch [System.Net.WebException] { $response = [System.Net.HttpWebResponse]$_.Exception.Response }
  $reader = [IO.StreamReader]::new($response.GetResponseStream()); $text = $reader.ReadToEnd(); $reader.Dispose()
  $parsed = $null; if ($text) { try { $parsed = $text | ConvertFrom-Json } catch { $parsed = $text } }
  [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $parsed }
}

function Invoke-RawPost([string]$url, [hashtable]$headers, [string]$rawBody) {
  $request = [System.Net.HttpWebRequest]::Create($url); $request.Method = 'POST'; $request.Timeout = 15000; $request.ReadWriteTimeout = 15000
  $request.ContentType = 'application/json'
  foreach ($key in $headers.Keys) { $request.Headers[$key] = [string]$headers[$key] }
  $bytes = [Text.Encoding]::UTF8.GetBytes($rawBody)
  $request.ContentLength = $bytes.Length
  $stream = $request.GetRequestStream(); $stream.Write($bytes, 0, $bytes.Length); $stream.Dispose()
  try { $response = [System.Net.HttpWebResponse]$request.GetResponse() } catch [System.Net.WebException] { $response = [System.Net.HttpWebResponse]$_.Exception.Response }
  $reader = [IO.StreamReader]::new($response.GetResponseStream()); $text = $reader.ReadToEnd(); $reader.Dispose()
  $parsed = $null; if ($text) { try { $parsed = $text | ConvertFrom-Json } catch { $parsed = $text } }
  [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $parsed }
}

function Hmac-Hex([string]$secret, [string]$message) {
  $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($secret))
  $hash = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($message))
  $hmac.Dispose()
  -join ($hash | ForEach-Object { $_.ToString('x2') })
}

function Check([string]$name, [scriptblock]$test) {
  try { & $test; Write-Output "${name}: PASS"; $script:results.Add([pscustomobject]@{ Name = $name; Result = 'PASS' }) }
  catch { Write-Output "${name}: FAIL ($($_.Exception.Message))"; $script:results.Add([pscustomobject]@{ Name = $name; Result = "FAIL ($($_.Exception.Message))" }) }
}
function Blocked([string]$name, [string]$reason) {
  Write-Output "${name}: BLOCKED ($reason)"; $script:results.Add([pscustomobject]@{ Name = $name; Result = "BLOCKED ($reason)" })
}
function AuthHeaders($token) { @{ apikey = $anon; Authorization = "Bearer $token" } }
function Invoke-LocalSql([string]$sql) {
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql))
  & docker.exe exec supabase_db_bookmyspace sh -lc "echo $encoded | base64 -d | psql -U postgres -d postgres -v ON_ERROR_STOP=1" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "local_sql_status_$LASTEXITCODE" }
}
function Query-LocalSql([string]$sql) {
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql))
  $out = & docker.exe exec supabase_db_bookmyspace sh -lc "echo $encoded | base64 -d | psql -U postgres -d postgres -v ON_ERROR_STOP=1 -t -A"
  if ($LASTEXITCODE -ne 0) { throw "local_sql_status_$LASTEXITCODE" }
  return ($out -join "`n").Trim()
}
function Health([string]$name, [string]$url, [int[]]$allowed = @(200), [string]$method = 'Head') {
  try { $request = [System.Net.HttpWebRequest]::Create($url); $request.Method = $method; $request.Timeout = 5000; try { $response = [System.Net.HttpWebResponse]$request.GetResponse() } catch [System.Net.WebException] { $response = [System.Net.HttpWebResponse]$_.Exception.Response }; if ($allowed -notcontains [int]$response.StatusCode) { throw "status_$($response.StatusCode)" }; Check $name { } }
  catch { Check $name { throw $_.Exception.Message } }
}

Write-Output "=== PHASE 16.9 REAL LOCAL E2E BOOKING FLOW (run marker: $runMarker) ==="

try {
  # ---------------------------------------------------------------
  # 0. Health
  # ---------------------------------------------------------------
  Health 'REST' "$base/rest/v1/"
  Health 'AUTH' "$base/auth/v1/health" @(200) 'Get'
  Health 'EDGE_CREATE_BOOKING_HOLD' "$base/functions/v1/create-booking-hold" @(405)
  Health 'EDGE_CREATE_PAYMENT_ORDER' "$base/functions/v1/create-payment-order" @(405)
  Health 'EDGE_OWNER_BOOKING_MANAGE' "$base/functions/v1/owner-booking-manage" @(405)

  # ---------------------------------------------------------------
  # 1. Customer / owner signup + login (real Supabase Auth, password grant)
  # ---------------------------------------------------------------
  foreach ($role in @('OWNER', 'CUSTOMER_A', 'CUSTOMER_B')) {
    $email = "PHASE169_${role}_$runMarker@example.test".ToLower()
    $r = Invoke-Json POST "$base/auth/v1/signup" @{ apikey = $anon } @{ email = $email; password = 'LocalOnly-Phase169-2026!' }
    if ($r.Status -ne 200 -or !$r.Body.access_token) { throw "signup_${role}_status=$($r.Status)" }
    $u = [pscustomobject]@{ Role = $role; Id = [string]$r.Body.user.id; Token = [string]$r.Body.access_token; Email = $email }
    $users.Add($u)
  }
  $owner = $users | Where-Object { $_.Role -eq 'OWNER' }
  $custA = $users | Where-Object { $_.Role -eq 'CUSTOMER_A' }
  $custB = $users | Where-Object { $_.Role -eq 'CUSTOMER_B' }
  Check 'CUSTOMER_SIGNUP_LOGIN' { if (!$custA.Token -or !$custB.Token) { throw 'missing customer JWT' } }

  # complete_owner_registration only requires auth.uid() - a real password
  # session can call it directly via REST, same RPC the OTP-driven Flutter
  # onboarding screen calls (see 20260823170000_secure_owner_registration_role.sql).
  Check 'OWNER_REGISTRATION' {
    $r = Invoke-Json POST "$base/rest/v1/rpc/complete_owner_registration" (AuthHeaders $owner.Token) @{ p_name = "Phase169 Owner $runMarker" }
    if ($r.Status -ne 200 -and $r.Status -ne 204) { throw "status=$($r.Status)" }
  }

  # ---------------------------------------------------------------
  # 2. Fixture setup (service-role SQL; precondition data only - category,
  #    org, venue, operating hours, one time slot. Not the flow under test.)
  # ---------------------------------------------------------------
  $categoryId = '16900000-0000-0000-0000-000000000001'
  $orgId = '16900000-0000-0000-0000-000000000002'
  $venueId = '16900000-0000-0000-0000-000000000003'
  $slotId = '16900000-0000-0000-0000-000000000004'
  $tokenAmount = 1000
  $slotPrice = 5000
  foreach ($f in @(
      @{ table = 'venues'; id = $venueId },
      @{ table = 'organizations'; id = $orgId },
      @{ table = 'venue_categories'; id = $categoryId }
    )) { $fixtureIds.Add([pscustomobject]$f) }

  Check 'FIXTURE_SETUP' {
    Invoke-LocalSql @"
insert into venue_categories(id,slug,name,metadata) values
  ('$categoryId','phase169-test-cat-$runMarker','Phase169 Test Category', jsonb_build_object('active',true,'payments_enabled',true))
  on conflict (id) do update set metadata=excluded.metadata;
insert into organizations(id,owner_user_id,org_type,name) values
  ('$orgId','$($owner.Id)','venue_owner','PHASE169_TEST_ORG_$runMarker')
  on conflict (id) do update set owner_user_id=excluded.owner_user_id,name=excluded.name;
insert into venues(id,org_id,category_id,name,slug,description,city,state,latitude,longitude,capacity,pricing_base_amount,tax_rate,is_active,listing_status,booking_token_amount) values
  ('$venueId','$orgId','$categoryId','PHASE169_TEST_VENUE_$runMarker','phase169-test-venue-$runMarker','Local-only Phase 16.9 fixture venue','Hyderabad','Telangana',17.385044,78.486671,10,$slotPrice,0,true,'published',$tokenAmount)
  on conflict (id) do update set org_id=excluded.org_id,category_id=excluded.category_id,is_active=true,listing_status='published',booking_token_amount=excluded.booking_token_amount;
"@
    for ($day = 0; $day -le 6; $day++) {
      Invoke-LocalSql "insert into venue_operating_hours(venue_id,day_of_week,opens_at,closes_at,is_closed) values ('$venueId',$day,'00:00:00','23:59:00',false) on conflict (venue_id,day_of_week) do update set opens_at=excluded.opens_at,closes_at=excluded.closes_at,is_closed=excluded.is_closed;"
    }
    Invoke-LocalSql "insert into time_slots(id,venue_id,label,start_time,end_time,price_amount,is_active) values ('$slotId','$venueId','PHASE169_TEST_SLOT','18:00:00','22:00:00',$slotPrice,true) on conflict (id) do update set venue_id=excluded.venue_id,is_active=true,price_amount=excluded.price_amount;"
  }

  # ---------------------------------------------------------------
  # 3. Venue discovery: customer A can see the published venue/slot through
  #    the same read path the app uses (RLS + availability RPC).
  # ---------------------------------------------------------------
  $happyDate = (Get-Date).AddDays(10).ToString('yyyy-MM-dd')
  Check 'VENUE_DISCOVERY_LISTING' {
    $r = Invoke-Json GET "$base/rest/v1/venues?id=eq.$venueId&select=id,name,listing_status" (AuthHeaders $custA.Token)
    if ($r.Status -ne 200 -or @($r.Body).Count -ne 1 -or $r.Body[0].listing_status -ne 'published') { throw "status=$($r.Status)" }
    $avail = Invoke-Json POST "$base/rest/v1/rpc/available_time_slots" (AuthHeaders $custA.Token) @{ p_venue_id = $venueId; p_book_date = $happyDate }
    if ($avail.Status -ne 200 -or @($avail.Body | Where-Object { $_.slot_id -eq $slotId -and $_.is_available -eq $true }).Count -ne 1) { throw "availability status=$($avail.Status)" }
  }

  # ---------------------------------------------------------------
  # 4. Slot selection + hold (create-booking-hold), with idempotent retry
  # ---------------------------------------------------------------
  $holdKey = [guid]::NewGuid().ToString()
  $holdId = $null
  Check 'SLOT_SELECTION_AND_HOLD' {
    $r = Invoke-Json POST "$base/functions/v1/create-booking-hold" (AuthHeaders $custA.Token) @{ venue_id = $venueId; slot_id = $slotId; book_date = $happyDate; idempotency_key = $holdKey; amount = $slotPrice; hold_minutes = 10 }
    if ($r.Status -ne 200 -or !$r.Body.hold_id) { throw "status=$($r.Status)" }
    $script:holdId = [string]$r.Body.hold_id
  }
  Check 'HOLD_RETRY_IDEMPOTENCY' {
    $r = Invoke-Json POST "$base/functions/v1/create-booking-hold" (AuthHeaders $custA.Token) @{ venue_id = $venueId; slot_id = $slotId; book_date = $happyDate; idempotency_key = $holdKey; amount = $slotPrice; hold_minutes = 10 }
    if ($r.Status -ne 200 -or [string]$r.Body.hold_id -ne $holdId) { throw "status=$($r.Status) hold_id=$($r.Body.hold_id)" }
  }

  # ---------------------------------------------------------------
  # 5. Booking creation: same insert the (fixed) client performs directly -
  #    status must start 'pending' so create-payment-order will authorize it.
  # ---------------------------------------------------------------
  $bookingId = $null
  Check 'BOOKING_CREATED_PENDING' {
    $r = Invoke-Json POST "$base/rest/v1/bookings" (AuthHeaders $custA.Token) @{ booking_ref = "BMS-P169-$runMarker"; user_id = $custA.Id; venue_id = $venueId; slot_id = $slotId; book_date = $happyDate; start_time = '18:00:00'; end_time = '22:00:00'; hold_id = $holdId; status = 'pending'; quantity = 1; amount = $slotPrice; tax_amount = 0; total_amount = $slotPrice; currency = 'INR' }
    if ($r.Status -ne 201 -or @($r.Body).Count -ne 1) { throw "status=$($r.Status)" }
    $script:bookingId = [string]$r.Body[0].id
    if ([string]$r.Body[0].status -ne 'pending') { throw "unexpected initial status $($r.Body[0].status)" }
  }

  # ---------------------------------------------------------------
  # 6. Negative paths that do not require payment
  # ---------------------------------------------------------------
  Check 'UNAVAILABLE_SLOT_BLOCKED_FOR_OTHER_CUSTOMER' {
    $r = Invoke-Json POST "$base/functions/v1/create-booking-hold" (AuthHeaders $custB.Token) @{ venue_id = $venueId; slot_id = $slotId; book_date = $happyDate; idempotency_key = [guid]::NewGuid().ToString(); amount = $slotPrice; hold_minutes = 10 }
    if ($r.Status -ne 409 -or [string]$r.Body.error -ne 'slot_unavailable') { throw "status=$($r.Status) error=$($r.Body.error)" }
  }
  Check 'DUPLICATE_BOOKING_BLOCKED' {
    $r = Invoke-Json POST "$base/rest/v1/bookings" (AuthHeaders $custA.Token) @{ booking_ref = "BMS-P169-DUP-$runMarker"; user_id = $custA.Id; venue_id = $venueId; slot_id = $slotId; book_date = $happyDate; start_time = '18:00:00'; end_time = '22:00:00'; status = 'pending'; quantity = 1; amount = $slotPrice; tax_amount = 0; total_amount = $slotPrice; currency = 'INR' }
    if ($r.Status -ne 409 -and $r.Status -ne 400) { throw "expected exclusion-violation status, got $($r.Status)" }
  }
  Check 'PAYMENT_CROSS_USER_AUTHORIZATION_BLOCKED' {
    $r = Invoke-Json POST "$base/functions/v1/create-payment-order" (AuthHeaders $custB.Token) @{ booking_id = $bookingId }
    if ($r.Status -ne 403 -or [string]$r.Body.error -ne 'not_authorized') { throw "status=$($r.Status) error=$($r.Body.error)" }
  }

  # ---------------------------------------------------------------
  # 7. Payment order creation (real Razorpay TEST-mode API call). This
  #    also regression-checks Phase 16.8: the charge must equal the
  #    venue's configured token amount, clamped, never the full price.
  # ---------------------------------------------------------------
  $orderId = $null
  $chargeAmount = $null
  Check 'PAYMENT_ORDER_CREATED_CHARGES_CONFIGURED_TOKEN' {
    $r = Invoke-Json POST "$base/functions/v1/create-payment-order" (AuthHeaders $custA.Token) @{ booking_id = $bookingId }
    if ($r.Status -eq 502 -or ($r.Body -and [string]$r.Body.error -eq 'payment_order_failed')) {
      throw 'razorpay_test_credentials_not_configured'
    }
    if ($r.Status -ne 200 -or !$r.Body.order_id) { throw "status=$($r.Status) body=$($r.Body | ConvertTo-Json -Compress)" }
    if ([double]$r.Body.amount -ne $tokenAmount) { throw "expected charge=$tokenAmount got $($r.Body.amount)" }
    $script:orderId = [string]$r.Body.order_id
    $script:chargeAmount = [double]$r.Body.amount
    $script:paymentOrderCreated = $true
  }

  if (-not $paymentOrderCreated) {
    Blocked 'PAYMENT_ORDER_RETRY_IDEMPOTENT' 'no order to retry (see PAYMENT_ORDER_CREATED_CHARGES_CONFIGURED_TOKEN)'
    Blocked 'WEBHOOK_PAYMENT_CAPTURED_MOVES_TO_PENDING_OWNER_APPROVAL' 'no payment order was created'
    Blocked 'WEBHOOK_REDELIVERY_IS_NOOP' 'no payment order was created'
    Blocked 'OWNER_VIEW_PENDING_BOOKING' 'booking never reached pending_owner_approval'
    Blocked 'OWNER_APPROVE_CONFIRMS_BOOKING_ONCE' 'booking never reached pending_owner_approval'
    Blocked 'RE_APPROVE_ALREADY_CONFIRMED_BLOCKED' 'booking was never confirmed'
    Blocked 'CUSTOMER_REFRESH_REOPEN_PERSISTENCE' 'booking was never confirmed'
    Write-Output ''
    Write-Output 'REMEDIATION for PAYMENT_ORDER_CREATED_CHARGES_CONFIGURED_TOKEN: create-payment-order'
    Write-Output 'calls the real Razorpay TEST-mode Orders API (api.razorpay.com/v1/orders) with'
    Write-Output 'RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET from the local Edge Function environment.'
    Write-Output 'The .env.dev.example placeholders (rzp_test_dev_key_id / rzp_test_dev_secret) are'
    Write-Output 'not real credentials and Razorpay will reject them. To unblock the payment,'
    Write-Output 'webhook and owner-approve steps: create a free Razorpay TEST-mode account,'
    Write-Output 'copy its Key Id / Key Secret and Webhook Secret into your local .env.dev, then'
    Write-Output 'restart `supabase functions serve` (or `supabase start`) so the Edge Function'
    Write-Output 'picks them up. This never charges real money - Razorpay test mode is a sandbox.'
    Write-Output ''
  } else {
    Check 'PAYMENT_ORDER_RETRY_IDEMPOTENT' {
      $r = Invoke-Json POST "$base/functions/v1/create-payment-order" (AuthHeaders $custA.Token) @{ booking_id = $bookingId }
      if ($r.Status -ne 200 -or [string]$r.Body.order_id -ne $orderId) { throw "status=$($r.Status) order_id=$($r.Body.order_id) expected=$orderId" }
    }

    # -------------------------------------------------------------
    # 8. Simulated Razorpay webhook delivery: correctly HMAC-signed, not a
    #    real payment. This is the standard way to test a webhook receiver
    #    without driving the Checkout.js UI.
    # -------------------------------------------------------------
    $eventId = "evt_phase169_$runMarker"
    $paymentIdFake = "pay_phase169_$runMarker"
    $amountPaise = [int][math]::Round($chargeAmount * 100)
    $payload = [ordered]@{
      id      = $eventId
      event   = 'payment.captured'
      payload = @{ payment = @{ entity = @{ id = $paymentIdFake; order_id = $orderId; amount = $amountPaise; currency = 'INR' } } }
    }
    $rawBody = $payload | ConvertTo-Json -Compress -Depth 10
    $signature = Hmac-Hex $RazorpayWebhookSecret $rawBody

    Check 'WEBHOOK_PAYMENT_CAPTURED_MOVES_TO_PENDING_OWNER_APPROVAL' {
      $r = Invoke-RawPost "$base/functions/v1/razorpay-webhook" @{ apikey = $anon; 'x-razorpay-signature' = $signature } $rawBody
      if ($r.Status -ne 200) { throw "webhook status=$($r.Status) body=$($r.Body | ConvertTo-Json -Compress)" }
      $status = Query-LocalSql "select status from bookings where id='$bookingId';"
      if ($status -ne 'pending_owner_approval') { throw "booking status is '$status', expected pending_owner_approval" }
    }
    Check 'WEBHOOK_REDELIVERY_IS_NOOP' {
      $r = Invoke-RawPost "$base/functions/v1/razorpay-webhook" @{ apikey = $anon; 'x-razorpay-signature' = $signature } $rawBody
      if ($r.Status -ne 200 -or [string]$r.Body.status -ne 'duplicate') { throw "status=$($r.Status) body=$($r.Body | ConvertTo-Json -Compress)" }
      $status = Query-LocalSql "select status from bookings where id='$bookingId';"
      if ($status -ne 'pending_owner_approval') { throw "redelivery mutated booking status to '$status'" }
    }

    # -------------------------------------------------------------
    # 9. Owner reviews and approves; verify booking_orders created exactly once.
    # -------------------------------------------------------------
    Check 'OWNER_VIEW_PENDING_BOOKING' {
      $r = Invoke-Json GET "$base/rest/v1/bookings?id=eq.$bookingId&select=id,status,venue_id" (AuthHeaders $owner.Token)
      if ($r.Status -ne 200 -or @($r.Body).Count -ne 1 -or $r.Body[0].status -ne 'pending_owner_approval') { throw "status=$($r.Status)" }
    }
    Check 'OWNER_CROSS_USER_APPROVAL_BLOCKED' {
      $r = Invoke-Json POST "$base/functions/v1/owner-booking-manage" (AuthHeaders $custB.Token) @{ action = 'approve'; booking_id = $bookingId }
      if ($r.Status -ne 403 -or [string]$r.Body.error -ne 'not_owner') { throw "status=$($r.Status) error=$($r.Body.error)" }
    }
    Check 'OWNER_APPROVE_CONFIRMS_BOOKING_ONCE' {
      $r = Invoke-Json POST "$base/functions/v1/owner-booking-manage" (AuthHeaders $owner.Token) @{ action = 'approve'; booking_id = $bookingId }
      if ($r.Status -ne 200 -or [string]$r.Body.status -ne 'confirmed') { throw "status=$($r.Status) body=$($r.Body | ConvertTo-Json -Compress)" }
      $orderCount = Query-LocalSql "select count(*) from booking_orders where booking_id='$bookingId';"
      if ($orderCount -ne '1') { throw "booking_orders count=$orderCount, expected exactly 1" }
    }
    Check 'RE_APPROVE_ALREADY_CONFIRMED_BLOCKED' {
      $r = Invoke-Json POST "$base/functions/v1/owner-booking-manage" (AuthHeaders $owner.Token) @{ action = 'approve'; booking_id = $bookingId }
      if ($r.Status -ne 409 -or [string]$r.Body.error -ne 'invalid_transition') { throw "status=$($r.Status) error=$($r.Body.error)" }
    }
    Check 'CUSTOMER_REFRESH_REOPEN_PERSISTENCE' {
      $r = Invoke-Json GET "$base/rest/v1/bookings?id=eq.$bookingId&select=id,status" (AuthHeaders $custA.Token)
      if ($r.Status -ne 200 -or @($r.Body).Count -ne 1 -or $r.Body[0].status -ne 'confirmed') { throw "status=$($r.Status)" }
    }
  }

  # ---------------------------------------------------------------
  # 10. Reject path - runs independently of Razorpay credentials: the
  #     owner-decide guard accepts a 'pending' booking directly, so this
  #     covers reject / cannot-re-decide / slot-freed even when payment was
  #     blocked above.
  # ---------------------------------------------------------------
  $rejectDate = (Get-Date).AddDays(11).ToString('yyyy-MM-dd')
  $rejectBookingId = $null
  Check 'REJECT_PATH_FIXTURE_BOOKING' {
    $holdKey2 = [guid]::NewGuid().ToString()
    $h = Invoke-Json POST "$base/functions/v1/create-booking-hold" (AuthHeaders $custA.Token) @{ venue_id = $venueId; slot_id = $slotId; book_date = $rejectDate; idempotency_key = $holdKey2; amount = $slotPrice; hold_minutes = 10 }
    if ($h.Status -ne 200 -or !$h.Body.hold_id) { throw "hold status=$($h.Status)" }
    $r = Invoke-Json POST "$base/rest/v1/bookings" (AuthHeaders $custA.Token) @{ booking_ref = "BMS-P169-REJ-$runMarker"; user_id = $custA.Id; venue_id = $venueId; slot_id = $slotId; book_date = $rejectDate; start_time = '18:00:00'; end_time = '22:00:00'; hold_id = [string]$h.Body.hold_id; status = 'pending'; quantity = 1; amount = $slotPrice; tax_amount = 0; total_amount = $slotPrice; currency = 'INR' }
    if ($r.Status -ne 201 -or @($r.Body).Count -ne 1) { throw "booking status=$($r.Status)" }
    $script:rejectBookingId = [string]$r.Body[0].id
  }
  Check 'OWNER_REJECT' {
    $r = Invoke-Json POST "$base/functions/v1/owner-booking-manage" (AuthHeaders $owner.Token) @{ action = 'reject'; booking_id = $rejectBookingId }
    if ($r.Status -ne 200 -or [string]$r.Body.status -ne 'rejected') { throw "status=$($r.Status) body=$($r.Body | ConvertTo-Json -Compress)" }
  }
  Check 'REJECTED_BOOKING_CANNOT_BE_RE_DECIDED' {
    $r = Invoke-Json POST "$base/functions/v1/owner-booking-manage" (AuthHeaders $owner.Token) @{ action = 'approve'; booking_id = $rejectBookingId }
    if ($r.Status -ne 409 -or [string]$r.Body.error -ne 'invalid_transition') { throw "status=$($r.Status) error=$($r.Body.error)" }
  }
  Check 'SLOT_FREED_AFTER_REJECT' {
    $h = Invoke-Json POST "$base/functions/v1/create-booking-hold" (AuthHeaders $custB.Token) @{ venue_id = $venueId; slot_id = $slotId; book_date = $rejectDate; idempotency_key = [guid]::NewGuid().ToString(); amount = $slotPrice; hold_minutes = 10 }
    if ($h.Status -ne 200 -or !$h.Body.hold_id) { throw "status=$($h.Status)" }
  }

  # ---------------------------------------------------------------
  Write-Output ''
  $fail = @($results | Where-Object { $_.Result -like 'FAIL*' })
  $blocked = @($results | Where-Object { $_.Result -like 'BLOCKED*' })
  Write-Output "SUMMARY: $($results.Count) checks, $($fail.Count) FAIL, $($blocked.Count) BLOCKED, $($results.Count - $fail.Count - $blocked.Count) PASS"
  if ($fail.Count -gt 0) { Write-Output 'FAILED CHECKS:'; $fail | ForEach-Object { Write-Output "  - $($_.Name): $($_.Result)" } }
  if ($blocked.Count -gt 0) { Write-Output 'BLOCKED CHECKS:'; $blocked | ForEach-Object { Write-Output "  - $($_.Name): $($_.Result)" } }
}
finally {
  Write-Output ''
  Write-Output '=== CLEANUP (best-effort; local dev only) ==='
  foreach ($f in $fixtureIds) {
    try { Invoke-Json DELETE "$base/rest/v1/$($f.table)?id=eq.$($f.id)" @{ apikey = $service; Authorization = "Bearer $service" } | Out-Null } catch { }
  }
  foreach ($u in $users) {
    try { Invoke-Json DELETE "$base/auth/v1/admin/users/$($u.Id)" @{ apikey = $service; Authorization = "Bearer $service" } | Out-Null } catch { }
  }
  Write-Output "FIXTURE_CLEANUP: attempted (fixtures=$($fixtureIds.Count), users=$($users.Count))"
}
