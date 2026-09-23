<#
.SYNOPSIS
  Run the conformance suite of one or all implementations.
#>
param(
    [ValidateSet('all', 'dotnet', 'go')][string]$Impl = 'all'
)
. "$PSScriptRoot/_common.ps1"

if ($Impl -in 'all', 'dotnet') {
    Write-Step '.NET implementation vs. spec'
    Invoke-Native $DotnetDir dotnet @('test', '--nologo', '--verbosity', 'quiet')
    Write-Ok '.NET conforms'
}

if ($Impl -in 'all', 'go') {
    Write-Step 'Go implementation vs. spec'
    Invoke-Native $GoDir go @('vet', './...')
    Invoke-Native $GoDir go @('test', './...')
    Write-Ok 'Go conforms'
}
