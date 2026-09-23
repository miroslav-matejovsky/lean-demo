<#
.SYNOPSIS
  Mutation testing: are the Lean-generated vectors strong enough to catch real bugs?

.DESCRIPTION
  Each mutant is a small, realistic bug (off-by-one at a boundary, a forgotten
  state, a wrong flag). The implementation is copied to a temp folder, the bug
  is injected, and the conformance suite is run. A mutant must be KILLED
  (tests fail). A SURVIVED mutant means the vectors have a blind spot.
  Your working tree is never modified.
#>
param(
    [ValidateSet('all', 'dotnet', 'go')][string]$Impl = 'all'
)
. "$PSScriptRoot/_common.ps1"

$mutants = @(
    # --- Go ---------------------------------------------------------------
    @{ Impl = 'go'; File = 'orders/order.go'; Name = 'threshold boundary >= instead of >'
       From = 'o.Total() > ApprovalThreshold'; To = 'o.Total() >= ApprovalThreshold' }
    @{ Impl = 'go'; File = 'orders/order.go'; Name = 'max quantity off by one'
       From = 'ev.Qty > MaxQty'; To = 'ev.Qty >= MaxQty' }
    @{ Impl = 'go'; File = 'orders/order.go'; Name = 'approval flag not recorded'
       From = 'n.Approved = true'; To = 'n.Approved = false' }
    @{ Impl = 'go'; File = 'orders/order.go'; Name = 'cancelled order can be cancelled again'
       From = 'o.Status == StatusShipped || o.Status == StatusCancelled'; To = 'o.Status == StatusShipped' }
    @{ Impl = 'go'; File = 'orders/order.go'; Name = 'line limit off by one'
       From = 'len(o.Lines) >= MaxLines'; To = 'len(o.Lines) > MaxLines' }
    @{ Impl = 'go'; File = 'orders/order.go'; Name = 'error precedence: price checked before qty'
       From = 'case ev.Qty <= 0 || ev.Qty > MaxQty:'; To = 'case ev.Qty <= 0 && ev.UnitPrice > 0 || ev.Qty > MaxQty:' }
    # --- .NET -------------------------------------------------------------
    @{ Impl = 'dotnet'; File = 'src/Orders/Order.cs'; Name = 'threshold boundary >= instead of >'
       From = 'Total > Policy.ApprovalThreshold'; To = 'Total >= Policy.ApprovalThreshold' }
    @{ Impl = 'dotnet'; File = 'src/Orders/Order.cs'; Name = 'approval flag not recorded'
       From = 'Approved = true'; To = 'Approved = false' }
    @{ Impl = 'dotnet'; File = 'src/Orders/Order.cs'; Name = 'reject cancels instead of returning to draft'
       From = 'Ok(this with { Status = OrderStatus.Draft })'; To = 'Ok(this with { Status = OrderStatus.Cancelled })' }
    @{ Impl = 'dotnet'; File = 'src/Orders/Order.cs'; Name = 'can ship directly from pending approval'
       From = 'OrderEvent.Ship => Status == OrderStatus.Approved'; To = 'OrderEvent.Ship => Status is OrderStatus.Approved or OrderStatus.PendingApproval' }
    @{ Impl = 'dotnet'; File = 'src/Orders/Order.cs'; Name = 'max price accepted one cent too high'
       From = 'a.UnitPrice > Policy.MaxUnitPrice'; To = 'a.UnitPrice > Policy.MaxUnitPrice + 1' }
) | Where-Object { $Impl -eq 'all' -or $_.Impl -eq $Impl }

$contracts = Join-Path $RepoRoot 'contracts'
$work = Join-Path ([IO.Path]::GetTempPath()) "truth-mutants-$PID"
$results = @()

try {
    foreach ($m in $mutants) {
        $src = if ($m.Impl -eq 'go') { $GoDir } else { $DotnetDir }
        $dst = Join-Path $work $m.Impl
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        New-Item -ItemType Directory -Force $dst | Out-Null
        # copy sources only (skip build output)
        Get-ChildItem $src -Force | Where-Object { $_.Name -notin 'bin', 'obj' } |
            Copy-Item -Destination $dst -Recurse -Force
        Get-ChildItem $dst -Recurse -Directory -Include bin, obj | Remove-Item -Recurse -Force

        $file = Join-Path $dst $m.File
        $text = Get-Content $file -Raw
        if (-not $text.Contains($m.From)) { throw "Mutant '$($m.Name)': pattern not found in $($m.File) - update mutate.ps1" }
        Set-Content $file ($text.Replace($m.From, $m.To)) -NoNewline

        Write-Host ("  [{0,-6}] {1,-48} " -f $m.Impl, $m.Name) -NoNewline
        $env:CONTRACTS_DIR = $contracts
        Push-Location $dst
        try {
            # a mutant that does not compile proves nothing about the vectors
            if ($m.Impl -eq 'go') { go vet ./... *> $null } else { dotnet build --nologo --verbosity quiet *> $null }
            if ($LASTEXITCODE -ne 0) { throw "Mutant '$($m.Name)' does not compile - fix mutate.ps1" }
            if ($m.Impl -eq 'go') { go test ./... *> $null }
            else { dotnet test --no-build --nologo --verbosity quiet *> $null }
            $killed = $LASTEXITCODE -ne 0
        }
        finally {
            Pop-Location
            Remove-Item Env:CONTRACTS_DIR
        }
        if ($killed) { Write-Host 'KILLED' -ForegroundColor Green }
        else { Write-Host 'SURVIVED' -ForegroundColor Red }
        $results += [pscustomobject]@{ Impl = $m.Impl; Mutant = $m.Name; Killed = $killed }
    }
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

$survived = @($results | Where-Object { -not $_.Killed })
$score = [math]::Round(100 * ($results.Count - $survived.Count) / [math]::Max(1, $results.Count))
Write-Host "`nMutation score: $score% ($($results.Count - $survived.Count)/$($results.Count) killed)"
if ($survived.Count -gt 0) {
    Write-Fail 'Some bugs were NOT detected by the conformance vectors - strengthen the generator in lean/Truth/Export/Vectors.lean'
    exit 1
}
Write-Ok 'every injected bug was caught by the spec-derived vectors'
exit 0 # killed mutants leave a non-zero $LASTEXITCODE behind
