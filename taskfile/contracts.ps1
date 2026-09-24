# Build the Lean project (checks every proof) and regenerate everything derived
# from the specs: contracts, C# and Go code, reference docs.
# -Check: afterwards fail if git sees any difference in the generated files.
# The committed artifacts must always equal what the current specs produce.
param(
    [switch]$Check
)
. (Join-Path $PSScriptRoot "common.ps1")

$generated = @(
    "contracts",
    "impl/dotnet/src/Surveillance/Zone/Generated",
    "impl/dotnet/src/Surveillance/Health/Generated",
    "impl/go/zone/contract_gen.go",
    "impl/go/health/contract_gen.go",
    "docs/reference/zone-alarm.md",
    "docs/reference/health-view.md"
)

Write-Host "contracts starting"
Invoke-Native $LeanDir lake @("build")
Invoke-Native $LeanDir lake @("exe", "truth", "export", $RepoRoot)
Invoke-Native $GoDir gofmt @("-l", "-w", "zone/contract_gen.go", "health/contract_gen.go")

if ($Check) {
    Push-Location $RepoRoot
    try {
        $untracked = git ls-files --others --exclude-standard -- @generated
        git diff --exit-code --stat -- @generated
        $diffExit = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    if ($diffExit -ne 0 -or $untracked) {
        if ($untracked) { Write-Host "untracked: $($untracked -join ', ')" }
        throw "generated artifacts differ from the specs: run 'task contracts' and commit the result"
    }
    Write-Host "no drift between specs and committed artifacts"
}
Write-Host "contracts done"
