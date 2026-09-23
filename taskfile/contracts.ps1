<#
.SYNOPSIS
  Regenerate everything derived from the Lean spec, or check that it is up to date.

.DESCRIPTION
  generate : lake build (proofs are checked) + `truth export` + gofmt on generated Go.
  check    : generate, then fail if git sees any difference in the generated files.
             This is the "drift gate": the committed contracts must equal what the
             current spec produces.
#>
param(
    [ValidateSet('generate', 'check')][string]$Mode = 'generate'
)
. "$PSScriptRoot/_common.ps1"

$generated = @(
    'contracts',
    'impl/dotnet/src/Orders/Generated',
    'impl/go/orders/contract_gen.go',
    'docs/reference/order-state-machine.md'
)

Write-Step 'Building Lean project (type-checks every proof)'
Invoke-Native $LeanDir lake @('build')

Write-Step 'Exporting contracts, code and docs from the spec'
Invoke-Native $LeanDir lake @('exe', 'truth', 'export', $RepoRoot)

if (Test-Tool 'gofmt') {
    Invoke-Native $GoDir gofmt @('-w', 'orders/contract_gen.go')
}

if ($Mode -eq 'check') {
    Write-Step 'Checking for drift between spec and committed artifacts'
    Push-Location $RepoRoot
    try {
        # Untracked generated files count as drift too.
        $untracked = git ls-files --others --exclude-standard -- @generated
        git diff --exit-code --stat -- @generated
        $diffExit = $LASTEXITCODE
    }
    finally { Pop-Location }
    if ($diffExit -ne 0 -or $untracked) {
        if ($untracked) { Write-Host "untracked: $untracked" }
        Write-Fail 'Generated artifacts are out of date. Run `task contracts` and commit the result.'
        exit 1
    }
    Write-Ok 'Committed artifacts match the specification'
}
else {
    Write-Ok 'Artifacts regenerated'
}
