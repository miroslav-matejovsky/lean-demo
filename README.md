# Lean as Architectural Truth

[![all](https://github.com/miroslav-matejovsky/lean-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/miroslav-matejovsky/lean-demo/actions/workflows/ci.yml)
[![docs](https://github.com/miroslav-matejovsky/lean-demo/actions/workflows/docs.yml/badge.svg)](https://miroslav-matejovsky.github.io/lean-demo/)

Research and learning repo. Can an architect write the truth about a system
once, prove it, and have a process confirm that independent .NET and Go
services stay aligned with it?

1. **Learning Lean 4** (`lean/Tutorial`): basic proofs, induction, refinement,
   and proofs about AIS/NMEA checksums and 6-bit armoring.
2. **The truth** (`lean/Truth`): two executable, proven specs from maritime
   surveillance.
   - *Safety zone*: per-vessel alarm lifecycle fed by AIS reports. Proven: the
     alarm tells the truth, no silent clear, going dark keeps the alarm,
     duplicates are harmless. Also proven: a late intrusion report is missed.
   - *Site health view*: primary and standby replicas as a CRDT. Proven: same
     reports in any order with any duplicates give the same view.
3. **Conformance** (`impl/`): Go and .NET implementations replay vectors
   generated from the specs. Drift gate, trust-base audit, mutation testing.

Docs: <https://miroslav-matejovsky.github.io/lean-demo/> (or `task docs`).

## Commands

- `task all` runs the complete gate: proofs, drift, conformance, audit, lint, mutation testing.
- `task fast` runs proofs, drift, vet and conformance tests.
- `task contracts` regenerates everything derived from the specs.
- `task doctor` checks tools. `task tools` installs the Go tools.
- `task --list` shows all tasks.

Requires elan (Lean), .NET 10 SDK, Go 1.27+, Task, PowerShell 7, uv.
Conventions are in [AGENTS.md](AGENTS.md). Known unfinished work is in [.todo](.todo).
