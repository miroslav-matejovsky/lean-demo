# Shared helpers, dot-sourced by every script in this folder.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$LeanDir = Join-Path $RepoRoot 'lean'
$DotnetDir = Join-Path $RepoRoot 'impl/dotnet'
$GoDir = Join-Path $RepoRoot 'impl/go'

function Write-Step([string]$Message) {
    Write-Host "`n▶ $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "✔ $Message" -ForegroundColor Green
}

function Write-Fail([string]$Message) {
    Write-Host "✖ $Message" -ForegroundColor Red
}

# Run a native command in a directory; throw if it fails.
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
