# Build or serve the documentation with Zensical, run through uv (no global install).
# docs/requirements.txt pins the version, shared with the GitHub Pages workflow.
param(
    [ValidateSet("build", "serve")][string]$Mode = "build"
)
. (Join-Path $PSScriptRoot "common.ps1")

if (-not (Test-Tool "uv")) { throw "uv is required: https://docs.astral.sh/uv" }
$requirements = Join-Path $RepoRoot "docs/requirements.txt"
$zensical = @("tool", "run", "--with-requirements", $requirements, "zensical")

if ($Mode -eq "serve") {
    Write-Host "serving docs on http://localhost:8000 (Ctrl+C to stop)"
    Invoke-Native $RepoRoot uv ($zensical + @("serve"))
}
else {
    Invoke-Native $RepoRoot uv ($zensical + @("build", "--clean"))
    Write-Host "docs done: $(Join-Path $RepoRoot 'site/index.html')"
}
