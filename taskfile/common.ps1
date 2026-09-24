# Shared paths and helpers. Dot-source from every script: . (Join-Path $PSScriptRoot "common.ps1")
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$LeanDir = Join-Path $RepoRoot "lean"
$GoDir = Join-Path $RepoRoot "impl/go"
$DotnetDir = Join-Path $RepoRoot "impl/dotnet"
$ContractsDir = Join-Path $RepoRoot "contracts"
$TestResultsDir = Join-Path $RepoRoot ".test-results"

# Run a native command in a directory. Throw with context when it fails.
function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$Command,
        [string[]]$Arguments = @()
    )
    Push-Location $Dir
    try {
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "'$Command $($Arguments -join ' ')' failed with exit code $LASTEXITCODE (in $Dir)"
        }
    }
    finally {
        Pop-Location
    }
}

function Test-Tool([string]$Name) {
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Path for a timestamped log file in .test-results/.
function New-TestLog([string]$Prefix) {
    if (-not (Test-Path $TestResultsDir)) {
        New-Item -ItemType Directory -Path $TestResultsDir | Out-Null
    }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Join-Path $TestResultsDir "$Prefix-$stamp.log"
}
