<#
.SYNOPSIS
  Remove build outputs (Lean .lake, .NET bin/obj, Go test cache, docs site).
#>
param(
    [switch]$Lean # also remove lean/.lake (full proof rebuild next time)
)
. "$PSScriptRoot/_common.ps1"

$paths = @(
    (Join-Path $RepoRoot 'site'),
    (Join-Path $RepoRoot '.cache')
)
$paths += Get-ChildItem $DotnetDir -Recurse -Directory -Include bin, obj | ForEach-Object FullName
if ($Lean) { $paths += Join-Path $LeanDir '.lake' }

foreach ($p in $paths) {
    if (Test-Path $p) {
        Remove-Item $p -Recurse -Force
        Write-Host "  removed $p"
    }
}
if (Test-Tool 'go') { Invoke-Native $GoDir go @('clean', '-testcache') }
Write-Ok 'clean'
