/-!
# 04 - AIS on the wire: proofs about real protocol code

AIS messages travel as NMEA 0183 sentences, for example:

    !AIVDM,1,1,,B,177KQJ5000G?tO`K>RA1wUbN0TKH,0*5C

Two small algorithms protect and encode this data:

* the checksum after `*` is the XOR of every character between `!` and `*`,
* the payload (`177KQJ...`) uses 6-bit ASCII armoring: one character carries 6 bits.

This lesson proves what these algorithms guarantee, and what they do not.
A proof that exposes a weakness is as useful as one that confirms a strength.
-/

namespace Tutorial.Nmea

/-! ## The checksum -/

def xorAll (xs : List Nat) : Nat := xs.foldl (· ^^^ ·) 0

/-- Characters between the leading `!` (or `$`) and the `*`. -/
def body (sentence : String) : List Nat :=
  ((sentence.toList.drop 1).takeWhile (· ≠ '*')).map Char.toNat

def checksum (sentence : String) : Nat := xorAll (body sentence)

def example1 : String := "!AIVDM,1,1,,B,177KQJ5000G?tO`K>RA1wUbN0TKH,0*5C"

-- Evaluated at build time: the build fails if this is false.
#guard checksum example1 == 0x5C

theorem foldl_xor (acc : Nat) (xs : List Nat) :
    xs.foldl (· ^^^ ·) acc = acc ^^^ xorAll xs := by
  induction xs generalizing acc with
  | nil => simp [xorAll]
  | cons x xs ih =>
    simp only [xorAll, List.foldl_cons, Nat.zero_xor] at *
    rw [ih, ih x, Nat.xor_assoc]

theorem xorAll_cons (x : Nat) (xs : List Nat) : xorAll (x :: xs) = x ^^^ xorAll xs := by
  show List.foldl (· ^^^ ·) 0 (x :: xs) = _
  rw [List.foldl_cons, foldl_xor, Nat.zero_xor]

theorem xorAll_append (xs ys : List Nat) : xorAll (xs ++ ys) = xorAll xs ^^^ xorAll ys := by
  show List.foldl (· ^^^ ·) 0 (xs ++ ys) = _
  rw [List.foldl_append, foldl_xor]
  rfl

theorem xor_cancel_right {a b c : Nat} (h : a ^^^ c = b ^^^ c) : a = b := by
  have := congrArg (· ^^^ c) h
  simpa [Nat.xor_assoc, Nat.xor_self] using this

theorem xor_cancel_left {a b c : Nat} (h : c ^^^ a = c ^^^ b) : a = b := by
  rw [Nat.xor_comm c a, Nat.xor_comm c b] at h
  exact xor_cancel_right h

/-- Strength: any single corrupted character changes the checksum. -/
theorem detects_single_change (pre post : List Nat) {a b : Nat} (hne : a ≠ b) :
    xorAll (pre ++ a :: post) ≠ xorAll (pre ++ b :: post) := by
  intro h
  simp only [xorAll_append, xorAll_cons] at h
  exact hne (xor_cancel_right (xor_cancel_left h))

/-- Weakness: swapping two characters is never detected. -/
theorem misses_transposition (pre post : List Nat) (a b : Nat) :
    xorAll (pre ++ a :: b :: post) = xorAll (pre ++ b :: a :: post) := by
  simp only [xorAll_append, xorAll_cons]
  rw [← Nat.xor_assoc a, ← Nat.xor_assoc b, Nat.xor_comm a b]

/-- Weakness: two changes that flip the same bit cancel out ('A' = 65, 'C' = 67, 'B' = 66, '@' = 64). -/
theorem misses_double_change : xorAll [65, 67] = xorAll [66, 64] := by decide

/-! ## 6-bit armoring

Each payload character encodes a value 0..63:
values 0..39 map to `'0'..'W'`, values 40..63 map to `` '`'..'w' ``.
-/

def armor (v : Nat) : Char := Char.ofNat (if v < 40 then v + 48 else v + 56)

def unarmor (c : Char) : Nat :=
  let n := c.toNat - 48
  if n > 40 then n - 8 else n

/-- Round trip, proven by checking all 64 cases. `decide` turns a finite
exhaustive check into a proof. -/
theorem unarmor_armor : ∀ v : Fin 64, unarmor (armor v.val) = v.val := by decide

/-- Every armored character is a legal payload character. -/
theorem armor_range : ∀ v : Fin 64,
    (48 ≤ (armor v.val).toNat ∧ (armor v.val).toNat ≤ 87) ∨
    (96 ≤ (armor v.val).toNat ∧ (armor v.val).toNat ≤ 119) := by decide

/-- Round trip implies no two values share a character. -/
theorem armor_injective {v w : Fin 64} (h : armor v.val = armor w.val) : v = w := by
  have := unarmor_armor v
  rw [h, unarmor_armor w] at this
  exact Fin.ext this.symm

/-! ## Decoding fields

A payload is a bit string. Fields are read MSB first at fixed offsets
(ITU-R M.1371, message type 1).
-/

def bits (payload : String) : List Bool :=
  payload.toList.flatMap fun c =>
    let v := unarmor c
    (List.range 6).reverse.map fun i => v.testBit i

def field (bs : List Bool) (start len : Nat) : Nat :=
  ((bs.drop start).take len).foldl (fun acc b => 2 * acc + if b then 1 else 0) 0

/-- Signed field (two's complement), used for longitude and latitude. -/
def sfield (bs : List Bool) (start len : Nat) : Int :=
  let v := field bs start len
  if v ≥ 2 ^ (len - 1) then (v : Int) - 2 ^ len else v

def payload1 : String := "177KQJ5000G?tO`K>RA1wUbN0TKH"

#guard field (bits payload1) 0 6 == 1               -- message type 1: position report
#guard field (bits payload1) 8 30 == 477553000      -- MMSI
#guard field (bits payload1) 38 4 == 5              -- navigational status 5: moored
#guard sfield (bits payload1) 61 28 == -73407500    -- longitude in 1/10 000 minute
#guard sfield (bits payload1) 89 27 == 28549700     -- latitude  in 1/10 000 minute

-- -73407500 / 600000 = -122.3458 degrees, 28549700 / 600000 = 47.5828 degrees
#eval (sfield (bits payload1) 89 27, sfield (bits payload1) 61 28)

end Tutorial.Nmea
