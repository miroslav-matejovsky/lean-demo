# Repository layout

```text
lean-demo/
├── lean/                          # Lean 4 project (lake)
│   ├── lean-toolchain             # pinned Lean version
│   ├── lakefile.toml
│   ├── Tutorial/                  # Part 1: learning Lean
│   │   ├── Basics.lean
│   │   ├── Induction.lean
│   │   └── SpecVsImpl.lean
│   ├── Truth/                     # Part 2: the architectural truth
│   │   ├── Order/Spec.lean        #   behaviour (step), types, policy   ← architects
│   │   ├── Order/Properties.lean  #   theorems                          ← architects
│   │   └── Export/                #   JSON, vectors, codegen, docs gen  ← platform team
│   └── Main.lean                  # `truth` executable
├── contracts/order/               # GENERATED: manifest.json, vectors.json
├── impl/
│   ├── dotnet/                    # .NET 10 solution (Orders + Orders.Conformance)
│   │   └── src/Orders/Generated/  #   GENERATED: Contract.g.cs
│   └── go/                        # Go module
│       └── orders/contract_gen.go #   GENERATED
├── docs/                          # this site (Zensical)
│   └── reference/order-state-machine.md   # GENERATED
├── taskfile/                      # PowerShell scripts behind every task
├── taskfile.yml
├── zensical.toml
└── .github/workflows/             # ci.yml (verify), docs.yml (GitHub Pages)
```

Everything marked **GENERATED** is committed on purpose. Reviewers see
behavioural changes as data diffs, teams need no Lean toolchain, and
`task contracts:check` guarantees it never drifts.
