import Truth.Order.Spec

/-!
# The Order domain – proven properties

These theorems are the reason the spec deserves to be called "truth".
They hold for **every** reachable order, for **every** sequence of events –
not only for the scenarios somebody thought of writing a test for.

If an architect changes `step` in a way that breaks a business rule,
`lake build` fails and the change cannot be merged.
-/

namespace Truth.Order

/-! ## Reachability -/

/-- Orders reachable from `Order.new` by successful events. -/
inductive Reachable : Order → Prop where
  | init : Reachable Order.new
  | next {o o' : Order} {e : Event} : Reachable o → step o e = .ok o' → Reachable o'

/-! ## The invariant (business rules as a single predicate) -/

def Line.Valid (l : Line) : Prop :=
  0 < l.qty ∧ l.qty ≤ maxQty ∧ 0 < l.unitPrice ∧ l.unitPrice ≤ maxUnitPrice

-- --8<-- [start:inv]
structure Inv (o : Order) : Prop where
  /-- Never more than `maxLines` lines. -/
  bounded : o.lines.length ≤ maxLines
  /-- Every line has a positive, bounded quantity and price. -/
  validLines : ∀ l ∈ o.lines, l.Valid
  /-- A submitted order is never empty. -/
  committedNonEmpty : o.status.isCommitted = true → o.lines ≠ []
  /-- Only large orders wait for approval. -/
  pendingAboveThreshold : o.status = .pendingApproval → o.total > approvalThreshold
  /-- Four-eyes principle: an approved/shipped order is small, or was approved by a human. -/
  fourEyes : o.status = .approved ∨ o.status = .shipped →
    o.total ≤ approvalThreshold ∨ o.approved = true
-- --8<-- [end:inv]

theorem inv_new : Inv Order.new := by
  constructor <;> simp [Order.new, Status.isCommitted, maxLines]

theorem total_append (o : Order) (l : Line) :
    ({ o with lines := o.lines ++ [l] } : Order).total = o.total + l.amount := by
  simp [Order.total]

theorem step_preserves_inv {o o' : Order} {e : Event}
    (hinv : Inv o) (h : step o e = .ok o') : Inv o' := by
  obtain ⟨hb, hv, hc, hp, hf⟩ := hinv
  cases e with
  | addLine sku qty price =>
    simp only [step] at h
    split at h; · contradiction
    split at h; · contradiction
    split at h; · contradiction
    split at h; · contradiction
    rename_i hdraft hq hpr hlen
    cases h
    refine ⟨?_, ?_, ?_, ?_, ?_⟩
    · simp; omega
    · intro l hl
      simp only [List.mem_append, List.mem_singleton] at hl
      rcases hl with hl | rfl
      · exact hv l hl
      · simp [Line.Valid]; omega
    all_goals simp_all [Status.isCommitted]
  | submit =>
    simp only [step] at h
    split at h; · contradiction
    split at h; · contradiction
    rename_i hdraft hne
    split at h <;> cases h <;> constructor <;> simp_all [Status.isCommitted, Order.total] <;> omega
  | approve =>
    simp only [step] at h
    split at h
    · cases h; constructor <;> simp_all [Status.isCommitted, Order.total]
    · contradiction
  | reject =>
    simp only [step] at h
    split at h
    · cases h; constructor <;> simp_all [Status.isCommitted, Order.total]
    · contradiction
  | ship =>
    simp only [step] at h
    split at h
    · cases h; constructor <;> simp_all [Status.isCommitted, Order.total]
    · contradiction
  | cancel =>
    simp only [step] at h
    split at h
    · contradiction
    · cases h; constructor <;> simp_all [Status.isCommitted, Order.total]

-- --8<-- [start:main]
/-- **Main theorem**: every reachable order satisfies all business rules. -/
theorem reachable_inv {o : Order} (h : Reachable o) : Inv o := by
  induction h with
  | init => exact inv_new
  | next _ hs ih => exact step_preserves_inv ih hs
-- --8<-- [end:main]

/-! ## Corollaries an auditor can read without reading the proof -/

-- --8<-- [start:corollaries]
/-- No large order is ever shipped without a human approval. -/
theorem no_unapproved_large_shipment {o : Order} (hr : Reachable o)
    (hs : o.status = .shipped) (hl : o.total > approvalThreshold) : o.approved = true := by
  rcases (reachable_inv hr).fourEyes (.inr hs) with h | h
  · omega
  · exact h

/-- A shipped order is final: every event is rejected. -/
theorem shipped_is_final {o : Order} (hs : o.status = .shipped) (e : Event) :
    step o e = .error .invalidTransition := by
  cases e <;> simp [step, hs]

/-- A cancelled order is final: every event is rejected. -/
theorem cancelled_is_final {o : Order} (hs : o.status = .cancelled) (e : Event) :
    step o e = .error .invalidTransition := by
  cases e <;> simp [step, hs]

/-- No dead ends: every non-final order can be cancelled. -/
theorem can_always_cancel {o : Order} (h₁ : o.status ≠ .shipped) (h₂ : o.status ≠ .cancelled) :
    ∃ o', step o .cancel = .ok o' ∧ o'.status = .cancelled := by
  exact ⟨{ o with status := .cancelled }, by simp [step, h₁, h₂], rfl⟩

/-- Liveness (of the model): a non-empty draft can always be driven to `shipped`. -/
theorem draft_can_ship {o : Order} (hd : o.status = .draft) (hne : o.lines ≠ []) :
    ∃ es o', run o es = .ok o' ∧ o'.status = .shipped := by
  by_cases ht : o.total > approvalThreshold
  · exact ⟨[.submit, .approve, .ship], { o with status := .shipped, approved := true },
      by simp [run, step, hd, hne, ht, bind, Except.bind], rfl⟩
  · exact ⟨[.submit, .ship], { o with status := .shipped },
      by simp [run, step, hd, hne, ht, bind, Except.bind], rfl⟩
-- --8<-- [end:corollaries]

/-! ## Representation guarantee for implementations

The spec uses unbounded `Nat`. Implementations use 64-bit integers.
This theorem is what *justifies* that choice: no reachable order total
can overflow `Int64`. Change a limit carelessly and this proof breaks.
-/

theorem sum_amount_le (ls : List Line) (hv : ∀ l ∈ ls, l.Valid) :
    (ls.map Line.amount).sum ≤ ls.length * (maxQty * maxUnitPrice) := by
  induction ls with
  | nil => simp
  | cons l ls ih =>
    simp only [List.map_cons, List.sum_cons, List.length_cons]
    have hl := hv l (by simp)
    have := ih (fun x hx => hv x (by simp [hx]))
    have : l.amount ≤ maxQty * maxUnitPrice :=
      Nat.mul_le_mul hl.2.1 hl.2.2.2
    rw [Nat.add_mul, Nat.one_mul]
    omega

theorem total_bounded {o : Order} (hr : Reachable o) :
    o.total ≤ maxLines * (maxQty * maxUnitPrice) := by
  have hinv := reachable_inv hr
  have := sum_amount_le o.lines hinv.validLines
  have := Nat.mul_le_mul_right (maxQty * maxUnitPrice) hinv.bounded
  unfold Order.total
  omega

-- --8<-- [start:int64]
theorem total_fits_int64 {o : Order} (hr : Reachable o) : o.total < 2 ^ 63 := by
  have := total_bounded hr
  have : maxLines * (maxQty * maxUnitPrice) < 2 ^ 63 := by decide
  omega
-- --8<-- [end:int64]

/-! ## Replay semantics used by the conformance vectors -/

theorem replayState_reachable {o : Order} (hr : Reachable o) (es : List Event) :
    Reachable (replayState o es) := by
  induction es generalizing o with
  | nil => exact hr
  | cons e es ih =>
    simp only [replayState]
    split
    · next o' h => exact ih (.next hr h)
    · exact ih hr

end Truth.Order
