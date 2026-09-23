# 02 · Induction

Unit tests check examples. Induction covers **every** natural number, and every
list or tree, with a finite argument:

1. prove the base case,
2. assume the claim for `n` (the *induction hypothesis*, `ih`), then prove it for `n + 1`.

The Order specification in Part 2 uses the same pattern, with *events* in place
of numbers. The claim holds for the empty order, and every event preserves it,
so it holds for **every reachable order**.

```lean
--8<-- "lean/Tutorial/Induction.lean"
```

Things worth pausing on:

- **`gauss`**: stated as `2 * sumTo n = n * (n + 1)` to avoid division on `Nat`.
  Choosing a statement that is easy to prove is a real skill in specification.
- **`MyNat`**: addition commutativity isn't built in. It is *derived* from two
  helper lemmas. Proofs often need a stronger or auxiliary statement first.
- **`Even`** is an *inductive predicate*, a set defined by rules. `not_even_one`
  holds because **no rule can produce it**. Part 2 defines `Reachable` orders in
  exactly this way.

!!! question "Exercise"
    Define `sumOdd n = 1 + 3 + … + (2n-1)` and prove `sumOdd n = n * n`.
