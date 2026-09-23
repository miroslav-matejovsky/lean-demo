# Alternatives & prior art

Lean isn't the only way to do this, and it may not be the best one for your
case. The comparison below is an opinion, meant for challenging discussion.

## Industrial precedent: AWS Cedar

The closest real-world match to this repo is
[Cedar](https://www.cedarpolicy.com/), AWS's authorization policy language:

- the **spec** of Cedar's semantics is written in **Lean** and its key properties are proven,
- the **production implementation** is in **Rust**,
- **differential random testing** runs millions of generated inputs through
  both and compares the answers.

This is exactly the "Lean truth + conformance" pattern here, at production scale.
Reading their paper ([*How We Built Cedar*](https://www.amazon.science/publications/how-we-built-cedar-a-verification-guided-approach), FSE 2024) is highly recommended.

## Comparison

| Tool | What you write | Proves things about | Links to prod code by | Sweet spot |
|---|---|---|---|---|
| **Lean 4** (this repo) | functional spec + proofs | the spec (any property) | vectors / differential testing | rich domain rules, policies, algorithms |
| **Dafny** | code + pre/postconditions | the code itself | **compiles to C#, Go, Java, JS, Python** | verified core libraries in .NET/Go shops |
| **TLA+ / PlusCal** | state machine of a *system* | protocols (model checking + TLAPS) | trace validation, manual | distributed protocols, concurrency |
| **P language** | communicating state machines | protocol behaviour (systematic testing) | runtime monitors, testing | services & message flows (used at AWS) |
| **Alloy** | relational model | structural constraints (bounded) | none (design-time) | data models, access control design |
| **Verus / Kani / Aeneas** | Rust + specs | the Rust code | it *is* the code (Aeneas: Rust → Lean) | verified Rust components |
| **Property-based testing** (FsCheck, rapid) | properties in the prod language | nothing (samples) | it *is* the code | cheap first step, no new language |
| **Quint** | TLA+-like, typed | protocols | model-based testing | TLA+ ideas with dev-friendly syntax |

!!! question "Challenge: shouldn't this repo use Dafny?"
    For a .NET and Go shop, **Dafny compiles verified code directly to C# and Go**.
    That closes the refinement gap described in [Limits](limits.md#1-the-refinement-gap-the-biggest-caveat)
    for the core logic. Why Lean, then?

    - Lean is a far more expressive *specification* language (dependent
      types, mathematics, metaprogramming for code generation).
    - Its community and momentum are larger (Mathlib, AI-for-math, Cedar, AWS, Microsoft).
    - The Lean spec is *independent* of any implementation, and teams keep their
      idioms. Dafny-generated C# isn't idiomatic, and teams usually wrap it.

    A plausible hybrid: **Lean for the enterprise truth and theorems, Dafny for
    one or two critical shared libraries, TLA+ for cross-service protocols.**

## When *not* to do any of this

- CRUD with little logic. OpenAPI plus contract tests are enough.
- Rules that change weekly and are owned by the business, where a rules engine
  or DMN fits better.
- There is nobody who will own the proofs long-term.
