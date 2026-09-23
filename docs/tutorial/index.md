# Part 1 · Learning Lean

Lean 4 is both a **programming language** and a **proof assistant**. The same
file can contain a function, a claim about that function, and a proof of the
claim. The compiler refuses to build unless every proof is correct.

Three lessons, each a real file under `lean/Tutorial/`. They are embedded
below directly from the source, so what you read is exactly what CI compiles.

| Lesson | File | Key ideas |
|---|---|---|
| [Basics](basics.md) | `Basics.lean` | `rfl`, `decide`, propositions as types, `∧ ∨ → ¬ ∀ ∃`, automation |
| [Induction](induction.md) | `Induction.lean` | Gauss sum, our own ℕ, inductive predicates |
| [Spec vs. implementation](spec-vs-impl.md) | `SpecVsImpl.lean` | refinement, specs as properties, executable oracles |

!!! tip "How to study"
    Don't just read the files, step through them. Open them in VS Code, move the
    cursor line by line through each `by` block, and watch the goal change in the
    Infoview. Then delete a proof and try to rebuild it yourself.

## Vocabulary in two minutes

`theorem name : Statement := proof`
:   A claim and its evidence. Lean checks that `proof` has type `Statement`.

`Prop`
:   The type of statements. `2 + 2 = 4 : Prop`. A *proof* of `p : Prop` is a value of type `p`.

Tactic (`by …`)
:   A script that builds the proof term for you, step by step: `intro`, `simp`,
    `omega`, `induction`, `cases`, `exact`, `grind`…

`#eval`
:   Runs code. Specs in this repo are *executable*, which is the whole trick of Part 2.

Kernel
:   A small trusted checker. Tactics can be as clever as they like, because the
    kernel re-checks the final proof term. This is why `task lean:audit` only
    needs to ask *which axioms* were used.

## Further reading

- [Theorem Proving in Lean 4](https://lean-lang.org/theorem_proving_in_lean4/)
- [Functional Programming in Lean](https://lean-lang.org/functional_programming_in_lean/)
- [Mathematics in Lean](https://leanprover-community.github.io/mathematics_in_lean/) (uses Mathlib)
- [The Natural Number Game](https://adam.math.hhu.de/#/g/leanprover-community/nng4), a playful introduction to induction
