/-!
# 02 · Induction: proving things about *all* natural numbers

Tests check a handful of inputs. Induction covers infinitely many:
prove the base case, then prove that case `n` implies case `n + 1`.
-/

namespace Tutorial.Induction

/-! ## Gauss: 0 + 1 + … + n = n(n+1)/2

We avoid division by stating `2 * sum n = n * (n + 1)`.
-/

def sumTo : Nat → Nat
  | 0 => 0
  | n + 1 => sumTo n + (n + 1)

#eval sumTo 100  -- 5050

theorem gauss (n : Nat) : 2 * sumTo n = n * (n + 1) := by
  induction n with
  | zero => rfl
  | succ k ih =>
    -- goal: 2 * (sumTo k + (k + 1)) = (k + 1) * (k + 1 + 1)
    simp only [sumTo, Nat.mul_add, ih]
    -- remaining goal is a polynomial identity
    simp only [Nat.add_mul, Nat.mul_one, Nat.one_mul]
    omega

/-! ## Our own natural numbers

To see that nothing is magic, define ℕ from scratch and prove
addition is commutative – the classic first exercise.
-/

inductive MyNat where
  | zero : MyNat
  | succ : MyNat → MyNat

namespace MyNat

def add : MyNat → MyNat → MyNat
  | n, zero => n
  | n, succ m => succ (add n m)

theorem zero_add (n : MyNat) : add zero n = n := by
  induction n with
  | zero => rfl
  | succ n ih => simp [add, ih]

theorem succ_add (n m : MyNat) : add (succ n) m = succ (add n m) := by
  induction m with
  | zero => rfl
  | succ m ih => simp [add, ih]

theorem add_comm (n m : MyNat) : add n m = add m n := by
  induction m with
  | zero => simp [add, zero_add]
  | succ m ih => simp [add, succ_add, ih]

end MyNat

/-! ## Even and odd, as an inductive predicate -/

inductive Even : Nat → Prop where
  | zero : Even 0
  | plusTwo : Even n → Even (n + 2)

theorem even_four : Even 4 := .plusTwo (.plusTwo .zero)

theorem even_double (n : Nat) : Even (2 * n) := by
  induction n with
  | zero => exact .zero
  | succ k ih =>
    have : 2 * (k + 1) = 2 * k + 2 := by omega
    rw [this]
    exact .plusTwo ih

-- Inversion: 1 is not even (no constructor can produce `Even 1`).
theorem not_even_one : ¬ Even 1 := by
  intro h
  cases h

theorem even_add {n m : Nat} (hn : Even n) (hm : Even m) : Even (n + m) := by
  induction hn with
  | zero => simpa using hm
  | @plusTwo k _ ih =>
    have : k + 2 + m = (k + m) + 2 := by omega
    rw [this]
    exact .plusTwo ih

end Tutorial.Induction
