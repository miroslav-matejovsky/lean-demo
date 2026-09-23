# The Order specification

Source: `lean/Truth/Order/Spec.lean` (behaviour) and `lean/Truth/Order/Properties.lean` (proofs).
All code on this page is embedded from those files at docs-build time.

## Domain in plain English

- An order starts as a **Draft**. Lines can be added only while it is a draft.
- Quantity must be in `1..maxQty`, and unit price in `1..maxUnitPrice` (cents).
  There are at most `maxLines` lines.
- **Submit** needs at least one line. If the total is **above** the approval threshold, the
  order goes to **PendingApproval**. Otherwise it is **Approved** immediately.
- A pending order can be **approved** by a human, which sets the `approved` flag.
  It can also be **rejected**, which sends it back to draft.
- Only **Approved** orders can be **shipped**. **Shipped** and **Cancelled** are final.
- A rejected command returns an error code and leaves the order unchanged.

## Policy constants

```lean
--8<-- "lean/Truth/Order/Spec.lean:policy"
```

## State

```lean
--8<-- "lean/Truth/Order/Spec.lean:order"
```

Design choices worth noticing:

- **`Nat` for money.** Negative amounts are unrepresentable, so they need no validation.
- **Minor units.** There is no floating point anywhere.
- **Pure and total.** The spec has no IO, no clock, and no exceptions. `step` always terminates.

## Behaviour: `step`

```lean
--8<-- "lean/Truth/Order/Spec.lean:step"
```

This one function is **the truth**. Diagrams, tables, vectors and generated code
are all *derived* from it. See the [generated state machine](../reference/order-state-machine.md).

!!! note "Precedence is part of the spec"
    Should `AddLine(qty = 0, price = 0)` report `InvalidQuantity` or `InvalidPrice`?
    A wiki page rarely says. The `if` order in `step` answers it, the vectors
    test it, and one mutant in `task mutate` checks exactly this.

## The invariant: business rules as one predicate

```lean
--8<-- "lean/Truth/Order/Properties.lean:inv"
```

## The main theorem

`Reachable` is defined inductively. The new order is reachable, and any successful
`step` from a reachable order is reachable. Every order that could ever exist in
production is therefore covered.

```lean
--8<-- "lean/Truth/Order/Properties.lean:main"
```

This proves the rules for **every sequence of events of any length**. No test
suite can do that.

## Corollaries (what auditors and stakeholders read)

```lean
--8<-- "lean/Truth/Order/Properties.lean:corollaries"
```

`draft_can_ship` and `can_always_cancel` are *progress* properties. They rule out
the opposite failure, a spec so restrictive that orders get stuck. Safety alone
is trivially satisfied by a system that rejects everything.

## A proof that justifies an implementation choice

The spec uses unbounded `Nat`, while .NET and Go use `long`/`int64`. Is that safe?

```lean
--8<-- "lean/Truth/Order/Properties.lean:int64"
```

If someone raises `maxQty` to 10¹⁰, this proof breaks **before** any
implementation silently overflows. The architecture decision "use int64 for
amounts" now comes with a machine-checked justification.

## Spec-level unit tests

`Truth/Export/Vectors.lean` contains `#guard` checks. These evaluate at compile
time, and the build fails if they are false. Use them for readable examples.
Use theorems for guarantees.
