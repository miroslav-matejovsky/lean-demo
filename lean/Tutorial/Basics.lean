/-!
# 01 · Basics: propositions are types, proofs are programs

Lean checks every `theorem` when the file is compiled. If this file builds,
every statement below is *true* – not "tested", but proven.

Open this file in VS Code (with the `lean4` extension) and put your cursor
inside a `by` block: the *Infoview* panel shows the current goal.
-/

namespace Tutorial.Basics

/-! ## Computation: `rfl` and `decide` -/

-- `rfl` ("reflexivity"): both sides compute to the same value.
theorem one_plus_one : 1 + 1 = 2 := rfl

-- `decide`: run a decision procedure for a decidable proposition.
theorem small_fact : 2 ^ 10 = 1024 ∧ 17 % 5 = 2 := by decide

-- Strings compute too.
theorem string_append : "Str".append "ing" = "String" := by decide

-- A false statement does not compile. Uncomment to see the error:
-- theorem one_plus_one_is_fifteen : 1 + 1 = 15 := rfl

/-! ## Logic: proofs are functions

`A → B` is a function type: a proof of `A → B` turns evidence for `A`
into evidence for `B`.  `A ∧ B` is a pair, `A ∨ B` is a tagged union.
-/

variable {A B C : Prop}

-- Term-mode proof: literally a lambda.
theorem and_implies_or : A ∧ B → A ∨ B :=
  fun ⟨a, _b⟩ => Or.inl a

-- The same proof in tactic mode.
theorem and_implies_or' : A ∧ B → A ∨ B := by
  intro h
  exact Or.inl h.left

theorem and_comm' : A ∧ B → B ∧ A := by
  intro ⟨a, b⟩
  exact ⟨b, a⟩

-- Case analysis on an `Or` is pattern matching.
theorem or_comm' : A ∨ B → B ∨ A
  | .inl a => .inr a
  | .inr b => .inl b

-- Implication chains compose like functions.
theorem imp_trans (f : A → B) (g : B → C) : A → C := g ∘ f

-- Negation `¬A` is defined as `A → False`.
theorem modus_tollens (f : A → B) (nb : ¬B) : ¬A := fun a => nb (f a)

/-! ## Quantifiers -/

-- `∀` is a dependent function; `∃` is a pair (witness, proof).
theorem exists_even_gt_ten : ∃ n : Nat, n > 10 ∧ n % 2 = 0 := ⟨12, by decide⟩

theorem forall_succ_pos : ∀ n : Nat, 0 < n + 1 := fun n => Nat.succ_pos n

/-! ## Automation: `simp`, `omega`, `grind`

In practice you rarely write proof terms by hand. Lean ships powerful
tactics:
* `simp`  – rewriting with a database of lemmas,
* `omega` – decision procedure for linear arithmetic over `Nat`/`Int`,
* `grind` – SMT-style automation (congruence closure, arithmetic, case splits).
-/

theorem linear (a b : Nat) (h₁ : a < b) (h₂ : b < 10) : a + 1 < 10 := by omega

theorem simp_example (xs : List Nat) : (xs ++ []).length = xs.length := by simp

theorem grind_example (a b c : Nat) (h₁ : a = b) (h₂ : b = c + 1) : a ≠ c := by grind

end Tutorial.Basics
