import Truth.Order.Spec
import Truth.Export.Json

/-!
# Conformance vectors

The spec is executable, so it can act as a *test oracle*: we feed it
event sequences and record exactly what it answers. Every implementation
must reproduce these answers bit-for-bit.

Two sources of traces:
* **scenarios** – hand-written, named, readable business examples
  (these double as spec-level unit tests via `#guard`);
* **generated** – pseudo-random traces from a fixed seed, biased toward
  boundaries (threshold, limits, invalid values).
-/

namespace Truth.Export
open Truth.Order

/-! ## Encoding (the wire format shared by every implementation) -/

def encodeEvent : Event → Json
  | .addLine sku qty price =>
    .obj [("type", .str "AddLine"), ("sku", .str sku), ("qty", .num qty), ("unitPrice", .num price)]
  | e => .obj [("type", .str e.kind)]

def encodeResult : Except ErrorCode Order → Json
  | .ok o => .obj [("ok", .bool true), ("status", .str o.status.name), ("total", .num o.total),
                   ("lines", .num o.lines.length), ("approved", .bool o.approved)]
  | .error e => .obj [("ok", .bool false), ("error", .str e.name)]

structure Trace where
  name : String
  events : List Event

def encodeTrace (t : Trace) : Json :=
  let results := replay Order.new t.events
  .obj [("name", .str t.name),
        ("steps", .arr ((t.events.zip results).map fun (e, r) =>
          .obj [("event", encodeEvent e), ("expect", encodeResult r)]))]

/-! ## Hand-written scenarios -/

def line (qty price : Nat) (sku := "SKU-1") : Event := .addLine sku qty price

def scenarios : List Trace := [
  { name := "small order ships without approval"
    events := [line 2 1_000, .submit, .ship] },
  { name := "large order needs approval"
    events := [line 2 600_000, .submit, .ship, .approve, .ship] },
  { name := "total exactly at threshold is auto-approved"
    events := [line 1 approvalThreshold, .submit] },
  { name := "total one cent above threshold waits for approval"
    events := [line 1 approvalThreshold, line 1 1, .submit] },
  { name := "rejected order returns to draft and can be fixed"
    events := [line 3 500_000, .submit, .reject, .submit, .cancel] },
  { name := "cannot submit an empty order"
    events := [.submit, .ship] },
  { name := "quantity and price limits"
    events := [line 0 100, line (maxQty + 1) 100, line 1 0, line 1 (maxUnitPrice + 1),
               line maxQty maxUnitPrice, .submit, .approve] },
  { name := "line limit"
    events := (List.range (maxLines + 1)).map (fun i => line 1 100 s!"SKU-{i}") },
  { name := "shipped is final"
    events := [line 1 100, .submit, .ship, .cancel, .reject, line 1 1] },
  { name := "cancelled is final"
    events := [line 1 100, .cancel, .submit, .cancel] },
  { name := "cannot add lines after submit"
    events := [line 1 100, .submit, line 1 100] }
]

-- Spec-level unit tests: evaluated at compile time; the build fails if they break.
#guard (replayState Order.new [line 1 approvalThreshold, .submit]).status == .approved
#guard (replayState Order.new [line 1 approvalThreshold, line 1 1, .submit]).status == .pendingApproval
#guard (replayState Order.new [.submit]).status == .draft

/-! ## Generated traces (deterministic PRNG) -/

structure Rng where
  state : UInt64

/-- 64-bit LCG (Knuth MMIX constants). Plenty for test generation; reproducible across platforms. -/
def Rng.next (r : Rng) : Nat × Rng :=
  let s := r.state * 6364136223846793005 + 1442695040888963407
  ((s >>> 33).toNat, ⟨s⟩)

def Rng.pick {α} [Inhabited α] (r : Rng) (xs : List α) : α × Rng :=
  let (n, r) := r.next
  (xs[n % xs.length]!, r)

def qtyChoices : List Nat := [1, 1, 2, 3, 5, 0, maxQty, maxQty + 1]
def priceChoices : List Nat :=
  [100, 999, 25_000, 250_000, 499_999, approvalThreshold, approvalThreshold + 1, 0, maxUnitPrice, maxUnitPrice + 1]

def genEvent (r : Rng) : Event × Rng :=
  let (k, r) := r.next
  match k % 20 with
  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 =>
    let (sku, r) := r.pick ["A", "B", "C"]
    let (q, r) := r.pick qtyChoices
    let (p, r) := r.pick priceChoices
    (.addLine s!"SKU-{sku}" q p, r)
  | 8 | 9 | 10 => (.submit, r)
  | 11 | 12 => (.approve, r)
  | 13 => (.reject, r)
  | 14 | 15 | 16 => (.ship, r)
  | 17 => (.cancel, r)
  | _ => (.addLine "SKU-A" 1 100, r)

def genTrace (len : Nat) (r : Rng) : List Event × Rng :=
  match len with
  | 0 => ([], r)
  | n + 1 =>
    let (e, r) := genEvent r
    let (es, r) := genTrace n r
    (e :: es, r)

def generated (count : Nat) (seed : UInt64) : List Trace :=
  go count ⟨seed⟩ []
where
  go : Nat → Rng → List Trace → List Trace
    | 0, _, acc => acc.reverse
    | n + 1, r, acc =>
      let (len, r) := r.next
      let (es, r) := genTrace (4 + len % 20) r
      go n r ({ name := s!"generated #{count - n}", events := es } :: acc)

def vectorSeed : UInt64 := 20260923
def vectorCount : Nat := 300

def vectorsJson : Json :=
  .obj [("specVersion", .str specVersion),
        ("seed", .num vectorSeed.toNat),
        ("traces", .arr ((scenarios ++ generated vectorCount vectorSeed).map encodeTrace))]

end Truth.Export
