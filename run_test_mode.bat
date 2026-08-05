@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "envFile=.env"
set "appName=BookMySpace"

if not exist "%envFile%" (
    echo [ERROR] %envFile% not found in the project root.
    echo Copy .env.example to .env and add your test credentials.
    exit /b 1
)

set "DEV_CUSTOMER_EMAIL="
set "DEV_CUSTOMER_PASSWORD="
set "DEV_OWNER_EMAIL="
set "DEV_OWNER_PASSWORD="
set "DEV_ADMIN_EMAIL="
set "DEV_ADMIN_PASSWORD="
set "APP_ENV="
set "SUPABASE_URL="
set "SUPABASE_ANON_KEY="
set "RAZORPAY_KEY_ID="

for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"DEV_CUSTOMER_EMAIL=" "%envFile%"`) do set "DEV_CUSTOMER_EMAIL=%%b"
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"DEV_CUSTOMER_PASSWORD=" "%envFile%"`) do set "DEV_CUSTOMER_PASSWORD=%%b"
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"DEV_OWNER_EMAIL=" "%envFile%"`) do set "DEV_OWNER_EMAIL=%%b"
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"DEV_OWNER_PASSWORD=" "%envFile%"`) do set "DEV_OWNER_PASSWORD=%%b"
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"DEV_ADMIN_EMAIL=" "%envFile%"`) do set "DEV_ADMIN_EMAIL=%%b"
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"DEV_ADMIN_PASSWORD=" "%envFile%"`) do set "DEV_ADMIN_PASSWORD=%%b"
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"APP_ENV=" "%envFile%"`) do set "APP_ENV=%%b"
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"SUPABASE_URL=" "%envFile%"`) do set "SUPABASE_URL=%%b"
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"SUPABASE_ANON_KEY=" "%envFile%"`) do set "SUPABASE_ANON_KEY=%%b"
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"RAZORPAY_KEY_ID=" "%envFile%"`) do set "RAZORPAY_KEY_ID=%%b"
if not defined SUPABASE_URL for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"NEXT_PUBLIC_SUPABASE_URL=" "%envFile%"`) do set "SUPABASE_URL=%%b"
if not defined SUPABASE_ANON_KEY for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /i /c:"NEXT_PUBLIC_SUPABASE_ANON_KEY=" "%envFile%"`) do set "SUPABASE_ANON_KEY=%%b"

if defined DEV_CUSTOMER_EMAIL set "DEV_CUSTOMER_EMAIL=%DEV_CUSTOMER_EMAIL:"=%"
if defined DEV_CUSTOMER_EMAIL set "DEV_CUSTOMER_EMAIL=%DEV_CUSTOMER_EMAIL:'=%"
if defined DEV_CUSTOMER_PASSWORD set "DEV_CUSTOMER_PASSWORD=%DEV_CUSTOMER_PASSWORD:"=%"
if defined DEV_CUSTOMER_PASSWORD set "DEV_CUSTOMER_PASSWORD=%DEV_CUSTOMER_PASSWORD:'=%"
if defined DEV_OWNER_EMAIL set "DEV_OWNER_EMAIL=%DEV_OWNER_EMAIL:"=%"
if defined DEV_OWNER_EMAIL set "DEV_OWNER_EMAIL=%DEV_OWNER_EMAIL:'=%"
if defined DEV_OWNER_PASSWORD set "DEV_OWNER_PASSWORD=%DEV_OWNER_PASSWORD:"=%"
if defined DEV_OWNER_PASSWORD set "DEV_OWNER_PASSWORD=%DEV_OWNER_PASSWORD:'=%"
if defined DEV_ADMIN_EMAIL set "DEV_ADMIN_EMAIL=%DEV_ADMIN_EMAIL:"=%"
if defined DEV_ADMIN_EMAIL set "DEV_ADMIN_EMAIL=%DEV_ADMIN_EMAIL:'=%"
if defined DEV_ADMIN_PASSWORD set "DEV_ADMIN_PASSWORD=%DEV_ADMIN_PASSWORD:"=%"
if defined DEV_ADMIN_PASSWORD set "DEV_ADMIN_PASSWORD=%DEV_ADMIN_PASSWORD:'=%"
if defined APP_ENV set "APP_ENV=%APP_ENV:"=%"
if defined APP_ENV set "APP_ENV=%APP_ENV:'=%"
if defined SUPABASE_URL set "SUPABASE_URL=%SUPABASE_URL:"=%"
if defined SUPABASE_URL set "SUPABASE_URL=%SUPABASE_URL:'=%"
if defined SUPABASE_ANON_KEY set "SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY:"=%"
if defined SUPABASE_ANON_KEY set "SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY:'=%"
if defined RAZORPAY_KEY_ID set "RAZORPAY_KEY_ID=%RAZORPAY_KEY_ID:"=%"
if defined RAZORPAY_KEY_ID set "RAZORPAY_KEY_ID=%RAZORPAY_KEY_ID:'=%"

set "missing="
if "%DEV_CUSTOMER_EMAIL%"=="" set "missing=%missing% DEV_CUSTOMER_EMAIL"
if "%DEV_CUSTOMER_PASSWORD%"=="" set "missing=%missing% DEV_CUSTOMER_PASSWORD"
if "%DEV_OWNER_EMAIL%"=="" set "missing=%missing% DEV_OWNER_EMAIL"
if "%DEV_OWNER_PASSWORD%"=="" set "missing=%missing% DEV_OWNER_PASSWORD"
if "%DEV_ADMIN_EMAIL%"=="" set "missing=%missing% DEV_ADMIN_EMAIL"
if "%DEV_ADMIN_PASSWORD%"=="" set "missing=%missing% DEV_ADMIN_PASSWORD"
if "%SUPABASE_URL%"=="" set "missing=%missing% SUPABASE_URL"
if "%SUPABASE_ANON_KEY%"=="" set "missing=%missing% SUPABASE_ANON_KEY"

if not "%missing%"=="" (
    echo [ERROR] Test-mode configuration is missing in %envFile%.
    echo Missing:%missing%
    echo.
    echo TEST MODE requires real Supabase configuration plus test login credentials.
    echo Add these lines to %envFile% and re-run:
    echo   SUPABASE_URL=https://YOUR_PROJECT.supabase.co
    echo   SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
    echo   DEV_CUSTOMER_EMAIL=you@example.com
    echo   DEV_CUSTOMER_PASSWORD=secret
    echo   DEV_OWNER_EMAIL=owner@example.com
    echo   DEV_OWNER_PASSWORD=secret
    echo   DEV_ADMIN_EMAIL=admin@example.com
    echo   DEV_ADMIN_PASSWORD=secret
    echo.
    echo NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY are also accepted.
    echo Values are read locally and passed via --dart-define only.
    echo %envFile% is gitignored and must never be committed.
    exit /b 1
)

findstr /b /i "DEV_" "%envFile%" | findstr "!" >nul 2>nul
if not errorlevel 1 (
    echo [WARNING] DEV_* values containing ^! are not supported by cmd.
    echo   Remove ^! from DEV_* values in %envFile% before launching.
)

where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Flutter is not on PATH. Install Flutter and re-run.
    exit /b 1
)

echo [TEST MODE] Launching %appName% on Chrome with test login credentials.
echo   Roles: customer / owner / admin
echo   Defines: DEV_CUSTOMER_EMAIL, DEV_CUSTOMER_PASSWORD, DEV_OWNER_EMAIL, DEV_OWNER_PASSWORD, DEV_ADMIN_EMAIL, DEV_ADMIN_PASSWORD

flutter run -d chrome "--dart-define=DEV_CUSTOMER_EMAIL=%DEV_CUSTOMER_EMAIL%" "--dart-define=DEV_CUSTOMER_PASSWORD=%DEV_CUSTOMER_PASSWORD%" "--dart-define=DEV_OWNER_EMAIL=%DEV_OWNER_EMAIL%" "--dart-define=DEV_OWNER_PASSWORD=%DEV_OWNER_PASSWORD%" "--dart-define=DEV_ADMIN_EMAIL=%DEV_ADMIN_EMAIL%" "--dart-define=DEV_ADMIN_PASSWORD=%DEV_ADMIN_PASSWORD%" "--dart-define=APP_ENV=%APP_ENV%" "--dart-define=SUPABASE_URL=%SUPABASE_URL%" "--dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%" "--dart-define=RAZORPAY_KEY_ID=%RAZORPAY_KEY_ID%"

exit /b %errorlevel%
