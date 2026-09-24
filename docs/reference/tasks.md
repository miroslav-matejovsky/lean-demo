# Tasks

Defined in `Taskfile.yml`. Logic lives in PowerShell 7 scripts in `taskfile/`.

| Task | What it does |
|---|---|
| `task` | list tasks |
| `task doctor` | check tools, print versions |
| `task tools` | install gotestsum and golangci-lint |
| `task lean` | type-check the tutorial and the specs (all proofs) |
| `task audit` | reject `sorry`, `axiom`, `native_decide`; print axioms of key theorems |
| `task contracts` | build and export vectors, manifests, C#, Go and reference pages |
| `task drift` | regenerate, then `git diff --exit-code` on generated paths |
| `task go:vet` | `go vet` |
| `task go:lint` | golangci-lint, including `exhaustive` over spec enums |
| `task go:test` | Go conformance tests, log in `.test-results/` |
| `task dotnet:test` | .NET conformance tests, log in `.test-results/` |
| `task mutate` | mutation testing (`task mutate IMPL=go`) |
| `task fast` | clean, drift, vet, Go and .NET tests |
| `task all` | fast + audit + lint + mutate. **Run before calling work done.** |
| `task docs` | live docs at <http://localhost:8000> |
| `task docs:build` | static site in `site/` |
| `task clean` | remove build outputs (`task clean -- -Lean` also drops `lean/.lake`) |

Direct Lean commands, from `lean/`:

```powershell
lake build                          # everything
lake build Tutorial.Nmea            # one module
lake env lean Tutorial/Nmea.lean    # check one file, print #eval output
lake exe truth export ..            # regenerate artifacts
lake exe truth version              # spec versions
```
