# 01 - Basics

Build just this lesson:

```powershell
cd lean; lake build Tutorial.Basics
```

What to notice:

- `rfl` and `decide` prove facts **by computation**.
- Logical connectives are ordinary types. `A ∧ B` is a pair, `A ∨ B` is a
  tagged union, `A → B` is a function, `¬A` is `A → False`.
- The same theorem can be written as a *term* (a lambda) or with *tactics*.
- `omega`, `simp` and `grind` do the tedious work.

```lean
--8<-- "lean/Tutorial/Basics.lean"
```

!!! question "Exercise"
    Prove `A ∧ (B ∨ C) → (A ∧ B) ∨ (A ∧ C)` in `Basics.lean`. Try it as a term
    first, then with tactics (`intro`, `rcases`, `exact`), and finally check
    whether `grind` solves it alone.
