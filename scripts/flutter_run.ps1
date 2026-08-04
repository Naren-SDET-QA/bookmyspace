# Loads Flutter dart-defines from the repo-root .env file (placeholders until you fill them in).
# Usage: .\scripts\flutter_run.ps1 [extra flutter run args...]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$envFile = Join-Path $repoRoot '.env'

if (-not (Test-Path $envFile)) {
    Write-Error "Missing .env file. Copy .env.example to .env and fill in your values."
}

$flutterKeys = @(
    'APP_ENV',
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'RAZORPAY_KEY_ID',
    'DEV_CUSTOMER_EMAIL',
    'DEV_CUSTOMER_PASSWORD',
    'DEV_OWNER_EMAIL',
    'DEV_OWNER_PASSWORD',
    'DEV_ADMIN_EMAIL',
    'DEV_ADMIN_PASSWORD'
)

$defines = @()
Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }

    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }

    $key = $line.Substring(0, $eq).Trim()
    $value = $line.Substring($eq + 1).Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
    }

    if ($flutterKeys -contains $key -and $value) {
        $defines += "--dart-define=$key=$value"
    }
}

Push-Location $repoRoot
try {
    if ($defines.Count -gt 0) {
        & flutter run @defines @FlutterArgs
    } else {
        & flutter run @FlutterArgs
    }
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
