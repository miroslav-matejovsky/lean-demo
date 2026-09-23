# Part 1 - Learning Lean

Lean 4 is both a **programming language** and a **proof assistant**. The same
file can contain a function, a claim about that function, and a proof of the
claim. The compiler refuses to build unless every proof is correct.

Four lessons, each a real file under `lean/Tutorial/`. They are embedded
directly from the source, so what you read is exactly what CI compiles.

| Lesson | File | Key ideas |
|---|---|---|
| [Basics](basics.md) | `Basics.lean` | `rfl`, `decide`, propositions as types, `∧ ∨ → ¬ ∀ ∃`, automation |
| [Induction](induction.md) | `Induction.lean` | Gauss sum, our own ℕ, inductive predicates |
| [Spec vs. implementation](spec-vs-impl.md) | `SpecVsImpl.lean` | refinement, specs as properties, executable oracles |
| [AIS on the wire](nmea.md) | `Nmea.lean` | NMEA checksum strengths and weaknesses, 6-bit armoring, decoding by `#guard` |

!!! tip "How to study"
    Do not only read the files. Open them in VS Code, move the cursor line by
    line through each `by` block, and watch the goal change in the Infoview.
    Then delete a proof and rebuild it yourself.

## Vocabulary in two minutes

`theorem name : Statement := proof`
:   A claim and its evidence. Lean checks that `proof` has type `Statement`.

`Prop`
:   The type of statements. `2 + 2 = 4 : Prop`. A *proof* of `p : Prop` is a value of type `p`.

Tactic (`by ...`)
:   A script that builds the proof term for you, step by step: `intro`, `simp`,
    `omega`, `induction`, `cases`, `exact`, `grind`, ...

`#eval`, `#guard`
:   Run code. `#guard` fails the build when its result is false. Specs in this
    repo are *executable*, which is the whole trick of Part 2.

Kernel
:   A small trusted checker. Tactics can be as clever as they like, because the
    kernel re-checks the final proof term. This is why `task audit` only needs
    to ask *which axioms* were used.

## Further reading

- [Theorem Proving in Lean 4](https://lean-lang.org/theorem_proving_in_lean4/)
- [Functional Programming in Lean](https://lean-lang.org/functional_programming_in_lean/)
- [Mathematics in Lean](https://leanprover-community.github.io/mathematics_in_lean/) (uses Mathlib, not needed here)
- [The Natural Number Game](https://adam.math.hhu.de/#/g/leanprover-community/nng4): induction as a game
