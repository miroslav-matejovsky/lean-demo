# Tasks

All tasks are defined in `taskfile.yml` and implemented as PowerShell 7 scripts
in `taskfile/`, so they behave the same on Windows, Linux (CI) and macOS.

| Task | Script | What it does |
|---|---|---|
| `task` | – | list tasks |
| `task doctor` | `doctor.ps1` | check tools, print versions |
| `task setup` | – | doctor + Lean build + NuGet restore + Go modules |
| `task lean:build` | – | type-check tutorial and spec (all proofs) |
| `task lean:audit` | `audit.ps1` | reject `sorry`/`axiom`, print axioms of key theorems |
| `task contracts` | `contracts.ps1` | build + export vectors, manifest, C#, Go, docs |
| `task contracts:check` | `contracts.ps1 -Mode check` | drift gate (regenerate, then `git diff --exit-code`) |
| `task test` | `test.ps1` | .NET + Go conformance |
| `task test:dotnet` / `test:go` | `test.ps1 -Impl …` | one implementation |
| `task mutate` | `mutate.ps1` | mutation testing (`task mutate IMPL=go`) |
| `task verify` | `verify.ps1` | proofs → drift → audit → .NET → Go (CI gate) |
| `task verify:full` | `verify.ps1 -Mutation` | … + mutation testing |
| `task docs` | `docs.ps1 -Mode serve` | live docs at <http://localhost:8000> |
| `task docs:build` | `docs.ps1 -Mode build` | static site into `site/` |
| `task clean` | `clean.ps1` | remove build outputs (`task clean -- -Lean` also drops `.lake`) |

Direct Lean commands (from `lean/`):

```powershell
lake build                       # everything
lake build Tutorial.Induction    # one module
lake exe truth export ..         # regenerate artifacts
lake exe truth version           # spec version
lake env lean Tutorial/Basics.lean   # check a single file, print #eval output
```
