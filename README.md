# Lean as Architectural Truth

[![verify](https://github.com/miroslav-matejovsky/lean-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/miroslav-matejovsky/lean-demo/actions/workflows/ci.yml)
[![docs](https://github.com/miroslav-matejovsky/lean-demo/actions/workflows/docs.yml/badge.svg)](https://miroslav-matejovsky.github.io/lean-demo/)

A research and learning repo. It covers:

1. **Learning Lean 4.** Basic mathematical proofs (`lean/Tutorial`).
2. **Lean as the enterprise "truth".** An executable, *proven* domain specification
   (`lean/Truth`). From it, test vectors, C#/Go contracts and docs are generated.
3. **Conformance.** Independent **.NET** and **Go** implementations (`impl/`) are
   continuously checked against the truth: proofs → drift gate → conformance →
   mutation testing.

📖 **Docs:** <https://miroslav-matejovsky.github.io/lean-demo/> (or `task docs` locally)

```powershell
task doctor        # tools present?
task verify        # proofs, audit, drift, .NET + Go conformance
task mutate        # inject bugs, watch the spec-derived vectors catch them
task docs          # docs on http://localhost:8000
```

Requires: elan (Lean), .NET 10 SDK, Go 1.27+, Task, PowerShell 7, uv.
See [docs/getting-started.md](docs/getting-started.md).
