import Truth.Zone.Spec
import Truth.Export.Common

/-!
# Zone exporter: vectors, manifest, C#, Go and a reference page

The spec is executable, so it is its own test oracle. We feed it message
sequences and record every answer. Implementations must reproduce them.
-/

namespace Truth.Export.Zone
open Truth.Zone Truth.Export

/-! ## Wire format -/

def encodeEvent : Event → Json
  | .report ts lat lon => .obj [("type", .str "Report"), ("ts", .num ts), ("lat", .int lat), ("lon", .int lon)]
  | .acknowledge => .obj [("type", .str "Acknowledge")]
  | .authorize a => .obj [("type", .str "Authorize"), ("authorized", .bool a)]
  | .tick now => .obj [("type", .str "Tick"), ("now", .num now)]

def encodeResult : Except ErrorCode Track → Json
  | .ok t => .obj [("ok", .bool true), ("alarm", .str t.alarm.name), ("inside", .bool t.inside),
                   ("lost", .bool t.lost), ("authorized", .bool t.authorized), ("lastTs", .num t.lastTs)]
  | .error e => .obj [("ok", .bool false), ("error", .str e.name)]

structure Trace where
  name : String
  events : List Event

def encodeTrace (t : Trace) : Json :=
  .obj [("name", .str t.name),
        ("steps", .arr ((t.events.zip (replay Track.new t.events)).map fun (e, r) =>
          .obj [("event", encodeEvent e), ("expect", encodeResult r)]))]

/-! ## Positions used by scenarios and the generator -/

def centerLat : Int := 35_100_000
def centerLon : Int := 1_200_000
def farLat : Int := 35_400_000

def at_ (ts : Nat) (lat : Int := centerLat) (lon : Int := centerLon) : Event := .report ts lat lon
def away (ts : Nat) : Event := .report ts farLat centerLon

/-! ## Hand-written scenarios (named, readable, reviewed like documentation) -/

def scenarios : List Trace := [
  { name := "intrusion raises an alarm; acknowledged; leaving clears it"
    events := [at_ 100, .acknowledge, away 110] },
  { name := "vessel leaves before acknowledgement: alarm waits for the operator"
    events := [at_ 100, away 110, .acknowledge] },
  { name := "re-entry before acknowledgement re-activates the alarm"
    events := [at_ 100, away 110, at_ 120] },
  { name := "authorized service vessel never raises an alarm"
    events := [.authorize true, at_ 100, at_ 110, .authorize false] },
  { name := "permit granted during an intrusion still needs acknowledgement"
    events := [at_ 100, .authorize true, .acknowledge] },
  { name := "going dark keeps the alarm"
    events := [at_ 100, .tick (100 + staleAfter - 1), .tick (100 + staleAfter), .acknowledge,
               away 400] },
  { name := "duplicated report is rejected as stale"
    events := [at_ 100, at_ 100] },
  { name := "late intrusion report is ignored"
    events := [away 160, at_ 100] },
  { name := "zone boundary belongs to the zone"
    events := [at_ 100 zone.latMin, at_ 110 (zone.latMin - 1), at_ 120 centerLat zone.lonMax,
               at_ 130 centerLat (zone.lonMax + 1)] },
  { name := "position not available and invalid positions"
    events := [at_ 100 latNotAvailable, at_ 101 centerLat lonNotAvailable, at_ 102 (maxLat + 1),
               at_ 103 centerLat (-maxLon - 1), at_ 104 (-maxLat) (-maxLon)] },
  { name := "nothing to acknowledge"
    events := [.acknowledge, at_ 100, .acknowledge, .acknowledge] },
  { name := "tick before any report never marks the track lost"
    events := [.tick 1_000] }
]

-- Spec-level unit tests, checked at build time.
#guard (replayState Track.new [at_ 100, away 110]).alarm == .unackCleared
#guard (replayState Track.new [.authorize true, at_ 100]).alarm == .normal
#guard (replayState Track.new [at_ 100, .tick 280]).lost

/-! ## Generated traces -/

def positions : List (Int × Int) := [
  (centerLat, centerLon), (centerLat, centerLon), (zone.latMax, centerLon), (zone.latMax + 1, centerLon),
  (centerLat, zone.lonMin), (centerLat, zone.lonMin - 1), (farLat, centerLon), (farLat, -centerLon),
  (latNotAvailable, centerLon), (centerLat, lonNotAvailable), (maxLat + 1, 0), (-maxLat, -maxLon)]

/-- `clock` is the generator's notion of "now". Most reports move it forward;
some are duplicated or late on purpose. -/
def genEvent (clock : Nat) (r : Rng) : Event × Nat × Rng :=
  let (k, r) := r.below 20
  if k < 10 then
    let (mode, r) := r.below 10
    let (dt, r) := r.pick [1, 5, 30, staleAfter + 20]
    let ts := if mode < 8 then clock + dt else if mode = 8 then clock else clock - min clock 15
    let (pos, r) := r.pick positions
    (.report ts pos.1 pos.2, max clock ts, r)
  else if k < 13 then (.acknowledge, clock, r)
  else if k < 15 then
    let (b, r) := r.pick [true, false]
    (.authorize b, clock, r)
  else
    let (dt, r) := r.pick [0, staleAfter - 1, staleAfter, 1_000]
    (.tick (clock + dt), clock, r)

def genTrace : Nat → Nat → Rng → List Event × Rng
  | 0, _, r => ([], r)
  | n + 1, clock, r =>
    let (e, clock, r) := genEvent clock r
    let (es, r) := genTrace n clock r
    (e :: es, r)

def generated (count : Nat) (seed : UInt64) : List Trace :=
  go count ⟨seed⟩ []
where
  go : Nat → Rng → List Trace → List Trace
    | 0, _, acc => acc.reverse
    | n + 1, r, acc =>
      let (len, r) := r.below 20
      let (es, r) := genTrace (4 + len) 1 r
      go n r ({ name := s!"generated #{count - n}", events := es } :: acc)

def seed : UInt64 := 58300200
def traceCount : Nat := 300

def vectors : Json :=
  .obj [("specVersion", .str specVersion), ("seed", .num seed.toNat),
        ("traces", .arr ((scenarios ++ generated traceCount seed).map encodeTrace))]

/-! ## Manifest and code -/

/-- (wire name, value, documentation). The documentation flows into C# and Go. -/
def constants : List (String × Int × String) := [
  ("unitsPerDegree", unitsPerDegree, "the number of AIS position units (1/10 000 minute) per degree."),
  ("maxLat", maxLat, "the largest valid latitude (90 degrees) in AIS units."),
  ("maxLon", maxLon, "the largest valid longitude (180 degrees) in AIS units."),
  ("latNotAvailable", latNotAvailable, "the AIS marker for latitude not available (91 degrees)."),
  ("lonNotAvailable", lonNotAvailable, "the AIS marker for longitude not available (181 degrees)."),
  ("zoneLatMin", zone.latMin, "the southern boundary of the safety zone, inclusive."),
  ("zoneLatMax", zone.latMax, "the northern boundary of the safety zone, inclusive."),
  ("zoneLonMin", zone.lonMin, "the western boundary of the safety zone, inclusive."),
  ("zoneLonMax", zone.lonMax, "the eastern boundary of the safety zone, inclusive."),
  ("staleAfter", staleAfter, "the number of seconds without a report after which a track is lost.")]

def capitalize (s : String) : String :=
  match s.toList with
  | c :: cs => String.ofList (c.toUpper :: cs)
  | [] => s

def manifest : Json :=
  .obj [("specVersion", .str specVersion),
        ("constants", .obj (constants.map fun (n, v, _) => (n, .int v))),
        ("alarmStates", .arr (AlarmState.all.map (.str ·.name))),
        ("errorCodes", .arr (ErrorCode.all.map (.str ·.name))),
        ("events", .arr [
          .obj [("type", .str "Report"), ("fields", .arr [.str "ts", .str "lat", .str "lon"])],
          .obj [("type", .str "Acknowledge")],
          .obj [("type", .str "Authorize"), ("fields", .arr [.str "authorized"])],
          .obj [("type", .str "Tick"), ("fields", .arr [.str "now"])]])]

def csharp : String :=
  csHeader "Zone" specVersion ++ "namespace Surveillance.Zone;\n\n" ++
  csEnum "AlarmState" "Alarm lifecycle (IEC 62682 style). Names are the wire format." (AlarmState.all.map AlarmState.name) ++
  csEnum "ErrorCode" "Why a message was rejected." (ErrorCode.all.map ErrorCode.name) ++
  csPolicy specVersion (constants.map fun (n, v, d) => { name := capitalize n, value := toString v, doc := d })

def golang : String :=
  goHeader "Zone" specVersion "zone" ++
  goEnum "AlarmState" "is the alarm lifecycle state (IEC 62682 style). Values are the wire format."
    "Alarm" "AllAlarmStates" (AlarmState.all.map AlarmState.name) ++
  goEnum "ErrorCode" "says why a message was rejected." "Err" "AllErrorCodes" (ErrorCode.all.map ErrorCode.name) ++
  goPolicy specVersion (constants.map fun (n, v, d) => { name := capitalize n, value := toString v, doc := d })

/-! ## Reference page: the alarm state machine, derived by running `step` -/

def sampleTrack (s : AlarmState) (inside authorized : Bool) : Track :=
  { lastTs := 100, inside, lost := false, authorized, alarm := s }

def probes : List (String × Event) := [
  ("report inside", at_ 200), ("report outside", away 200),
  ("acknowledge", .acknowledge), ("authorize", .authorize true), ("revoke", .authorize false),
  ("tick (dark)", .tick 1_000)]

/-- Consistent sample tracks for each alarm state (the invariant tells us which exist). -/
def samplesFor : AlarmState → List Track
  | .normal => [sampleTrack .normal false false, sampleTrack .normal true true]
  | .unackActive => [sampleTrack .unackActive true false]
  | .ackActive => [sampleTrack .ackActive true false]
  | .unackCleared => [sampleTrack .unackCleared false false, sampleTrack .unackCleared true true]

def outcome (t : Track) (e : Event) : String :=
  match step t e with
  | .ok t' => t'.alarm.name
  | .error err => s!"x {err.name}"

def mermaid : String := Id.run do
  let mut edges : List String := []
  for s in AlarmState.all do
    for (label, e) in probes do
      for t in samplesFor s do
        if let .ok t' := step t e then
          if t'.alarm != s then
            let edge := s!"    {s.name} --> {t'.alarm.name} : {label}"
            if !edges.contains edge then edges := edges ++ [edge]
  return "```mermaid\nstateDiagram-v2\n    [*] --> Normal\n" ++ "\n".intercalate edges ++ "\n```\n"

def table : String :=
  mdTable ("Alarm state" :: probes.map (·.1))
    (AlarmState.all.map fun s =>
      s!"**{s.name}**" :: probes.map fun (_, e) =>
        " / ".intercalate ((samplesFor s).map (outcome · e)).eraseDups)

def doc : String :=
  mdHeader "Zone" specVersion ++
  s!"# Safety zone alarm (spec {specVersion})\n\n" ++
  "!!! info \"Generated from the specification\"\n" ++
  "    This page is produced by running `step` from `lean/Truth/Zone/Spec.lean` on sample tracks.\n" ++
  "    CI regenerates it and fails on any difference, so it cannot drift from the spec.\n\n" ++
  "## Alarm state machine\n\n" ++ mermaid ++ "\n" ++
  "## Reaction table\n\n" ++
  "Rows are alarm states. Columns are messages. A state can hold for two kinds of track.\n" ++
  "Where two outcomes are shown, the first is for an unauthorized vessel outside the zone,\n" ++
  "the second for an authorized vessel inside it.\n\n" ++
  table ++ "\n" ++
  "## Policy constants\n\n" ++
  "Positions are in AIS units of 1/10 000 minute (600 000 per degree).\n\n" ++
  mdTable ["Constant", "Value", "Meaning"] (constants.map fun (n, v, d) => [s!"`{n}`", toString v, d]) ++ "\n" ++
  "## Error codes\n\n" ++ String.join (ErrorCode.all.map fun e => s!"- `{e.name}`\n")

end Truth.Export.Zone
