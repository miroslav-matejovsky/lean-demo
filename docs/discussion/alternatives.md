# Alternatives and prior art

Lean is not the only way to do this, and not always the best one. Opinions
below are meant to be argued with.

## Industrial precedent: AWS Cedar

The closest real-world match to this repo is [Cedar](https://www.cedarpolicy.com/),
AWS's authorization policy language:

- the semantics are specified in **Lean** and key properties are proven,
- the production engine is written in **Rust**,
- **differential random testing** runs millions of generated inputs through
  both and compares the answers.

That is the "Lean truth + conformance" pattern at production scale. Recommended
reading: *How We Built Cedar: A Verification-Guided Approach* (FSE 2024).

## Comparison

| Tool | You write | Proves things about | Link to production code | Sweet spot |
|---|---|---|---|---|
| **Lean 4** (this repo) | functional spec + proofs | the spec (any property) | vectors, differential testing | domain rules, state machines, CRDTs, codecs |
| **TLA+ / PlusCal** | a system as a state machine | protocols (model checking, TLAPS proofs) | trace validation, manual | leases, failover, split-brain, consensus |
| **P language** | communicating state machines | protocol behaviour (systematic testing) | runtime monitors | message-driven services (used at AWS) |
| **Quint** | TLA+ semantics, typed syntax | protocols | model-based testing | TLA+ ideas for developers |
| **Dafny** | code + pre/postconditions | the code itself | compiles to **C#, Go**, Java, JS, Python | a verified core library in a .NET/Go shop |
| **CUE** | constraints on data | data validity (unification, not proofs) | validates config and messages | deployment descriptors, configuration, schemas |
| **Alloy** | relational model | structural constraints (bounded) | none (design time) | data models, access rules |
| **Verus / Kani / Aeneas** | Rust + specs | the Rust code | it *is* the code | verified Rust components |
| **Property-based testing** | properties in the production language | nothing (samples) | it *is* the code | cheap first step, no new language |

## Pairings that make sense for this domain

**Lean for behaviour, TLA+ for protocols.**
The alarm lifecycle and the health view are pure functions over messages: Lean
is a good fit. Primary/standby ownership with leases and partitions is a
concurrent protocol with timing: TLA+ explores interleavings that nobody writes
tests for.

**Lean for behaviour, CUE for shape and configuration.**
CUE is excellent for "is this deployment descriptor valid", with good tooling
and a gentle learning curve. Its values form a lattice and unification is a
meet, which is the same algebra as the health view's join. CUE does not prove
anything about behaviour over time. Lean does. A realistic setup could generate
CUE schemas from the Lean spec (another export target).

**Lean for the truth, Dafny for one critical library.**

!!! question "Challenge: should the implementations be Dafny?"
    Dafny compiles verified code to C# and Go. That closes the
    [refinement gap](limits.md#1-the-refinement-gap-the-biggest-caveat) for the
    core logic. Why Lean then?

    - Lean is a more expressive *specification* language (dependent types,
      mathematics, metaprogramming for code generation).
    - The Lean spec is *independent* of any implementation. Teams keep their
      idioms. Generated Dafny C# is not idiomatic and is usually wrapped.
    - Momentum: Mathlib, Cedar, AI-for-math tooling.

    A plausible hybrid: Lean for the enterprise truth, Dafny for one or two
    shared libraries that must be correct (for example an AIS decoder), TLA+ for
    cross-site protocols.

## When not to do any of this

- CRUD with little logic. OpenAPI plus contract tests are enough.
- Rules owned by the business that change weekly. A rules engine fits better.
- Nobody will own the proofs long term.
