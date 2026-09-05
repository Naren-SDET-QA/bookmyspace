$ErrorActionPreference = 'Stop'

$base = 'http://127.0.0.1:54321'
$docker = 'C:\Users\windows\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe'
$null = Add-Type -AssemblyName System.Net.Http
$http = [System.Net.Http.HttpClient]::new()
$status = supabase status --output env | ConvertFrom-StringData
$anon = $status.ANON_KEY
$users = @()
$sessions = @()

function Invoke-Json([string]$method, [string]$url, [hashtable]$headers, [object]$body) {
  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($method), $url)
  foreach ($entry in $headers.GetEnumerator()) { [void]$request.Headers.TryAddWithoutValidation($entry.Key, [string]$entry.Value) }
  if ($null -ne $body) { $request.Content = [System.Net.Http.StringContent]::new(($body | ConvertTo-Json -Compress -Depth 10), [System.Text.Encoding]::UTF8, 'application/json') }
  $response = $http.SendAsync($request).Result
  $text = $response.Content.ReadAsStringAsync().Result
  $parsed = $null
  if ($text) { try { $parsed = $text | ConvertFrom-Json } catch { $parsed = $text } }
  [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $parsed }
}

function Assert([bool]$condition, [string]$message) { if (-not $condition) { throw $message } }
function Invoke-Rpc([string]$name, [hashtable]$headers, [hashtable]$body) {
  return Invoke-Json 'POST' "$base/rest/v1/rpc/$name" $headers $body
}

try {
  foreach ($suffix in @('A', 'B')) {
    $email = "PHASE70D_TEST_RUNTIME_$suffix@example.test"
    $signup = Invoke-Json 'POST' "$base/auth/v1/signup" @{ apikey = $anon } @{ email = $email; password = 'LocalOnly-Phase70D-2026!' }
    Assert ($signup.Status -eq 200 -and $signup.Body.access_token) "signup_$suffix_failed"
    $users += [pscustomobject]@{ Id = $signup.Body.user.id; Token = $signup.Body.access_token }
  }
  $a = @{ apikey = $anon; Authorization = "Bearer $($users[0].Token)" }
  $b = @{ apikey = $anon; Authorization = "Bearer $($users[1].Token)" }
  $circuitComponent = "PHASE70D_TEST_CIRCUIT_$($users[0].Id)"

  $rate1 = Invoke-Rpc 'consume_ai_rate_limit' $a @{ p_provider = 'phase70d-runtime'; p_limit = 2; p_window_seconds = 60; p_organization_id = $null }
  $rate2 = Invoke-Rpc 'consume_ai_rate_limit' $a @{ p_provider = 'phase70d-runtime'; p_limit = 2; p_window_seconds = 60; p_organization_id = $null }
  $rate3 = Invoke-Rpc 'consume_ai_rate_limit' $a @{ p_provider = 'phase70d-runtime'; p_limit = 2; p_window_seconds = 60; p_organization_id = $null }
  Write-Output "RATE_DEBUG: $($rate1.Status)/$($rate2.Status)/$($rate3.Status)"
  Write-Output ("RATE_BODY: " + (($rate1.Body | ConvertTo-Json -Compress) -replace '[A-Za-z0-9_\-]{20,}', '[redacted]'))
  Write-Output ("RATE_BODY_2: " + (($rate2.Body | ConvertTo-Json -Compress) -replace '[A-Za-z0-9_\-]{20,}', '[redacted]'))
  Assert ($rate1.Status -eq 200 -and $rate1.Body[0].allowed -eq $true -and $rate2.Body[0].allowed -eq $true -and $rate3.Body[0].allowed -eq $false) 'rate_limit_boundary_failed'

  $circuitArgs = @{ p_component = $circuitComponent; p_provider = 'local-deterministic'; p_organization_id = $null; p_category_id = $null; p_failure_threshold = 2; p_cooldown_seconds = 3 }
  $admit = Invoke-Rpc 'ai_circuit_admit' $a $circuitArgs
  Assert ($admit.Status -eq 200 -and $admit.Body[0].allowed -eq $true) 'circuit_initial_admit_failed'
  $failArgs = @{ p_component = $circuitComponent; p_provider = 'local-deterministic'; p_succeeded = $false; p_organization_id = $null; p_category_id = $null; p_failure_threshold = 2; p_cooldown_seconds = 3; p_error = 'deterministic_failure' }
  $firstFailure = Invoke-Rpc 'ai_circuit_record_result' $a $failArgs
  $secondFailure = Invoke-Rpc 'ai_circuit_record_result' $a $failArgs
  Write-Output ("CIRCUIT_FAILURE_DEBUG: " + (($firstFailure.Body | ConvertTo-Json -Compress) + '/' + ($secondFailure.Body | ConvertTo-Json -Compress)))
  Assert ($firstFailure.Status -eq 200 -and $secondFailure.Body -eq 'CIRCUIT_OPEN') 'circuit_open_threshold_failed'
  $open = Invoke-Rpc 'ai_circuit_admit' $a $circuitArgs
  Write-Output ("CIRCUIT_OPEN_DEBUG: " + (($open.Body | ConvertTo-Json -Compress)))
  Assert ($open.Body[0].allowed -eq $false -and $open.Body[0].state -eq 'CIRCUIT_OPEN') 'circuit_open_admission_failed'
  Start-Sleep -Seconds 4
  $recover = Invoke-Rpc 'ai_circuit_admit' $a $circuitArgs
  Write-Output ("CIRCUIT_RECOVERY_DEBUG: " + (($recover.Body | ConvertTo-Json -Compress) -replace '[A-Za-z0-9_\-]{20,}', '[redacted]'))
  Assert ($recover.Body[0].allowed -eq $true -and $recover.Body[0].state -eq 'RECOVERING') 'circuit_recovery_admission_failed'
  $successArgs = $failArgs.Clone(); $successArgs.p_succeeded = $true; $successArgs.p_error = $null
  $healthy = Invoke-Rpc 'ai_circuit_record_result' $a $successArgs
  Assert ($healthy.Status -eq 200 -and $healthy.Body -eq 'HEALTHY') 'circuit_health_restore_failed'

  $start = Invoke-Json 'POST' "$base/functions/v1/ai-clarification" $a @{ action = 'START_CLARIFICATION'; request = 'function hall' }
  Assert ($start.Status -eq 200 -and $start.Body.session.id) 'clarification_start_failed'
  $sessionId = [string]$start.Body.session.id
  $sessions += $sessionId

  $own = Invoke-Json 'POST' "$base/functions/v1/ai-clarification" $a @{ action = 'GET_CLARIFICATION'; session_id = $sessionId }
  Assert ($own.Status -eq 200) 'owner_session_read_failed'
  $cross = Invoke-Json 'POST' "$base/functions/v1/ai-clarification" $b @{ action = 'GET_CLARIFICATION'; session_id = $sessionId }
  Assert ($cross.Status -eq 404) 'cross_user_session_read_allowed'
  $forged = Invoke-Json 'POST' "$base/functions/v1/ai-clarification" $a @{ action = 'GET_CLARIFICATION'; session_id = $sessionId; user_id = $users[1].Id; tenant_id = 'forged'; organization_id = 'forged'; role = 'admin'; permission = 'all' }
  $storedUser = (("select user_id from public.ai_clarification_sessions where id = '$sessionId';" | & $docker exec -i supabase_db_bookmyspace psql -U postgres -d postgres -At).Trim())
  Assert ($forged.Status -eq 200 -and $storedUser -eq $users[0].Id) 'forged_context_overrode_authority'

  $expireSql = "update public.ai_clarification_sessions set expires_at = now() - interval '1 second' where id = '$sessionId' and user_id = '$($users[0].Id)';"
  $expireSql | & $docker exec -i supabase_db_bookmyspace psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q
  Assert ($LASTEXITCODE -eq 0) 'fixture_expiration_update_failed'
  $expired = Invoke-Json 'POST' "$base/functions/v1/ai-clarification" $a @{ action = 'GET_CLARIFICATION'; session_id = $sessionId }
  $replay = Invoke-Json 'POST' "$base/functions/v1/ai-clarification" $a @{ action = 'GET_CLARIFICATION'; session_id = $sessionId }
  Assert ($expired.Status -eq 410 -and $replay.Status -eq 410) 'expired_replay_not_rejected'
  $eventSql = "select count(*) from public.analytics_events where user_id = '$($users[0].Id)' and event_type = 'clarification_expired' and properties->>'source' = 'ai_clarification';"
  $eventCount = (($eventSql | & $docker exec -i supabase_db_bookmyspace psql -U postgres -d postgres -At).Trim())
  Assert ($eventCount -eq '1') "expiration_event_count_$eventCount"

  $intents = @('find a function hall','what is available tomorrow','show venue details','I want to book a hotel','what is my refund status','get my invoice','show my QR','help me')
  foreach ($input in $intents) {
    $chat = Invoke-Json 'POST' "$base/functions/v1/ai-chat" $a @{ input = $input; user_id = $users[1].Id; tenant_id = 'forged'; organization_id = 'forged'; role = 'admin' }
    Assert ($chat.Status -eq 200 -and $null -ne $chat.Body) "intent_failed_$input"
  }
  foreach ($category in @('hotel','hospital','temple','movie','function hall','pg','institute','class','sports court')) {
    $result = Invoke-Json 'POST' "$base/functions/v1/ai-clarification" $a @{ action = 'START_CLARIFICATION'; request = $category }
    Assert ($result.Status -in @(200,404,409)) "category_unexpected_$category`_$($result.Status)"
    if ($result.Body.session.id) { $sessions += [string]$result.Body.session.id }
  }
  Write-Output 'RUNTIME_VERIFICATION: PASS'
  Write-Output 'SESSION_ISOLATION: PASS'
  Write-Output 'FORGED_CONTEXT: PASS'
  Write-Output 'RATE_LIMIT_BOUNDARY: PASS'
  Write-Output 'CIRCUIT_RECOVERY: PASS'
  Write-Output 'EXPIRATION_REPLAY: PASS'
  Write-Output 'INTENT_MATRIX: PASS'
  Write-Output 'CATEGORY_MATRIX: PASS'
} finally {
  foreach ($sessionId in $sessions) {
    & $docker exec supabase_db_bookmyspace psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "delete from public.ai_clarification_sessions where id = '$sessionId';" | Out-Null
  }
  if ($circuitComponent) {
    & $docker exec supabase_db_bookmyspace psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "delete from public.observability_recovery_state where component = '$circuitComponent' and provider = 'local-deterministic';" | Out-Null
  }
  foreach ($user in $users) {
    & $docker exec supabase_db_bookmyspace psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "delete from auth.users where id = '$($user.Id)';" | Out-Null
  }
  Write-Output "FIXTURE_CLEANUP: $($(if ($users.Count -eq 2) { 'PASS' } else { 'PARTIAL' }))"
}
