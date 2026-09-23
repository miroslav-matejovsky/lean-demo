<#
.SYNOPSIS
  Audit the trust base of the specification.

.DESCRIPTION
  A proof is only as good as what it assumes. This script
    1. rejects `sorry` (an unfinished proof) and custom `axiom`s in lean/,
    2. prints the axioms each key theorem depends on via `#print axioms`,
       and fails if any theorem depends on `sorryAx`.
  The standard axioms (propext, Classical.choice, Quot.sound) are expected.
#>
. "$PSScriptRoot/_common.ps1"

$theorems = @(
    'Truth.Order.reachable_inv',
    'Truth.Order.no_unapproved_large_shipment',
    'Truth.Order.shipped_is_final',
    'Truth.Order.cancelled_is_final',
    'Truth.Order.can_always_cancel',
    'Truth.Order.draft_can_ship',
    'Truth.Order.total_fits_int64',
    'Truth.Order.replayState_reachable'
)

Write-Step 'Scanning Lean sources for sorry / axiom'
$hits = Get-ChildItem -Path (Join-Path $LeanDir 'Truth'), (Join-Path $LeanDir 'Tutorial') -Recurse -Filter *.lean |
    Select-String -Pattern '^\s*(axiom\s|.*\bsorry\b)' |
    Where-Object { $_.Line -notmatch '^\s*--' }
if ($hits) {
    $hits | ForEach-Object { Write-Host "  $($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
    Write-Fail 'Found sorry/axiom in sources'
    exit 1
}
Write-Ok 'no sorry / custom axioms'

Write-Step 'Axioms used by key theorems'
Invoke-Native $LeanDir lake @('build', 'Truth')
$probe = Join-Path ([IO.Path]::GetTempPath()) "truth-audit-$PID.lean"
$lines = @('import Truth') + ($theorems | ForEach-Object { "#print axioms $_" })
Set-Content -Path $probe -Value $lines -Encoding utf8
try {
    Push-Location $LeanDir
    $out = & lake env lean $probe 2>&1 | Out-String
    $exit = $LASTEXITCODE
}
finally {
    Pop-Location
    Remove-Item $probe -ErrorAction SilentlyContinue
}
Write-Host $out
if ($exit -ne 0 -or $out -match 'sorryAx') {
    Write-Fail 'A key theorem depends on sorry (or Lean failed)'
    exit 1
}
Write-Ok 'trust base: Lean kernel + standard axioms only'
