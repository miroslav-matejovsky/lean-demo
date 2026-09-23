<#
.SYNOPSIS
  Check that every tool the repo needs is installed, and print versions.
#>
. "$PSScriptRoot/_common.ps1"

$tools = @(
    @{ Name = 'elan';   Args = @('--version'); Hint = 'https://lean-lang.org/install (or: scoop install elan)' }
    @{ Name = 'lake';   Args = @('--version'); Hint = 'installed by elan' }
    @{ Name = 'dotnet'; Args = @('--version'); Hint = 'https://dot.net (SDK 10+)' }
    @{ Name = 'go';     Args = @('version');   Hint = 'https://go.dev/dl (1.27+)' }
    @{ Name = 'task';   Args = @('--version'); Hint = 'https://taskfile.dev/installation' }
    @{ Name = 'uv';     Args = @('--version'); Hint = 'https://docs.astral.sh/uv (runs zensical for docs)' }
    @{ Name = 'git';    Args = @('--version'); Hint = 'https://git-scm.com' }
)

$missing = 0
# run inside lean/ so elan resolves the pinned toolchain instead of the global default
Push-Location $LeanDir
foreach ($t in $tools) {
    if (Test-Tool $t.Name) {
        $v = (& $t.Name @($t.Args) 2>&1 | Select-Object -First 1)
        Write-Host ('  {0,-8} {1}' -f $t.Name, $v) -ForegroundColor Green
    }
    else {
        Write-Host ('  {0,-8} MISSING  -> {1}' -f $t.Name, $t.Hint) -ForegroundColor Red
        $missing++
    }
}
Pop-Location

$toolchain = (Get-Content (Join-Path $LeanDir 'lean-toolchain')).Trim()
Write-Host "`n  Lean toolchain pinned by lean/lean-toolchain: $toolchain"

if ($missing -gt 0) {
    Write-Fail "$missing tool(s) missing"
    exit 1
}
Write-Ok 'all tools present'
