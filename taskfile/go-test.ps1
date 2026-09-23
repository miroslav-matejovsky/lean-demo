# Run Go conformance tests with gotestsum (falls back to go test), tee to .test-results/.
. (Join-Path $PSScriptRoot "common.ps1")

Write-Host "go-test starting"
$log = New-TestLog "go"
Write-Host "saving output to $log"
Push-Location $GoDir
try {
    if (Test-Tool "gotestsum") {
        gotestsum --format pkgname ./... 2>&1 | Tee-Object -FilePath $log
    }
    else {
        go test ./... 2>&1 | Tee-Object -FilePath $log
    }
    if ($LASTEXITCODE -ne 0) {
        throw "go tests failed (exit $LASTEXITCODE), see $log"
    }
}
finally {
    Pop-Location
}
Write-Host "go-test done"
