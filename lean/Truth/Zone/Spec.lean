/-!
# Safety zone monitoring - executable specification

An offshore installation (a wind turbine, a substation, a platform) has a
safety zone. Unauthorized vessels must not enter it. A surveillance system
receives AIS position reports and raises an alarm for an operator.

The unit of state is one **vessel track** (one MMSI). In an actor system this
is one actor per vessel: one owner of the state, messages in, a deterministic
reaction for a given message sequence. `step` below is that reaction.

The alarm lifecycle follows the common alarm-management model
(IEC 62682 / ANSI/ISA-18.2, and the IMO Bridge Alert Management states):

* `normal`       - no condition, nothing to acknowledge
* `unackActive`  - condition present, operator has not acknowledged
* `ackActive`    - condition present, operator acknowledged
* `unackCleared` - condition gone, but the operator never acknowledged it

Implementations (.NET, Go) do not import this file. They receive generated
constants and conformance vectors. See `Truth/Export`.
-/

namespace Truth.Zone

/-- Semantic version of this specification. Bump on any behavioural change. -/
def specVersion : String := "1.0.0"

/-! ## Units and policy

AIS message type 1 carries position in 1/10 000 minute (ITU-R M.1371).
One degree is 600 000 units. We keep these integer units everywhere:
no floating point in the truth.
-/

-- --8<-- [start:policy]
def unitsPerDegree : Int := 600_000
def maxLat : Int := 90 * unitsPerDegree
def maxLon : Int := 180 * unitsPerDegree
/-- AIS "not available" markers: latitude 91 degrees, longitude 181 degrees. -/
def latNotAvailable : Int := 91 * unitsPerDegree
def lonNotAvailable : Int := 181 * unitsPerDegree

/-- Axis-aligned box in AIS units. Boundaries belong to the zone. -/
structure Box where
  latMin : Int
  latMax : Int
  lonMin : Int
  lonMax : Int
  deriving Repr

/-- About 500 m around a fictional installation at 58 30.0'N 002 00.0'E. -/
def zone : Box :=
  { latMin := 35_097_300, latMax := 35_102_700, lonMin := 1_194_800, lonMax := 1_205_200 }

/-- A track with no report for this many seconds is lost ("gone dark").
Class A AIS reports every 3 minutes at anchor, faster when moving. -/
def staleAfter : Nat := 180
-- --8<-- [end:policy]

def Box.contains (b : Box) (lat lon : Int) : Bool :=
  decide (b.latMin ≤ lat ∧ lat ≤ b.latMax ∧ b.lonMin ≤ lon ∧ lon ≤ b.lonMax)

/-! ## Vocabulary -/

inductive AlarmState where
  | normal
  | unackActive
  | ackActive
  | unackCleared
  deriving DecidableEq, Repr, Inhabited

def AlarmState.all : List AlarmState := [.normal, .unackActive, .ackActive, .unackCleared]

/-- Canonical name, used on the wire and in generated code. -/
def AlarmState.name : AlarmState → String
  | .normal => "Normal"
  | .unackActive => "UnackActive"
  | .ackActive => "AckActive"
  | .unackCleared => "UnackCleared"

/-- The condition is present. -/
def AlarmState.isActive : AlarmState → Bool
  | .unackActive | .ackActive => true
  | .normal | .unackCleared => false

/-- An operator still has to acknowledge. -/
def AlarmState.isUnacked : AlarmState → Bool
  | .unackActive | .unackCleared => true
  | .normal | .ackActive => false

inductive ErrorCode where
  | positionUnavailable
  | invalidPosition
  | staleReport
  | nothingToAcknowledge
  deriving DecidableEq, Repr, Inhabited

def ErrorCode.all : List ErrorCode :=
  [.positionUnavailable, .invalidPosition, .staleReport, .nothingToAcknowledge]

def ErrorCode.name : ErrorCode → String
  | .positionUnavailable => "PositionUnavailable"
  | .invalidPosition => "InvalidPosition"
  | .staleReport => "StaleReport"
  | .nothingToAcknowledge => "NothingToAcknowledge"

/-- Messages the vessel-track actor accepts. -/
inductive Event where
  /-- AIS position report. `ts` is the receive time in seconds (assigned ashore). -/
  | report (ts : Nat) (lat lon : Int)
  /-- Operator acknowledges the alarm. -/
  | acknowledge
  /-- Vessel is (or is no longer) authorized to be inside the zone, e.g. a service vessel. -/
  | authorize (authorized : Bool)
  /-- Time passes. Sent periodically by a timer. -/
  | tick (now : Nat)
  deriving DecidableEq, Repr

def Event.kind : Event → String
  | .report .. => "Report"
  | .acknowledge => "Acknowledge"
  | .authorize .. => "Authorize"
  | .tick .. => "Tick"

-- --8<-- [start:track]
structure Track where
  /-- Receive time of the newest accepted report (0 = never reported). -/
  lastTs : Nat
  /-- Last known position is inside the zone. -/
  inside : Bool
  /-- No report for `staleAfter` seconds. -/
  lost : Bool
  authorized : Bool
  alarm : AlarmState
  deriving DecidableEq, Repr

def Track.new : Track :=
  { lastTs := 0, inside := false, lost := false, authorized := false, alarm := .normal }

/-- The alarm condition: an unauthorized vessel inside the zone. -/
def Track.intrusion (t : Track) : Bool := t.inside && !t.authorized
-- --8<-- [end:track]

/-! ## Behaviour -/

-- --8<-- [start:step]
/-- Alarm reaction to the current condition. Acknowledgement is never implied. -/
def AlarmState.onCondition : AlarmState → Bool → AlarmState
  | .normal, true => .unackActive
  | .unackCleared, true => .unackActive
  | .unackActive, false => .unackCleared
  | .ackActive, false => .normal
  | s, _ => s

def Track.evaluate (t : Track) : Track :=
  { t with alarm := t.alarm.onCondition t.intrusion }

def step (t : Track) : Event → Except ErrorCode Track
  | .report ts lat lon =>
    if lat = latNotAvailable ∨ lon = lonNotAvailable then .error .positionUnavailable
    else if lat < -maxLat ∨ lat > maxLat ∨ lon < -maxLon ∨ lon > maxLon then .error .invalidPosition
    else if ts ≤ t.lastTs then .error .staleReport
    else .ok ({ t with lastTs := ts, inside := zone.contains lat lon, lost := false }).evaluate
  | .acknowledge =>
    match t.alarm with
    | .unackActive => .ok { t with alarm := .ackActive }
    | .unackCleared => .ok { t with alarm := .normal }
    | .normal | .ackActive => .error .nothingToAcknowledge
  | .authorize a => .ok ({ t with authorized := a }).evaluate
  | .tick now =>
    if t.lastTs > 0 ∧ now ≥ t.lastTs + staleAfter then .ok { t with lost := true }
    else .ok t
-- --8<-- [end:step]

/-- Deliver messages like a real actor: a rejected message is reported and
the state stays as it was. Returns every intermediate result. -/
def replay (t : Track) : List Event → List (Except ErrorCode Track)
  | [] => []
  | e :: es =>
    match step t e with
    | .ok t' => .ok t' :: replay t' es
    | .error err => .error err :: replay t es

/-- The state after `replay`. -/
def replayState (t : Track) : List Event → Track
  | [] => t
  | e :: es =>
    match step t e with
    | .ok t' => replayState t' es
    | .error _ => replayState t es

end Truth.Zone
