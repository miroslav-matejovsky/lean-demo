# Limits and honest caveats

This is a learning repo. It should be clear about what it does *not* prove.

## 1. The refinement gap: the biggest caveat

What is **proven**: *the spec* satisfies its rules, for all message sequences.
What is **tested**: *the implementations* agree with the spec on about 6 000
sampled steps plus 60 convergence cases.

```text
operational intent --(human judgement)-->  theorems
theorems           --(Lean kernel: PROOF)--> spec
spec               --(vectors: SAMPLED)-->   .NET / Go code
```

A .NET bug that shows up only for a vessel that re-enters the zone exactly at
the boundary one second before going dark could slip through. Mutation testing
measures the hole. It does not close it. Closing it means verifying the
implementation itself: Dafny, Verus, Aeneas, or compiling the Lean spec and
calling it. See [Alternatives](alternatives.md).

!!! question "Is sampled good enough?"
    Compare with the status quo, not with perfection. Most systems today have no
    machine-checked link between the architecture document and the code. A
    proven spec plus thousands of generated checks plus a mutation score is a
    large step, even if it is not the last one.

## 2. Garbage in, proven garbage out

Lean proves that the spec satisfies *the theorems you wrote*. A wrong theorem is
a rigorous proof of the wrong thing. Mitigations:

- short theorem statements in operational language, reviewed by operations,
- **progress** properties next to safety properties: a spec that rejects every
  report is "safe" and useless,
- adversarial theorems, like `late_intrusion_missed`, that state uncomfortable
  facts on purpose.

## 3. Time is an assumption

Both specs take timestamps as given:

- **Zone**: `ts` is the receive time assigned ashore. If two receivers with
  skewed clocks feed the same track, "stale" means something else than you
  think. AIS itself carries only the UTC second of the position.
- **Health**: "newer wins" compares probe times from two machines. The views
  *converge* whatever the clocks do (proven). They may converge to the *wrong*
  report under clock skew (not proven, not true). Hybrid logical clocks or
  per-observer sequence numbers would move this into the spec.

## 4. Geometry is simplified

- The zone is an axis-aligned box in AIS units. Real zones are circles or
  polygons on WGS84. Distances need trigonometry and floating point.
- Lean can reason about exact integers and rationals well, about IEEE floats
  poorly. A realistic spec keeps integer or fixed-point geometry (a local
  projected grid, squared distances) and states the approximation error as an
  explicit assumption.
- The "position is inside" decision near the boundary is exactly where
  implementations with different float code will disagree. The spec fixes the
  rule. The vectors test the boundary.

## 5. Actors and the runtime are outside the spec

The spec covers one actor's behaviour for a given message sequence. It does not
cover:

- **mailbox order across actors** (two consoles acknowledging at the same moment),
- **restarts and persistence** (is state rebuilt by replaying the log, and is
  that replay the same `replayState`?),
- **supervision** (what happens to alarms while the actor is down),
- **authorization of operators** (four-eyes, who may acknowledge).

Some of these fit Lean well: event-sourced recovery is a theorem about
`replayState`. Others, like concurrent protocols, fit TLA+ or P better.

## 6. Split-brain is not in scope

The health spec assumes both instances are alive and exchange reports. The hard
problem in a primary/standby platform is **ownership**: at most one primary,
even during partitions and lease expiry. That is a distributed protocol with
timing assumptions. It deserves a model checker (TLA+) or a careful Lean model
with explicit clocks. It is listed in [Ideas](ideas.md).

## 7. Representation

The spec uses unbounded `Nat` and `Int`. Go and .NET use `int64`. For AIS units
and seconds the values are far from overflow, but that is an argument, not a
theorem. A theorem like "every reachable value fits in int64" is cheap to add
and belongs in a production spec.

## 8. Vector generation bias

Random traces with uniform choices rarely reach deep states. The generators are
biased toward boundaries by hand. Coverage-guided generation is better. See
[Ideas](ideas.md).

## 9. Cost, skills, churn

- Writing the spec is cheap. It is a small functional program.
- Writing proofs is medium to expensive and needs a trained person. The proofs
  here are mostly `cases`, `simp` and `omega`.
- Lean moves fast. This repo already hit a deprecated API between minor
  versions. Pin the toolchain and budget for upgrades.
