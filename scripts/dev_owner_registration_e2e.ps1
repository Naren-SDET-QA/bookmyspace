# =============================================================================
# BookMySpace DEV ONLY — Owner Registration E2E driver
# =============================================================================
# Drives the EXACT production flow end-to-end against a Supabase project:
#
#   signInWithOtp (POST /auth/v1/otp)
#     -> 6-digit OTP email
#     -> verifyOTP (POST /auth/v1/verify, type=email)
#     -> authenticated session
#     -> complete_owner_registration(p_name) RPC (security definer)
#     -> owner_profiles row + active venue_owner role in user_roles
#
# No Auth users are created via SQL. No service-role key is used anywhere.
#
# When MAILPIT_BASE points at the local Supabase mail catcher, the 6-digit
# code is read automatically from the inbox. Against cloud DEV you must pass
# -OtpCode manually after reading your own mailbox.
#
# Usage (local):
#   pwsh ./scripts/dev_owner_registration_e2e.ps1 -Email dev.owner1@bookmyspace.test -Name "Dev Owner One"
# Usage (cloud DEV):
#   $env:BMS_SUPABASE_URL="https://<dev-ref>.supabase.co"
#   $env:BMS_SUPABASE_ANON_KEY="<publishable key>"
#   pwsh ./scripts/dev_owner_registration_e2e.ps1 -Email you@example.com -Name "You" -OtpCode 123456
# =============================================================================

param(
  [Parameter(Mandatory = $true)][string]$Email,
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$OtpCode,
  [string]$SupabaseUrl = $env:BMS_SUPABASE_URL,
  [string]$AnonKey = $env:BMS_SUPABASE_ANON_KEY,
  [string]$MailpitBase = $env:BMS_MAILPIT_URL
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) { $SupabaseUrl = 'http://127.0.0.1:54321' }
if ([string]::IsNullOrWhiteSpace($AnonKey)) { $AnonKey = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH' }
if ([string]::IsNullOrWhiteSpace($MailpitBase)) { $MailpitBase = 'http://127.0.0.1:54324' }

$headers = @{ apikey = $AnonKey; 'Content-Type' = 'application/json' }

function Read-OtpFromMailpit([string]$mailTo, [datetime]$notBefore) {
  $deadline = (Get-Date).AddSeconds(30)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 800
    $inbox = Invoke-RestMethod -Uri "$MailpitBase/api/v1/messages?limit=25" -Method Get
    foreach ($m in ($inbox.messages | Sort-Object Created -Descending)) {
      if ([datetime]$m.Created -lt $notBefore.AddSeconds(-5)) { continue }
      $toAddresses = @($m.To | ForEach-Object { $_.address })
      if ($toAddresses -notcontains $mailTo) { continue }
      if ($m.Subject -notmatch 'log ?in|confirmation|sign|verif|otp|code') { continue }
      $full = Invoke-RestMethod -Uri "$MailpitBase/api/v1/message/$($m.ID)" -Method Get
      # Prefer the plain-text part: the HTML part can contain unrelated
      # 6-digit sequences (hex colors etc.) that defeat a naive scan.
      $haystack = if ($full.Text) { $full.Text } else { $full.Html }
      $match = [regex]::Match($haystack, '\b(\d{6})\b')
      if ($match.Success) { return $match.Groups[1].Value }
    }
  }
  throw "OTP email for $mailTo did not arrive within 30s (check SMTP config)."
}

Write-Host "[1/4] requestOwnerOtp -> signInWithOtp($Email)"
$otpResponse = Invoke-RestMethod `
  -Uri "$SupabaseUrl/auth/v1/otp" `
  -Method Post -Headers $headers `
  -Body (@{ email = $Email; create_user = $true } | ConvertTo-Json)

if (-not $otpResponse) { throw 'signInWithOtp returned an empty response.' }
Write-Host "      OK (email dispatched by auth provider)"

if ([string]::IsNullOrWhiteSpace($OtpCode)) {
  Write-Host "[2/4] waiting for OTP email via mail catcher..."
  $startedAt = Get-Date
  $OtpCode = Read-OtpFromMailpit $Email $startedAt
  Write-Host "      received 6-digit code"
} else {
  Write-Host "[2/4] using caller-supplied OTP code"
}

Write-Host "[3/4] verifyOwnerOtp -> verifyOTP(type=email)"
$verifyHeaders = $headers.Clone()
$verify = Invoke-RestMethod `
  -Uri "$SupabaseUrl/auth/v1/verify" `
  -Method Post -Headers $verifyHeaders `
  -Body (@{ type = 'email'; email = $Email; token = $OtpCode } | ConvertTo-Json)

if (-not $verify.access_token) { throw 'verifyOTP did not return an access_token (no session created).' }
Write-Host "      session established for $($verify.user.email)"

Write-Host "[4/4] complete_owner_registration(p_name='$Name')"
$rpcHeaders = @{
  apikey        = $AnonKey
  Authorization = "Bearer $($verify.access_token)"
  'Content-Type' = 'application/json'
}
$ownerId = Invoke-RestMethod `
  -Uri "$SupabaseUrl/rest/v1/rpc/complete_owner_registration" `
  -Method Post -Headers $rpcHeaders `
  -Body (@{ p_name = $Name } | ConvertTo-Json)

Write-Host ""
Write-Host "SUCCESS owner_id=$ownerId"
Write-Host "ROLE_CHECK required: user_roles(role=venue_owner, revoked_at IS NULL) for $($verify.user.id)"
