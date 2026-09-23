# Audit the trust base of the specs. A proof is only as good as what it assumes.
#   1. Reject `sorry` (unfinished proof), custom `axiom` and `native_decide`
#      (trusts the compiler, not only the kernel) in lean/.
#   2. Print `#print axioms` for key theorems. Fail on sorryAx.
# The standard axioms propext, Classical.choice and Quot.sound are expected.
. (Join-Path $PSScriptRoot "common.ps1")

$theorems = @(
    "Truth.Zone.reachable_inv",
    "Truth.Zone.intrusion_always_alarms",
    "Truth.Zone.no_silent_clear",
    "Truth.Zone.going_dark_keeps_alarm",
    "Truth.Zone.duplicate_report_rejected",
    "Truth.Zone.late_intrusion_missed",
    "Truth.Health.convergence",
    "Truth.Health.merge_deliver",
    "Truth.Health.tie_prefers_worse",
    "Truth.Health.stale_is_unknown",
    "Tutorial.Nmea.detects_single_change",
    "Tutorial.Nmea.misses_transposition",
    "Tutorial.Nmea.unarmor_armor"
)

Write-Host "audit starting"
$sources = Get-ChildItem -Path (Join-Path $LeanDir "Truth"), (Join-Path $LeanDir "Tutorial") -Recurse -Filter *.lean
$hits = $sources |
    Select-String -Pattern '^\s*axiom\s|\bsorry\b|\bnative_decide\b' |
    Where-Object { $_.Line -notmatch '^\s*--' }
if ($hits) {
    $hits | ForEach-Object { Write-Host "  $($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
    throw "found sorry, axiom or native_decide in Lean sources"
}

Invoke-Native $LeanDir lake @("build", "Truth", "Tutorial")
$probe = Join-Path ([IO.Path]::GetTempPath()) "truth-audit-$PID.lean"
$lines = @("import Truth", "import Tutorial") + ($theorems | ForEach-Object { "#print axioms $_" })
Set-Content -Path $probe -Encoding utf8 -Value $lines
try {
    Push-Location $LeanDir
    $out = & lake env lean $probe 2>&1 | Out-String
    $exit = $LASTEXITCODE
}
finally {
    Pop-Location
    Remove-Item $probe -ErrorAction SilentlyContinue
}
Write-Host $out.Trim()
if ($exit -ne 0 -or $out -match "sorryAx") {
    throw "a key theorem depends on sorry, or Lean failed"
}
Write-Host "audit done"
