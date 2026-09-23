# Remove build outputs and test results.
# -Lean also removes lean/.lake (full proof rebuild next time).
param(
    [switch]$Lean
)
. (Join-Path $PSScriptRoot "common.ps1")

$paths = @($TestResultsDir, (Join-Path $RepoRoot "site"), (Join-Path $RepoRoot ".cache"))
$paths += Get-ChildItem $DotnetDir -Recurse -Directory -Include bin, obj | ForEach-Object FullName
if ($Lean) { $paths += Join-Path $LeanDir ".lake" }

foreach ($p in $paths) {
    if (Test-Path $p) {
        Write-Host "removing $p"
        Remove-Item $p -Recurse -Force
    }
}
if (Test-Tool "go") { Invoke-Native $GoDir go @("clean", "-testcache") }
