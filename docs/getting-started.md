# Getting started

## Prerequisites

| Tool | Why | Install |
|---|---|---|
| **elan** (Lean toolchain manager) | Builds proofs and runs the exporter | [lean-lang.org/install](https://lean-lang.org/install) or `scoop install elan` |
| **.NET SDK 10+** | .NET implementation | [dot.net](https://dot.net) |
| **Go 1.27+** | Go implementation | [go.dev/dl](https://go.dev/dl) |
| **Task** | Task runner (`taskfile.yml`) | [taskfile.dev](https://taskfile.dev/installation) |
| **PowerShell 7+** | All scripts under `taskfile/` | [aka.ms/powershell](https://aka.ms/powershell) |
| **uv** | Runs Zensical for the docs (no global install) | [docs.astral.sh/uv](https://docs.astral.sh/uv) |

The Lean version is pinned in `lean/lean-toolchain`. elan downloads it automatically
the first time you build. The project uses Lean core only (no Mathlib), so the
first build takes seconds, not the hours a Mathlib build can take.

```powershell
task doctor
task setup
```

## Editor

Use **VS Code** with the official *Lean 4* extension, and open the `lean/` folder
(or the repo root). Put your cursor in any `by` block to see the current proof
goal in the *Lean Infoview*. This interactive loop is how you learn Lean.

## First run

```powershell
task verify
```

Expected tail:

```text
=== verification summary ===

Stage          Result Seconds
-----          ------ -------
proofs + drift PASS      1.0
audit          PASS      1.2
dotnet         PASS      3.7
go             PASS      0.8

✔ spec proven, artifacts in sync, all implementations conform
```

## Break something (recommended)

The quickest way to understand the setup is to break each layer once.

=== "Break an implementation"

    In `impl/go/orders/order.go` change `o.Total() > ApprovalThreshold` to `>=`.

    ```powershell
    task test:go
    ```

    The vector *"total exactly at threshold is auto-approved"* fails, with a
    diff of spec vs. implementation. Revert.

=== "Break a business rule in the spec"

    In `lean/Truth/Order/Spec.lean`, let `ship` also work from `pendingApproval`:

    ```lean
    | .ship =>
      if o.status = .approved ∨ o.status = .pendingApproval then .ok { o with status := .shipped }
    ```

    ```powershell
    task lean:build
    ```

    **The build fails.** `step_preserves_inv` can no longer be proven, because
    a large order could now ship without approval. The theorem is the guardrail
    on the spec itself. Revert.

=== "Change the spec legitimately"

    Raise `approvalThreshold` to `2_000_000` and run:

    ```powershell
    task contracts:check   # fails: committed artifacts are stale
    task contracts         # regenerate
    task test              # still green? the implementations use the generated constant
    ```

    Then run `git diff`: vectors, `Contract.g.cs`, `contract_gen.go` and the
    state-machine page all changed together. This diff is what a spec-change PR
    looks like.
