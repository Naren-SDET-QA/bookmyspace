# Launch Flutter Web against the remote DEV Supabase project.
# Reads only the ignored repository-root .env.dev.local; never prints secrets.
[CmdletBinding()]
param(
  [int]$WebPort = 8793
)

$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot '..\.env.dev.local'

if (-not (Test-Path -LiteralPath $envFile)) {
  Write-Error 'REMOTE_DEV_CONFIG_INVALID'
  exit 2
}

$values = @{}
foreach ($line in Get-Content -LiteralPath $envFile) {
  if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
    $values[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
  }
}

$supabaseUrl = $values['SUPABASE_URL']
$supabaseAnonKey = $values['SUPABASE_ANON_KEY']
$remoteUrl = $false
if (-not [string]::IsNullOrWhiteSpace($supabaseUrl)) {
  try {
    $uri = [Uri]$supabaseUrl
    $remoteUrl = $uri.Scheme -eq 'https' -and
      $uri.Host -match '^[a-z0-9]+\.supabase\.co$'
  } catch {
    $remoteUrl = $false
  }
}

if (-not $remoteUrl -or [string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  Write-Error 'REMOTE_DEV_CONFIG_INVALID'
  exit 2
}

$flutter = if (Get-Command flutter.bat -ErrorAction SilentlyContinue) {
  'flutter.bat'
} elseif (Test-Path 'C:\flutter\bin\flutter.bat') {
  'C:\flutter\bin\flutter.bat'
} else {
  Write-Error 'FLUTTER_NOT_FOUND'
  exit 2
}

& $flutter run -d chrome `
  --web-port $WebPort `
  --dart-define=APP_ENV=development `
  --dart-define=SUPABASE_URL=$supabaseUrl `
  --dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey
exit $LASTEXITCODE
