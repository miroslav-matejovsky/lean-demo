import Truth.Health.Spec

/-!
# Replicated site health view - proven properties

The goal is `convergence`: two replicas that received the same set of
reports show the same view, whatever the order and however many duplicates.
The path there is the classic CRDT argument:

1. `Report.lt` is a strict total order,
2. so `join` is commutative, associative and idempotent,
3. so receiving reports commutes and duplicates are absorbed,
4. so only the *set* of received reports matters.
-/

namespace Truth.Health

/-! ## 1. A strict total order -/

theorem Health.rank_inj {a b : Health} (h : a.rank = b.rank) : a = b := by
  cases a <;> cases b <;> simp_all [Health.rank]

theorem Observer.rank_inj {a b : Observer} (h : a.rank = b.rank) : a = b := by
  cases a <;> cases b <;> simp_all [Observer.rank]

theorem Report.lt_irrefl (a : Report) : ¬ a.lt a := by
  unfold Report.lt; omega

theorem Report.lt_asymm {a b : Report} (h : a.lt b) : ¬ b.lt a := by
  unfold Report.lt at *; omega

theorem Report.lt_trans {a b c : Report} (h₁ : a.lt b) (h₂ : b.lt c) : a.lt c := by
  unfold Report.lt at *; omega

theorem Report.eq_of_not_lt {a b : Report} (h₁ : ¬ a.lt b) (h₂ : ¬ b.lt a) : a = b := by
  unfold Report.lt at *
  have hts : a.ts = b.ts := by omega
  have hh : a.health.rank = b.health.rank := by omega
  have ho : a.observer.rank = b.observer.rank := by omega
  have hu : a.unit = b.unit := by omega
  cases a; cases b
  simp only at hts hh ho hu
  subst hts hu
  obtain rfl := Health.rank_inj hh
  obtain rfl := Observer.rank_inj ho
  rfl

/-- Two reports that are both "not smaller" in a chain cannot be out of order. -/
theorem Report.not_lt_trans {a b c : Report} (h₁ : ¬ a.lt b) (h₂ : ¬ b.lt c) : ¬ a.lt c := by
  unfold Report.lt at *; omega

/-! ## 2. `join` is a semilattice -/

-- --8<-- [start:laws]
theorem join_some (x y : Report) : join (some x) (some y) = some (if x.lt y then y else x) := by
  simp only [join]; split <;> rfl

theorem join_none_right (a : Option Report) : join a none = a := by
  cases a <;> rfl

theorem join_comm (a b : Option Report) : join a b = join b a := by
  rcases a with _ | x <;> rcases b with _ | y
  all_goals try rfl
  rw [join_some, join_some]
  by_cases h₁ : x.lt y <;> by_cases h₂ : y.lt x <;> simp [h₁, h₂]
  · exact (Report.lt_asymm h₁ h₂).elim
  · exact Report.eq_of_not_lt h₁ h₂

theorem join_assoc (a b c : Option Report) : join (join a b) c = join a (join b c) := by
  rcases a with _ | x <;> rcases b with _ | y <;> rcases c with _ | z
  all_goals try rfl
  all_goals try (simp only [join_none_right]; done)
  rw [join_some x y, join_some _ z, join_some y z, join_some x]
  by_cases hxy : x.lt y <;> by_cases hyz : y.lt z <;> by_cases hxz : x.lt z <;>
    simp [hxy, hyz, hxz]
  · exact (hxz (Report.lt_trans hxy hyz)).elim
  · exact (Report.not_lt_trans hxy hyz hxz).elim

theorem join_idem (a : Option Report) : join a a = a := by
  cases a <;> simp [join, Report.lt_irrefl]
-- --8<-- [end:laws]

/-- Merging whole views inherits the laws, so anti-entropy in any direction agrees. -/
theorem merge_comm (v w : View) : merge v w = merge w v := by
  funext u; exact join_comm _ _

theorem merge_assoc (v w x : View) : merge (merge v w) x = merge v (merge w x) := by
  funext u; exact join_assoc _ _ _

theorem merge_idem (v : View) : merge v v = v := by
  funext u; exact join_idem _

/-! ## 3. Receiving commutes and absorbs duplicates -/

theorem join_join_comm (x : Option Report) (a b : Report) :
    join (join x (some a)) (some b) = join (join x (some b)) (some a) := by
  rw [join_assoc, join_comm (some a), ← join_assoc]

theorem join_join_self (x : Option Report) (a : Report) :
    join (join x (some a)) (some a) = join x (some a) := by
  rw [join_assoc, join_idem]

/-- Pointwise meaning of `ingest`: only the reported unit changes. -/
theorem ingest_apply (v : View) (r : Report) (u : Nat) :
    ingest v r u = if u = r.unit ∧ r.unit < siteUnits then join (v u) (some r) else v u := by
  unfold ingest receive
  by_cases h : r.unit < siteUnits
  · simp only [if_pos h]
    by_cases hu : u = r.unit
    · simp only [if_pos hu, if_pos (And.intro hu h)]
    · simp only [if_neg hu, if_neg (fun c : u = r.unit ∧ _ => hu c.1)]
  · simp only [if_neg h, if_neg (fun c : u = r.unit ∧ _ => h c.2)]

theorem ingest_comm (v : View) (a b : Report) : ingest (ingest v a) b = ingest (ingest v b) a := by
  funext u
  simp only [ingest_apply]
  by_cases ca : u = a.unit ∧ a.unit < siteUnits <;> by_cases cb : u = b.unit ∧ b.unit < siteUnits
  · simp only [if_pos ca, if_pos cb, join_join_comm]
  · simp only [if_pos ca, if_neg cb]
  · simp only [if_neg ca, if_pos cb]
  · simp only [if_neg ca, if_neg cb]

theorem ingest_idem (v : View) (a : Report) : ingest (ingest v a) a = ingest v a := by
  funext u
  simp only [ingest_apply]
  by_cases ca : u = a.unit ∧ a.unit < siteUnits
  · simp only [if_pos ca, join_join_self]
  · simp only [if_neg ca]

/-! ## 4. Only the set of reports matters -/

theorem ingest_foldl_comm (v : View) (r : Report) (rs : List Report) :
    ingest (rs.foldl ingest v) r = rs.foldl ingest (ingest v r) := by
  induction rs generalizing v with
  | nil => rfl
  | cons x rs ih => simp only [List.foldl_cons, ih, ingest_comm]

/-- Re-delivering a report that was already received changes nothing. -/
theorem ingest_absorb (v : View) {r : Report} {rs : List Report} (h : r ∈ rs) :
    ingest (rs.foldl ingest v) r = rs.foldl ingest v := by
  induction rs generalizing v with
  | nil => simp at h
  | cons x rs ih =>
    simp only [List.foldl_cons]
    rcases List.mem_cons.mp h with rfl | h
    · rw [ingest_foldl_comm, ingest_idem]
    · exact ih _ h

theorem foldl_absorb (v : View) {rs extra : List Report} (h : ∀ r ∈ extra, r ∈ rs) :
    extra.foldl ingest (rs.foldl ingest v) = rs.foldl ingest v := by
  induction extra with
  | nil => rfl
  | cons x extra ih =>
    simp only [List.foldl_cons]
    rw [ingest_absorb v (h x (by simp))]
    exact ih (fun r hr => h r (by simp [hr]))

theorem foldl_perm (v : View) {xs ys : List Report} (h : xs.Perm ys) :
    xs.foldl ingest v = ys.foldl ingest v := by
  induction h generalizing v with
  | nil => rfl
  | cons x _ ih => exact ih _
  | swap x y _ => simp only [List.foldl_cons, ingest_comm]
  | trans _ _ ih₁ ih₂ => exact (ih₁ v).trans (ih₂ v)

-- --8<-- [start:convergence]
/-- **Convergence**: replicas that received the same reports agree,
regardless of delivery order and duplicates. -/
theorem convergence {xs ys : List Report} (h : ∀ r, r ∈ xs ↔ r ∈ ys) :
    deliver xs = deliver ys := by
  unfold deliver
  have hx : (xs ++ ys).foldl ingest View.empty = xs.foldl ingest View.empty := by
    rw [List.foldl_append]; exact foldl_absorb _ (fun r hr => (h r).mpr hr)
  have hy : (ys ++ xs).foldl ingest View.empty = ys.foldl ingest View.empty := by
    rw [List.foldl_append]; exact foldl_absorb _ (fun r hr => (h r).mp hr)
  rw [← hx, ← hy]
  exact foldl_perm _ List.perm_append_comm

/-- Receiving a report is merging a one-entry view (a delta). -/
theorem ingest_eq_merge (v : View) (r : Report) : ingest v r = merge v (ingest View.empty r) := by
  funext u
  simp only [merge, ingest_apply]
  by_cases c : u = r.unit ∧ r.unit < siteUnits
  · simp only [if_pos c]; rfl
  · simp only [if_neg c]; exact (join_none_right _).symm

theorem foldl_eq_merge (v : View) (rs : List Report) :
    rs.foldl ingest v = merge v (rs.foldl ingest View.empty) := by
  induction rs generalizing v with
  | nil => exact (by funext u; exact (join_none_right _).symm)
  | cons x rs ih =>
    simp only [List.foldl_cons]
    rw [ih, ih (ingest View.empty x), ingest_eq_merge v x, merge_assoc]

/-- **Anti-entropy is sound**: merging the views of two partial inboxes gives
the view of the combined inbox. Primary and standby can sync in either direction. -/
theorem merge_deliver (p q : List Report) : merge (deliver p) (deliver q) = deliver (p ++ q) := by
  unfold deliver
  rw [List.foldl_append, foldl_eq_merge (p.foldl ingest View.empty)]

/-- The console shows the same status on both replicas, at any time. -/
theorem status_converges {xs ys : List Report} (h : ∀ r, r ∈ xs ↔ r ∈ ys) (now u : Nat) :
    status (deliver xs) now u = status (deliver ys) now u := by
  rw [convergence h]
-- --8<-- [end:convergence]

/-! ## Operational rules -/

-- --8<-- [start:rules]
/-- On equal probe time, the worse report wins, whichever arrived first. -/
theorem tie_prefers_worse {a b : Report} (hts : a.ts = b.ts) (hw : a.health.rank < b.health.rank) :
    join (some a) (some b) = some b ∧ join (some b) (some a) = some b := by
  have hab : a.lt b := by unfold Report.lt; omega
  exact ⟨by simp [join, hab], by simp [join, Report.lt_asymm hab]⟩

/-- A unit nobody reported on reads as Unknown, never as Healthy. -/
theorem unreported_is_unknown (now u : Nat) : status View.empty now u = .unknown := rfl

/-- An expired report reads as Unknown: silence is not health. -/
theorem stale_is_unknown {v : View} {u now : Nat} {r : Report}
    (hv : v u = some r) (hs : now > r.ts + freshFor) : status v now u = .unknown := by
  simp [status, hv, hs]

/-- Receiving a report never makes the view older for any unit. -/
theorem ingest_monotone (v : View) (r : Report) (u : Nat) (x : Report) (hv : v u = some x) :
    ∃ y, ingest v r u = some y ∧ x.ts ≤ y.ts := by
  rw [ingest_apply, hv]
  by_cases c : u = r.unit ∧ r.unit < siteUnits
  · rw [if_pos c, join_some]
    by_cases h : x.lt r
    · refine ⟨r, by simp [h], ?_⟩
      unfold Report.lt at h; omega
    · exact ⟨x, by simp [h], Nat.le_refl _⟩
  · exact ⟨x, by rw [if_neg c], Nat.le_refl _⟩
-- --8<-- [end:rules]

end Truth.Health
