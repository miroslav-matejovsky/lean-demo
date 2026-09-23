# Check that required tools are installed and print their versions.
. (Join-Path $PSScriptRoot "common.ps1")

$tools = @(
    @{ Name = "elan"; Args = @("--version"); Hint = "https://lean-lang.org/install (scoop install elan)" }
    @{ Name = "lake"; Args = @("--version"); Hint = "installed by elan" }
    @{ Name = "dotnet"; Args = @("--version"); Hint = "https://dot.net (SDK 10+)" }
    @{ Name = "go"; Args = @("version"); Hint = "https://go.dev/dl (1.27+)" }
    @{ Name = "gotestsum"; Args = @("--version"); Hint = "task tools" }
    @{ Name = "golangci-lint"; Args = @("--version"); Hint = "task tools" }
    @{ Name = "task"; Args = @("--version"); Hint = "https://taskfile.dev/installation" }
    @{ Name = "uv"; Args = @("--version"); Hint = "https://docs.astral.sh/uv (runs zensical)" }
    @{ Name = "git"; Args = @("--version"); Hint = "https://git-scm.com" }
)

$missing = 0
# Run inside lean/ so elan resolves the pinned toolchain, not the global default.
Push-Location $LeanDir
try {
    foreach ($t in $tools) {
        if (Test-Tool $t.Name) {
            $v = & $t.Name @($t.Args) 2>&1 | Select-Object -First 1
            Write-Host ("  {0,-14} {1}" -f $t.Name, $v)
        }
        else {
            Write-Host ("  {0,-14} MISSING -> {1}" -f $t.Name, $t.Hint) -ForegroundColor Red
            $missing++
        }
    }
}
finally {
    Pop-Location
}

Write-Host "  lean toolchain pinned: $((Get-Content (Join-Path $LeanDir 'lean-toolchain')).Trim())"
if ($missing -gt 0) {
    throw "$missing tool(s) missing"
}
Write-Host "doctor done"
