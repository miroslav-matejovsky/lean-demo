/-!
# 03 - Specification vs. implementation (refinement)

This file is the bridge to the architecture part of the repo.

* A **specification** says *what* is correct. Written for clarity, not speed.
* An **implementation** says *how*. Written for performance.
* A **refinement proof** shows the implementation behaves exactly like the spec.

This is the core idea an architect can reuse: publish the specification as
the single source of truth; every implementation must be *shown* to agree.
-/

namespace Tutorial.SpecVsImpl

/-! ## Example 1: summing a list -/

-- Spec: obviously correct, but not tail recursive (stack grows with the list).
def sumSpec : List Nat → Nat
  | [] => 0
  | x :: xs => x + sumSpec xs

-- Implementation: accumulator-based loop.
def sumImpl (xs : List Nat) : Nat := go 0 xs
where
  go (acc : Nat) : List Nat → Nat
    | [] => acc
    | x :: xs => go (acc + x) xs

-- The key lemma generalises over the accumulator.
theorem sumImpl.go_eq (acc : Nat) (xs : List Nat) :
    sumImpl.go acc xs = acc + sumSpec xs := by
  induction xs generalizing acc with
  | nil => simp [sumImpl.go, sumSpec]
  | cons x xs ih => simp [sumImpl.go, sumSpec, ih]; omega

-- Refinement: for *every* list the two agree.
theorem sumImpl_correct (xs : List Nat) : sumImpl xs = sumSpec xs := by
  simp [sumImpl, sumImpl.go_eq]

/-! ## Example 2: a specification as properties

Sometimes the spec is not a reference function but a set of properties.
For `maxOf` the spec is: the result is in the list, and nothing is bigger.
-/

def maxOf : (xs : List Nat) → xs ≠ [] → Nat
  | [x], _ => x
  | x :: y :: rest, _ => max x (maxOf (y :: rest) (by simp))

theorem maxOf_ge : ∀ (xs : List Nat) (h : xs ≠ []), ∀ z ∈ xs, z ≤ maxOf xs h
  | [x], _, z, hz => by simp at hz; simp [maxOf, hz]
  | x :: y :: rest, _, z, hz => by
    have ih := maxOf_ge (y :: rest) (by simp)
    simp only [List.mem_cons] at hz
    simp only [maxOf]
    rcases hz with rfl | hz
    · omega
    · have := ih z (by simpa using hz); omega

theorem maxOf_mem : ∀ (xs : List Nat) (h : xs ≠ []), maxOf xs h ∈ xs
  | [x], _ => by simp [maxOf]
  | x :: y :: rest, _ => by
    have ih := maxOf_mem (y :: rest) (by simp)
    simp only [maxOf]
    rcases Nat.le_total x (maxOf (y :: rest) (by simp)) with hle | hle
    · rw [Nat.max_eq_right hle]; exact List.mem_cons_of_mem _ ih
    · rw [Nat.max_eq_left hle]; exact List.mem_cons_self

/-! ## Example 3: an executable spec is also a test oracle

Because Lean definitions *run*, the same spec that we reason about can
generate expected outputs for other languages. That is exactly what
`Truth/Export` does for the safety zone and health specs.
-/

#eval sumSpec [1, 2, 3, 4]              -- 10
#eval maxOf [3, 9, 2] (by simp)         -- 9

end Tutorial.SpecVsImpl
