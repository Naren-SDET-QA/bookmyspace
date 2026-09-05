$ErrorActionPreference = 'Stop'

$base = 'http://127.0.0.1:54321'
$docker = 'C:\Users\windows\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe'
$null = Add-Type -AssemblyName System.Net.Http
$http = [System.Net.Http.HttpClient]::new()
$status = supabase status --output env | ConvertFrom-StringData
$anon = $status.ANON_KEY

function Invoke-Json([string]$method, [string]$url, [hashtable]$headers, [object]$body) {
  $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($method), $url)
  foreach ($entry in $headers.GetEnumerator()) { [void]$request.Headers.TryAddWithoutValidation($entry.Key, [string]$entry.Value) }
  if ($null -ne $body) { $request.Content = [System.Net.Http.StringContent]::new(($body | ConvertTo-Json -Compress -Depth 10), [System.Text.Encoding]::UTF8, 'application/json') }
  $response = $http.SendAsync($request).Result
  $text = $response.Content.ReadAsStringAsync().Result
  [pscustomobject]@{ Status = [int]$response.StatusCode; Body = ($text | ConvertFrom-Json) }
}

$users = @()
try {
  foreach ($suffix in @('A', 'B')) {
    $email = "PHASE70D_TEST_USER_$suffix@example.test"
    $signup = Invoke-Json 'POST' "$base/auth/v1/signup" @{ apikey = $anon } @{ email = $email; password = 'LocalOnly-Phase70D-2026!' }
    if ($signup.Status -ne 200 -or [string]::IsNullOrWhiteSpace($signup.Body.access_token)) { throw "signup_failed_$suffix`_status_$($signup.Status)`_token_present_$([bool]$signup.Body.access_token)`_body_$($signup.Body | ConvertTo-Json -Compress)" }
    $users += [pscustomobject]@{ Id = $signup.Body.user.id; Token = $signup.Body.access_token }
  }

  $auth = @{ apikey = $anon; Authorization = "Bearer $($users[0].Token)" }
  foreach ($input in @('find a function hall', 'what is available tomorrow', 'show venue details', 'I want to book a hotel', 'what is my refund status', 'get my invoice', 'show my QR', 'help me')) {
    $result = Invoke-Json 'POST' "$base/functions/v1/ai-chat" $auth @{ input = $input }
    if ($result.Status -ne 200) { throw "ai_chat_failed_$($result.Status)" }
  }

  $clarification = Invoke-Json 'POST' "$base/functions/v1/ai-clarification" $auth @{ action = 'START_CLARIFICATION'; request = 'function hall' }
  if ($clarification.Status -notin @(200, 404, 409)) { throw "ai_clarification_unexpected_$($clarification.Status)`_body_$($clarification.Body | ConvertTo-Json -Compress)" }

  foreach ($action in @('SEARCH', 'AVAILABILITY', 'RESOURCE_DETAILS', 'BOOKING_STATUS', 'REFUND_STATUS', 'GET_INVOICE', 'GET_QR', 'GET_HELP')) {
    $result = Invoke-Json 'POST' "$base/functions/v1/ai-action-gate" $auth @{ action = $action }
    if ($result.Status -notin @(200, 400, 404, 422, 503)) { throw "ai_action_unexpected_$action`_$($result.Status)" }
  }
  $mutation = Invoke-Json 'POST' "$base/functions/v1/ai-action-gate" $auth @{ action = 'CONFIRM_BOOKING' }
  if ($mutation.Status -ne 409 -or $mutation.Body.error_code -ne 'CONFIRMATION_REQUIRED') { throw 'mutation_gate_failed' }

  Write-Output 'LOCAL_AUTH_AI_E2E: PASS'
  Write-Output 'AI_CHAT: PASS'
  Write-Output "AI_CLARIFICATION: $($clarification.Status)"
  Write-Output 'AI_ACTION_GATE: PASS'
  Write-Output 'MUTATION_PROTECTION: PASS'
} finally {
  foreach ($user in $users) {
    & $docker exec supabase_db_bookmyspace psql -U postgres -d postgres -v ON_ERROR_STOP=1 -Atc "delete from auth.users where id = '$($user.Id)';" | Out-Null
  }
  Write-Output "FIXTURE_CLEANUP: $($(if ($users.Count -eq 2) { 'PASS' } else { 'PARTIAL' }))"
}
