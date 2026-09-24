# 02 - Induction

Unit tests check examples. Induction covers **every** natural number, list or
tree with a finite argument:

1. prove the base case,
2. assume the claim for `n` (the *induction hypothesis*, `ih`), then prove it for `n + 1`.

The safety zone spec in Part 2 uses the same pattern with *messages* in place of
numbers. The claim holds for a new track, and every message preserves it, so
it holds for **every reachable track**, whatever arrives in whatever order.

```lean
--8<-- "lean/Tutorial/Induction.lean"
```

Things worth pausing on:

- **`gauss`** is stated as `2 * sumTo n = n * (n + 1)` to avoid division on
  `Nat`. Choosing a statement that is easy to prove is a real specification skill.
- **`MyNat`**: commutativity is not built in. It is *derived* from two helper
  lemmas. Proofs often need a stronger or auxiliary statement first.
- **`Even`** is an *inductive predicate*: a set defined by rules. `not_even_one`
  holds because **no rule can produce it**. Part 2 defines `Reachable` tracks the
  same way.

!!! question "Exercise"
    Define `sumOdd n = 1 + 3 + ... + (2n-1)` and prove `sumOdd n = n * n`.
