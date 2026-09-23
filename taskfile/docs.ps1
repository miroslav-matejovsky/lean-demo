<#
.SYNOPSIS
  Build or serve the documentation site with Zensical (run through uv, no global install needed).
#>
param(
    [ValidateSet('build', 'serve')][string]$Mode = 'build'
)
. "$PSScriptRoot/_common.ps1"

if (-not (Test-Tool 'uv')) { throw 'uv is required: https://docs.astral.sh/uv' }

# docs/requirements.txt pins the version, shared with the GitHub Pages workflow.
$requirements = Join-Path $RepoRoot 'docs/requirements.txt'
$zensical = @('tool', 'run', '--with-requirements', $requirements, 'zensical')

if ($Mode -eq 'serve') {
    Write-Step 'Serving docs on http://localhost:8000 (Ctrl+C to stop)'
    Invoke-Native $RepoRoot uv ($zensical + @('serve'))
}
else {
    Write-Step 'Building docs into site/'
    Invoke-Native $RepoRoot uv ($zensical + @('build', '--clean'))
    Write-Ok "site built: $(Join-Path $RepoRoot 'site/index.html')"
}
