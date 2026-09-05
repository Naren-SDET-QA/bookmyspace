# Real-concurrency race runner for Phase 16.7A backend-gaps verification.
# Requires: local Supabase stack already running (supabase start / db reset
# already applied, including this phase's migrations), and psql on PATH.
#
# Run from the repo root:  .\supabase\tests\dev_verification_phase16_7a\06_run_concurrency_races.ps1
#
# FIX (2026-08-28): this script used to launch straight into
# 05a_race_setup.sql, which does not create the base fixture rows
# (users/venue/slot) - it only assumes 00_fixture_setup.sql already ran
# in the same database. Against a freshly-reset DB that left a2/venue
# c1/slot d1 missing, and because the setup step ran with
# ON_ERROR_STOP=0, that failure was silently swallowed and the race
# sessions ran against a booking that was never created. Fixed here by
# (a) always running 00_fixture_setup.sql immediately before
# 05a_race_setup.sql, (b) ON_ERROR_STOP=1 on every setup step, and
# (c) explicitly checking psql's exit code after each setup step and
# aborting the whole run with a clear message if either fails, instead
# of continuing into an invalid race. No application code changed -
# fixture/setup ordering only.

$ErrorActionPreference = "Stop"
$env:PGPASSWORD = "postgres"
$dir = "supabase/tests/dev_verification_phase16_7a"
$pgArgs = @("-h","127.0.0.1","-p","54322","-U","postgres","-d","postgres","-v","ON_ERROR_STOP=1")

function Invoke-Setup($file) {
    & psql @pgArgs -f $file
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ABORTED: setup step failed ($file, psql exit code $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "Race results would be invalid if the suite continued past a failed setup step - stopping here." -ForegroundColor Red
        exit 1
    }
}

Write-Host "--- base fixture (users, venue, slot, org) ---"
Invoke-Setup "$dir/00_fixture_setup.sql"

Write-Host "`n--- race setup (contested slot + pending_owner_approval booking, with existence assertions) ---"
Invoke-Setup "$dir/05a_race_setup.sql"

Write-Host "`n--- Race A: two concurrent acquire_booking_hold calls for the same slot ---"
$outA1 = "$env:TEMP\race_a1_out.txt"; $errA1 = "$env:TEMP\race_a1_err.txt"
$outA2 = "$env:TEMP\race_a2_out.txt"; $errA2 = "$env:TEMP\race_a2_err.txt"
$pA1 = Start-Process -FilePath psql -ArgumentList ($pgArgs + @("-f", "$dir/05b_race_hold_session1.sql")) -RedirectStandardOutput $outA1 -RedirectStandardError $errA1 -PassThru -NoNewWindow
$pA2 = Start-Process -FilePath psql -ArgumentList ($pgArgs + @("-f", "$dir/05b_race_hold_session2.sql")) -RedirectStandardOutput $outA2 -RedirectStandardError $errA2 -PassThru -NoNewWindow
$pA1.WaitForExit(); $pA2.WaitForExit()
Write-Host "session 1:"; Get-Content $outA1, $errA1
Write-Host "session 2:"; Get-Content $outA2, $errA2

Write-Host "`n--- Race B: two concurrent owner_decide_booking('approve') calls for the same booking ---"
$outB1 = "$env:TEMP\race_b1_out.txt"; $errB1 = "$env:TEMP\race_b1_err.txt"
$outB2 = "$env:TEMP\race_b2_out.txt"; $errB2 = "$env:TEMP\race_b2_err.txt"
$pB1 = Start-Process -FilePath psql -ArgumentList ($pgArgs + @("-f", "$dir/05c_race_approve_session1.sql")) -RedirectStandardOutput $outB1 -RedirectStandardError $errB1 -PassThru -NoNewWindow
$pB2 = Start-Process -FilePath psql -ArgumentList ($pgArgs + @("-f", "$dir/05c_race_approve_session2.sql")) -RedirectStandardOutput $outB2 -RedirectStandardError $errB2 -PassThru -NoNewWindow
$pB1.WaitForExit(); $pB2.WaitForExit()
Write-Host "session 1:"; Get-Content $outB1, $errB1
Write-Host "session 2:"; Get-Content $outB2, $errB2

Write-Host "`n--- assertions (C1 / C2) ---"
& psql @pgArgs -f "$dir/05d_race_check.sql"
