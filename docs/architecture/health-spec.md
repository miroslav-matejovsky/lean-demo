# Site health spec

Source: `lean/Truth/Health/Spec.lean` and `lean/Truth/Health/Properties.lean`.

## Domain in plain words

- A site runs a **primary** and a **standby** platform instance.
- Both probe the same service units, every `probeInterval` seconds, and publish
  health reports.
- Every instance keeps its own **view**: per unit, the best report seen so far.
- Reports travel over a constrained network: late, out of order, more than once.
- Instances also sync whole views (anti-entropy), in either direction.
- A report is evidence for `freshFor = 2 * probeInterval + probeTimeout`
  seconds. One missed probe is tolerated, two are not. After that the console
  shows **Unknown**: silence is not health.

The requirement: two instances that received the same reports show the same
view. Otherwise two operators see two different truths during an incident.

## Policy

```lean
--8<-- "lean/Truth/Health/Spec.lean:policy"
```

## Which report wins

```lean
--8<-- "lean/Truth/Health/Spec.lean:report"
```

The order must be **total**: no two different reports may tie. Otherwise two
replicas could keep different reports and never agree. The tie-breaks
(observer, unit) carry no business meaning. They exist only to make the order
total. The [generated reference](../reference/health-view.md) shows the
resulting table.

## Behaviour

```lean
--8<-- "lean/Truth/Health/Spec.lean:view"
```

## The CRDT laws

```lean
--8<-- "lean/Truth/Health/Properties.lean:laws"
```

`join` is commutative, associative and idempotent: a join-semilattice. That is
all a state-based CRDT needs. From these laws:

- receiving reports commutes (`ingest_comm`),
- a duplicate is absorbed (`ingest_idem`, `ingest_absorb`),
- any permutation gives the same result (`foldl_perm`).

## Convergence

```lean
--8<-- "lean/Truth/Health/Properties.lean:convergence"
```

`convergence` quantifies over **all** pairs of inboxes with the same set of
reports: any order, any number of duplicates. `merge_deliver` says that
anti-entropy between partial inboxes gives the same view as receiving
everything. Together they justify the primary/standby sync protocol.

## Operational rules

```lean
--8<-- "lean/Truth/Health/Properties.lean:rules"
```

!!! warning "What convergence does not cover"
    "Newer wins" compares probe timestamps from *two different machines*. If
    their clocks disagree, the view converges, but maybe to the wrong report.
    Convergence is proven. Correctness under clock skew is not. See
    [Limits](../discussion/limits.md#3-time-is-an-assumption).
