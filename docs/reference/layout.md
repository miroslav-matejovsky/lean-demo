# Repository layout

```text
lean-demo/
├── lean/                              Lean 4 project (lake)
│   ├── lean-toolchain                 pinned Lean version
│   ├── Tutorial/                      Part 1: Basics, Induction, SpecVsImpl, Nmea
│   ├── Truth/
│   │   ├── Zone/Spec.lean             safety zone: behaviour        <- architects
│   │   ├── Zone/Properties.lean       safety zone: theorems         <- architects
│   │   ├── Health/Spec.lean           site health view: behaviour   <- architects
│   │   ├── Health/Properties.lean     site health view: theorems    <- architects
│   │   └── Export/                    JSON, vectors, codegen, docs  <- platform team
│   └── Main.lean                      `truth` executable
├── contracts/                         GENERATED: zone/, health/ (manifest.json, vectors.json)
├── impl/
│   ├── go/                            Go module
│   │   ├── zone/                      Track + contract_gen.go (GENERATED) + conformance test
│   │   └── health/                    View + contract_gen.go (GENERATED) + conformance test
│   └── dotnet/                        .NET 10 solution
│       ├── src/Surveillance/          Zone/Track.cs, Health/SiteView.cs, */Generated (GENERATED)
│       └── tests/Surveillance.Conformance/
├── docs/                              this site (Zensical)
│   └── reference/zone-alarm.md, health-view.md   GENERATED
├── taskfile/                          PowerShell scripts behind every task
├── Taskfile.yml
├── AGENTS.md, CLAUDE.md               conventions for humans and agents
├── .todo                              known unfinished work
├── zensical.toml
└── .github/workflows/                 ci.yml (task all on Windows), docs.yml (GitHub Pages)
```

Everything marked GENERATED is committed on purpose: reviewers see behaviour
changes as data diffs, teams need no Lean toolchain, and `task drift`
guarantees it never diverges from the specs.
