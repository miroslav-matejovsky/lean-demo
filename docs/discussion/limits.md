# Limits & honest caveats

This is a learning repo, so it should be clear about what it does *not* prove.

## 1. The refinement gap: the biggest caveat

What is **proven**: *the spec* satisfies the business rules, for all inputs.
What is **tested**: *the implementations* agree with the spec on ~4 000 sampled steps.

These are different guarantees. The chain is:

```text
business intent ──(human judgement)──▶ theorems
theorems        ──(Lean kernel: PROOF)──▶ spec
spec            ──(vectors: SAMPLED)──▶ .NET / Go code
```

A .NET bug that only shows up with 7 lines, a price of 333 333 and a reject-resubmit
cycle could slip through. Mutation testing measures the size of that hole, but
doesn't close it. Closing it fully requires the implementation itself to be
verified (see [Alternatives](alternatives.md): Dafny, Verus, Aeneas, or writing
the core in Lean).

!!! question "Is 'sampled' good enough?"
    Compare it to the status quo, not to perfection. Most enterprises today have
    zero machine-checked link between the architecture document and the code.
    Going from "a Confluence page" to "4 000 spec-derived checks plus proven rules
    about the spec" is a big step, even if it isn't the final one.

## 2. Garbage in, proven garbage out

Lean proves that the spec satisfies *the theorems you wrote*. If the theorem
says the wrong thing, you have a very rigorous proof of the wrong thing.
Mitigations:

- keep theorem statements short and in business language (reviewable),
- add **progress** theorems (`draft_can_ship`) so the spec can't be "safe" by
  rejecting everything,
- write adversarial theorems ("it is impossible to …") and scenario `#guard`s.

## 3. Only what is modelled is covered

The spec knows nothing about:

- **Concurrency.** Two approvers clicking at the same moment, optimistic locking.
- **Distribution.** At-least-once delivery, event reordering, sagas, idempotency.
- **Time.** Timeouts, SLAs, "approve within 48 h".
- **Persistence and serialisation.** JSON rounding, DB constraints, migrations.
- **Authorization.** *Who* may approve. The four-eyes rule here only says *that*
  someone approved, not that it was a different person.

Each can be modelled, but modelling costs effort. For distributed protocols, TLA+
or P is usually the better tool.

## 4. Representation mismatches

The spec uses `Nat`, and the code uses `int64`. We **proved** totals fit (`total_fits_int64`),
but only for *reachable* orders. An implementation that accepts `qty = 2^62`
before validating could still overflow in intermediate arithmetic. Strings are
another trap: Lean `String` is Unicode scalar values, while .NET is UTF-16.
SKU comparison and length semantics could differ.

## 5. Vector generation bias

Random traces with uniform event choice rarely reach deep states. In the current
vectors, only one step hits `TooManyLines`, which comes from a hand-written scenario.
Improve this with coverage-guided generation (see [Ideas](ideas.md)), and check
coverage per transition, which you can compute from `vectors.json`.

## 6. Cost and skills

- Writing the spec: cheap. It is a functional program.
- Writing proofs: medium to expensive, and needs a trained person. Automation
  (`grind`) and LLMs help a lot for invariant-style proofs like the ones here.
- Keeping it alive: the drift gate makes *not* updating the spec impossible,
  which is the point, but it is also friction. Expect pushback.

## 7. Toolchain churn

Lean 4 moves fast. This repo already hit a deprecation (`String.trimRight`)
between versions. Pin the toolchain (`lean/lean-toolchain`) and budget for upgrades.
