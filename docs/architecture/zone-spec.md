# Safety zone spec

Source: `lean/Truth/Zone/Spec.lean` (behaviour) and `lean/Truth/Zone/Properties.lean`
(theorems). All code on this page is embedded from those files.

## Domain in plain words

- An offshore installation has a safety zone. UNCLOS Article 60 allows up to
  500 m around installations. Here the zone is an axis-aligned box of about
  500 m around a fictional position in the North Sea.
- A surveillance system receives AIS position reports per vessel (per MMSI).
- An **unauthorized vessel inside the zone** is the alarm condition. Service
  vessels can be authorized.
- The alarm follows the usual alarm-management lifecycle (IEC 62682 /
  ISA-18.2, and the IMO Bridge Alert Management states). An alarm whose
  condition cleared but that nobody acknowledged is *rectified-unacknowledged*
  (`UnackCleared`). It does not disappear on its own.
- A track with no report for 3 minutes is **lost**: the vessel went dark.
- Reports can be duplicated or late. A report not newer than the last one is
  rejected as stale.

One track is one actor: one owner of the state, messages in, a deterministic
reaction. `step` is that reaction.

## Policy

Positions stay in AIS integer units (1/10 000 minute). No floating point.

```lean
--8<-- "lean/Truth/Zone/Spec.lean:policy"
```

## State

```lean
--8<-- "lean/Truth/Zone/Spec.lean:track"
```

## Behaviour

```lean
--8<-- "lean/Truth/Zone/Spec.lean:step"
```

This function is **the truth**. The [generated alarm reference](../reference/zone-alarm.md),
the vectors and the generated constants are derived from it.

!!! note "Precedence is part of the spec"
    A report with latitude "not available" *and* an old timestamp: is it
    `PositionUnavailable` or `StaleReport`? A wiki rarely says. The order of the
    `if` branches answers it (`PositionUnavailable`), and the vectors test it.

## The invariant

```lean
--8<-- "lean/Truth/Zone/Properties.lean:inv"
```

```lean
--8<-- "lean/Truth/Zone/Properties.lean:main"
```

`Reachable` is inductive: a new track is reachable, and any accepted message
from a reachable track gives a reachable track. So this holds for every track
that can exist in production, after any sequence of any length.

## Corollaries

```lean
--8<-- "lean/Truth/Zone/Properties.lean:corollaries"
```

## No silent clear

The rule operators care about most: an intrusion nobody has seen must not
vanish.

```lean
--8<-- "lean/Truth/Zone/Properties.lean:silent"
```

Read `no_silent_clear` as: *whatever reports, permits and timer ticks arrive,
if nobody acknowledges, the alarm stays unacknowledged.* It is a statement
about all message sequences, not a test case.

## An uncomfortable truth: order matters

```lean
--8<-- "lean/Truth/Zone/Properties.lean:order"
```

The spec rejects reports older than the newest one. That is reasonable for
position (old news), but it means a short intrusion whose report arrives late
(satellite AIS, store-and-forward, a slow receiver) is **never alarmed**.

This is a business decision, not a bug. The proof makes it impossible to
overlook. Options:

- accept it and document it (current spec),
- keep a separate "intrusion history" and raise a *late* alarm,
- use the AIS timestamp for ordering only within a bounded window.

Each option is a spec change with theorems to re-prove. That is the
conversation this setup forces.
