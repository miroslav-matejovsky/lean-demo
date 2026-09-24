import Truth.Zone.Spec

/-!
# Safety zone monitoring - proven properties

Each theorem is a business or operational rule. It holds for every
reachable track and every message sequence, including late, duplicated and
missing AIS reports.
-/

namespace Truth.Zone

/-- Tracks reachable from `Track.new` by accepted messages. -/
inductive Reachable : Track → Prop where
  | init : Reachable Track.new
  | next {t t' : Track} {e : Event} : Reachable t → step t e = .ok t' → Reachable t'

/-! ## The invariant: the alarm always tells the truth about the condition -/

theorem onCondition_isActive (s : AlarmState) (c : Bool) : (s.onCondition c).isActive = c := by
  cases s <;> cases c <;> rfl

-- --8<-- [start:inv]
def Inv (t : Track) : Prop := t.alarm.isActive = t.intrusion
-- --8<-- [end:inv]

theorem step_preserves_inv {t t' : Track} {e : Event}
    (hinv : Inv t) (h : step t e = .ok t') : Inv t' := by
  unfold Inv at *
  cases e with
  | report ts lat lon =>
    simp only [step] at h
    split at h; · contradiction
    split at h; · contradiction
    split at h; · contradiction
    cases h
    simp [Track.evaluate, onCondition_isActive, Track.intrusion]
  | acknowledge =>
    simp only [step] at h
    split at h <;> first | contradiction | (cases h; simp_all [AlarmState.isActive, Track.intrusion])
  | authorize a =>
    simp only [step] at h
    cases h
    simp [Track.evaluate, onCondition_isActive, Track.intrusion]
  | tick now =>
    simp only [step] at h
    split at h <;> (cases h; simp_all [Track.intrusion])

-- --8<-- [start:main]
/-- **Main theorem**: on every reachable track, the alarm is active exactly
when an unauthorized vessel is inside the zone. -/
theorem reachable_inv {t : Track} (h : Reachable t) : Inv t := by
  induction h with
  | init => rfl
  | next _ hs ih => exact step_preserves_inv ih hs
-- --8<-- [end:main]

/-! ## Corollaries -/

-- --8<-- [start:corollaries]
/-- An unauthorized vessel inside the zone always has an active alarm. -/
theorem intrusion_always_alarms {t : Track} (hr : Reachable t)
    (hin : t.inside = true) (hauth : t.authorized = false) : t.alarm.isActive = true := by
  have := reachable_inv hr
  simp_all [Inv, Track.intrusion]

/-- An authorized vessel never has an active alarm. -/
theorem authorized_never_alarms {t : Track} (hr : Reachable t)
    (hauth : t.authorized = true) : t.alarm.isActive = false := by
  have := reachable_inv hr
  simp_all [Inv, Track.intrusion]

/-- Going dark never clears an alarm: time passing changes nothing but `lost`. -/
theorem going_dark_keeps_alarm {t t' : Track} {now : Nat} (h : step t (.tick now) = .ok t') :
    t'.alarm = t.alarm ∧ t'.inside = t.inside := by
  simp only [step] at h
  split at h <;> (cases h; simp)

/-- A duplicated AIS report is harmless: the second copy is rejected as stale. -/
theorem duplicate_report_rejected {t t' : Track} {ts : Nat} {lat lon : Int}
    (h : step t (.report ts lat lon) = .ok t') :
    step t' (.report ts lat lon) = .error .staleReport := by
  simp only [step] at h ⊢
  split at h; · contradiction
  split at h; · contradiction
  split at h; · contradiction
  cases h
  simp_all [Track.evaluate]

/-- Time never goes backwards on a track. -/
theorem lastTs_monotone {t t' : Track} {e : Event} (h : step t e = .ok t') :
    t.lastTs ≤ t'.lastTs := by
  cases e with
  | report ts lat lon =>
    simp only [step] at h
    split at h; · contradiction
    split at h; · contradiction
    split at h; · contradiction
    cases h
    simp [Track.evaluate]; omega
  | acknowledge =>
    simp only [step] at h
    split at h <;> first | contradiction | (cases h; simp)
  | authorize a => simp only [step] at h; cases h; simp [Track.evaluate]
  | tick now => simp only [step] at h; split at h <;> (cases h; simp)
-- --8<-- [end:corollaries]

/-! ## No silent clear

An intrusion that an operator has not seen must never disappear by itself.
-/

-- --8<-- [start:silent]
theorem unacked_step {t t' : Track} {e : Event} (hu : t.alarm.isUnacked = true)
    (hne : e ≠ .acknowledge) (h : step t e = .ok t') : t'.alarm.isUnacked = true := by
  cases e with
  | report ts lat lon =>
    simp only [step] at h
    split at h; · contradiction
    split at h; · contradiction
    split at h; · contradiction
    cases h
    simp only [Track.evaluate]
    cases ht : t.alarm <;> simp_all [AlarmState.isUnacked] <;>
      cases (Track.intrusion _) <;> rfl
  | acknowledge => exact absurd rfl hne
  | authorize a =>
    simp only [step] at h; cases h
    simp only [Track.evaluate]
    cases ht : t.alarm <;> simp_all [AlarmState.isUnacked] <;>
      cases (Track.intrusion _) <;> rfl
  | tick now => simp only [step] at h; split at h <;> (cases h; simpa using hu)

/-- **No silent clear**: if nobody acknowledges, an unacknowledged alarm
stays unacknowledged, whatever else happens (reports, permits, time). -/
theorem no_silent_clear {t : Track} (hu : t.alarm.isUnacked = true)
    (es : List Event) (hna : Event.acknowledge ∉ es) :
    (replayState t es).alarm.isUnacked = true := by
  induction es generalizing t with
  | nil => exact hu
  | cons e es ih =>
    simp only [List.mem_cons, not_or] at hna
    simp only [replayState]
    split
    · next t' h => exact ih (unacked_step hu (Ne.symm hna.1) h) hna.2
    · exact ih hu hna.2
-- --8<-- [end:silent]

/-! ## An uncomfortable truth: delivery order matters

AIS reports can arrive late (satellite AIS, store-and-forward links,
a slow receiver). The spec rejects reports older than the newest one.
Consequence, proven below: a short intrusion that is delivered late is
never seen. Whether that is acceptable is a business decision. The proof
makes it impossible to ignore.
-/

-- --8<-- [start:order]
def inZone : Event := .report 100 35_100_000 1_200_000
def outside : Event := .report 160 35_200_000 1_200_000

/-- In order: the intrusion is seen, and it waits for acknowledgement. -/
theorem in_order_intrusion_seen :
    (replayState Track.new [inZone, outside]).alarm = .unackCleared := by decide

/-- Out of order: the late intrusion report is rejected as stale. No alarm. -/
theorem late_intrusion_missed :
    (replayState Track.new [outside, inZone]).alarm = .normal := by decide
-- --8<-- [end:order]

theorem replayState_reachable {t : Track} (hr : Reachable t) (es : List Event) :
    Reachable (replayState t es) := by
  induction es generalizing t with
  | nil => exact hr
  | cons e es ih =>
    simp only [replayState]
    split
    · next t' h => exact ih (.next hr h)
    · exact ih hr

end Truth.Zone
