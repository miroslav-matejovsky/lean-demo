# Getting started

## Prerequisites

| Tool | Why | Install |
|---|---|---|
| elan | Lean toolchain manager. Builds proofs, runs the exporter. | `scoop install elan` or [lean-lang.org/install](https://lean-lang.org/install) |
| .NET SDK 10+ | .NET implementation | [dot.net](https://dot.net) |
| Go 1.27+ | Go implementation | [go.dev/dl](https://go.dev/dl) |
| gotestsum, golangci-lint | Go test output and lint | `task tools` |
| Task | Task runner (`Taskfile.yml`) | [taskfile.dev](https://taskfile.dev/installation) |
| PowerShell 7+ | All scripts in `taskfile/` | [aka.ms/powershell](https://aka.ms/powershell) |
| uv | Runs Zensical for the docs, no global install | [docs.astral.sh/uv](https://docs.astral.sh/uv) |

The Lean version is pinned in `lean/lean-toolchain`. elan downloads it on the
first build. The project uses Lean core only, no Mathlib, so a full build of
all proofs takes seconds.

```powershell
task doctor
task tools
```

## Editor

VS Code with the *Lean 4* extension. Open a `.lean` file and put the cursor in
a `by` block. The *Lean Infoview* shows the current goal. This loop is how you
learn Lean.

## First run

```powershell
task all
```

Expected tail:

```text
audit done
0 issues.
go:lint done
mutate starting
  [go    ] silent clear: unacknowledged alarm returns to normal    KILLED
  ...
mutation score: 16/16 killed
mutate done
all done
```

`task fast` skips audit, lint and mutation testing.

## Break something

The quickest way to understand the setup is to break each layer once.

=== "Break an implementation"

    In `impl/go/zone/track.go`, make an unacknowledged alarm clear itself:
    change `t.Alarm = AlarmUnackCleared` to `t.Alarm = AlarmNormal`.

    ```powershell
    task go:test
    ```

    The scenario *"vessel leaves before acknowledgement: alarm waits for the
    operator"* fails, with spec and implementation side by side. Revert.

=== "Break a rule in the spec"

    In `lean/Truth/Zone/Spec.lean`, let a tick clear the alarm when the vessel
    goes dark:

    ```lean
    | .tick now =>
      if t.lastTs > 0 ∧ now ≥ t.lastTs + staleAfter then .ok { t with lost := true, alarm := .normal }
    ```

    ```powershell
    task lean
    ```

    **The build fails.** The invariant proof and `going_dark_keeps_alarm` no
    longer hold. The theorem is the guardrail on the spec itself. Revert.

=== "Change the spec legitimately"

    Raise `staleAfter` from `180` to `360` in `Spec.lean`.

    ```powershell
    task drift       # fails: committed artifacts are stale
    task contracts   # regenerate
    task fast        # implementations use the generated constant: still green
    git diff --stat
    ```

    Vectors, `Contract.g.cs`, `contract_gen.go` and the reference page changed
    together. That diff is what a spec change looks like in review.
