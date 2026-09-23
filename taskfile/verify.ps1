<#
.SYNOPSIS
  The full "is the code aligned with the truth?" pipeline - the same gate CI runs.

.DESCRIPTION
  1. proofs    : lake build type-checks the spec and every theorem
  2. audit     : no sorry, only standard axioms
  3. drift     : committed contracts/code/docs equal what the spec generates
  4. dotnet    : .NET implementation replays all vectors
  5. go        : Go implementation replays all vectors
  6. mutation  : (optional, -Mutation) injected bugs are detected
#>
param(
    [switch]$Mutation
)
. "$PSScriptRoot/_common.ps1"

$stages = [ordered]@{
    'proofs + drift' = { & "$PSScriptRoot/contracts.ps1" -Mode check }
    'audit'          = { & "$PSScriptRoot/audit.ps1" }
    'dotnet'         = { & "$PSScriptRoot/test.ps1" -Impl dotnet }
    'go'             = { & "$PSScriptRoot/test.ps1" -Impl go }
}
if ($Mutation) { $stages['mutation'] = { & "$PSScriptRoot/mutate.ps1" } }

$summary = @()
$failed = $false
foreach ($name in $stages.Keys) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $ok = $true
    try {
        $global:LASTEXITCODE = 0
        & $stages[$name]
        if ($LASTEXITCODE -ne 0) { $ok = $false }
    }
    catch {
        Write-Fail $_
        $ok = $false
    }
    $summary += [pscustomobject]@{ Stage = $name; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
    if (-not $ok) { $failed = $true; break }
}

Write-Host "`n=== verification summary ==="
$summary | Format-Table -AutoSize | Out-String | Write-Host
if ($failed) {
    Write-Fail 'code is NOT aligned with the truth'
    exit 1
}
Write-Ok 'spec proven, artifacts in sync, all implementations conform'
