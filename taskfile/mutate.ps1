# Mutation testing: are the spec-derived vectors strong enough to catch real bugs?
#
# Each mutant is one small, realistic bug. The implementation is copied to a
# temp folder, the bug is injected, and the conformance tests run against the
# committed contracts. A mutant must be KILLED (tests fail). A SURVIVED mutant
# is a blind spot in the vector generator (lean/Truth/Export). The working tree
# is never modified.
param(
    [ValidateSet("all", "dotnet", "go")][string]$Impl = "all"
)
. (Join-Path $PSScriptRoot "common.ps1")

$mutants = @(
    # --- Go: zone -------------------------------------------------------------
    @{ Impl = "go"; File = "zone/track.go"; Name = "silent clear: unacknowledged alarm returns to normal"
       From = "t.Alarm = AlarmUnackCleared"; To = "t.Alarm = AlarmNormal" }
    @{ Impl = "go"; File = "zone/track.go"; Name = "duplicate AIS report accepted"
       From = "r.TS <= t.LastTS"; To = "r.TS < t.LastTS" }
    @{ Impl = "go"; File = "zone/track.go"; Name = "zone boundary excluded"
       From = "ZoneLatMin <= lat"; To = "ZoneLatMin < lat" }
    @{ Impl = "go"; File = "zone/track.go"; Name = "track lost one second late"
       From = "ev.Now >= t.LastTS+StaleAfter"; To = "ev.Now > t.LastTS+StaleAfter" }
    @{ Impl = "go"; File = "zone/track.go"; Name = "going dark clears the alarm"
       From = "t.Lost = true"; To = "t.Lost, t.Alarm = true, AlarmNormal" }
    @{ Impl = "go"; File = "zone/track.go"; Name = "permit ignored"
       From = "return t.Inside && !t.Authorized"; To = "return t.Inside" }
    @{ Impl = "go"; File = "zone/track.go"; Name = "longitude not-available marker treated as invalid"
       From = "r.Lat == LatNotAvailable || r.Lon == LonNotAvailable"; To = "r.Lat == LatNotAvailable" }
    # --- Go: health -----------------------------------------------------------
    @{ Impl = "go"; File = "health/view.go"; Name = "tie prefers the better report"
       From = "return ha < hb"; To = "return ha > hb" }
    @{ Impl = "go"; File = "health/view.go"; Name = "freshness off by one"
       From = "now > e.Report.TS+FreshFor"; To = "now >= e.Report.TS+FreshFor" }
    @{ Impl = "go"; File = "health/view.go"; Name = "last arrival wins (not a CRDT)"
       From = "case less(a.Report, b.Report):"; To = "case b.Present:" }
    # --- .NET: zone -----------------------------------------------------------
    @{ Impl = "dotnet"; File = "src/Surveillance/Zone/Track.cs"; Name = "silent clear: unacknowledged alarm returns to normal"
       From = "(AlarmState.UnackActive, false) => AlarmState.UnackCleared"; To = "(AlarmState.UnackActive, false) => AlarmState.Normal" }
    @{ Impl = "dotnet"; File = "src/Surveillance/Zone/Track.cs"; Name = "duplicate AIS report accepted"
       From = "r.Ts <= LastTs"; To = "r.Ts < LastTs" }
    @{ Impl = "dotnet"; File = "src/Surveillance/Zone/Track.cs"; Name = "re-entry does not re-activate"
       From = "(AlarmState.Normal or AlarmState.UnackCleared, true)"; To = "(AlarmState.Normal, true)" }
    # --- .NET: health ---------------------------------------------------------
    @{ Impl = "dotnet"; File = "src/Surveillance/Health/SiteView.cs"; Name = "older report wins"
       From = "if (a.Ts != b.Ts) return a.Ts < b.Ts;"; To = "if (a.Ts != b.Ts) return a.Ts > b.Ts;" }
    @{ Impl = "dotnet"; File = "src/Surveillance/Health/SiteView.cs"; Name = "freshness uses probe interval only"
       From = "now > r.Ts + Policy.FreshFor"; To = "now > r.Ts + Policy.ProbeInterval" }
    @{ Impl = "dotnet"; File = "src/Surveillance/Health/SiteView.cs"; Name = "observer tie-break reversed"
       From = "return Rank(a.Observer) < Rank(b.Observer);"; To = "return Rank(a.Observer) > Rank(b.Observer);" }
) | Where-Object { $Impl -eq "all" -or $_.Impl -eq $Impl }

$work = Join-Path ([IO.Path]::GetTempPath()) "truth-mutants-$PID"
$results = @()

Write-Host "mutate starting"
try {
    foreach ($m in $mutants) {
        $src = if ($m.Impl -eq "go") { $GoDir } else { $DotnetDir }
        $dst = Join-Path $work $m.Impl
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        New-Item -ItemType Directory -Force $dst | Out-Null
        Get-ChildItem $src -Force | Copy-Item -Destination $dst -Recurse -Force
        Get-ChildItem $dst -Recurse -Directory -Include bin, obj | Remove-Item -Recurse -Force

        $file = Join-Path $dst $m.File
        $text = Get-Content $file -Raw
        if (-not $text.Contains($m.From)) {
            throw "mutant '$($m.Name)': pattern not found in $($m.File), update mutate.ps1"
        }
        Set-Content $file ($text.Replace($m.From, $m.To)) -NoNewline

        Write-Host ("  [{0,-6}] {1,-55} " -f $m.Impl, $m.Name) -NoNewline
        $env:CONTRACTS_DIR = $ContractsDir
        Push-Location $dst
        try {
            # A mutant that does not compile proves nothing about the vectors.
            if ($m.Impl -eq "go") { go vet ./... *> $null } else { dotnet build --nologo --verbosity quiet *> $null }
            if ($LASTEXITCODE -ne 0) { throw "mutant '$($m.Name)' does not compile, fix mutate.ps1" }
            if ($m.Impl -eq "go") { go test ./... *> $null } else { dotnet test --no-build --nologo --verbosity quiet *> $null }
            $killed = $LASTEXITCODE -ne 0
        }
        finally {
            Pop-Location
            Remove-Item Env:CONTRACTS_DIR
        }
        if ($killed) { Write-Host "KILLED" -ForegroundColor Green } else { Write-Host "SURVIVED" -ForegroundColor Red }
        $results += [pscustomobject]@{ Impl = $m.Impl; Mutant = $m.Name; Killed = $killed }
    }
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

$survived = @($results | Where-Object { -not $_.Killed })
Write-Host "mutation score: $($results.Count - $survived.Count)/$($results.Count) killed"
if ($survived.Count -gt 0) {
    throw "some bugs were not detected: strengthen the generators in lean/Truth/Export"
}
Write-Host "mutate done"
# Killed mutants leave a non-zero $LASTEXITCODE behind.
exit 0
