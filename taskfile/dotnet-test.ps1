# Run .NET conformance tests at solution level, tee to .test-results/.
. (Join-Path $PSScriptRoot "common.ps1")

Write-Host "dotnet-test starting"
$log = New-TestLog "dotnet"
Write-Host "saving output to $log"
Push-Location $DotnetDir
try {
    dotnet test --nologo --verbosity quiet 2>&1 | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
        throw ".NET tests failed (exit $LASTEXITCODE), see $log"
    }
}
finally {
    Pop-Location
}
Write-Host "dotnet-test done"
