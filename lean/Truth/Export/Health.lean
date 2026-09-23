import Truth.Health.Spec
import Truth.Export.Common

/-!
# Health exporter: vectors, manifest, C#, Go and a reference page

Two kinds of vectors:

* `traces` - one replica receives reports and answers queries, step by step,
* `convergence` - the same reports delivered to two replicas in two different
  orders with duplicates, plus a split inbox that is merged (anti-entropy).
  Every implementation must end with the expected view in all three cases.
  The theorems `convergence` and `merge_deliver` guarantee the spec does.
-/

namespace Truth.Export.Health
open Truth.Health Truth.Export

/-! ## Wire format -/

def encodeReport (r : Report) : Json :=
  .obj [("type", .str "Report"), ("unit", .num r.unit), ("ts", .num r.ts),
        ("health", .str r.health.name), ("observer", .str r.observer.name)]

def encodeView (v : View) : Json :=
  .arr ((List.range siteUnits).map fun u =>
    match v u with
    | none => .null
    | some r => .obj [("ts", .num r.ts), ("health", .str r.health.name), ("observer", .str r.observer.name)])

inductive Msg where
  | report (r : Report)
  | query (now : Nat)

def encodeMsg : Msg → Json
  | .report r => encodeReport r
  | .query now => .obj [("type", .str "Query"), ("now", .num now)]

/-- Replay one replica; errors leave the view unchanged. -/
def replay (v : View) : List Msg → List Json
  | [] => []
  | .report r :: ms =>
    match receive v r with
    | .ok w => .obj [("ok", .bool true), ("view", encodeView w)] :: replay w ms
    | .error e => .obj [("ok", .bool false), ("error", .str e.name)] :: replay v ms
  | .query now :: ms =>
    .obj [("ok", .bool true), ("statuses", .arr ((List.range siteUnits).map fun u =>
      .str (status v now u).name))] :: replay v ms

structure Trace where
  name : String
  msgs : List Msg

def encodeTrace (t : Trace) : Json :=
  .obj [("name", .str t.name),
        ("steps", .arr ((t.msgs.zip (replay View.empty t.msgs)).map fun (m, e) =>
          .obj [("event", encodeMsg m), ("expect", e)]))]

/-! ## Scenarios -/

def rep (unit ts : Nat) (h : Health) (o : Observer := .primary) : Msg := .report ⟨unit, ts, h, o⟩

def scenarios : List Trace := [
  { name := "newer report wins"
    msgs := [rep 0 10 .unhealthy, rep 0 20 .healthy, .query 20] },
  { name := "late report never rolls the view back"
    msgs := [rep 0 20 .healthy, rep 0 10 .unhealthy, .query 20] },
  { name := "on equal time the worse report wins, whichever arrives first"
    msgs := [rep 1 10 .healthy .primary, rep 1 10 .unhealthy .standby, rep 1 10 .healthy .primary,
             rep 2 10 .unhealthy .standby, rep 2 10 .degraded .primary, .query 10] },
  { name := "exact tie on health: standby breaks the tie"
    msgs := [rep 3 10 .degraded .primary, rep 3 10 .degraded .standby] },
  { name := "unknown unit is rejected"
    msgs := [rep siteUnits 10 .healthy, rep (siteUnits + 7) 10 .healthy] },
  { name := "freshness: silence is not health"
    msgs := [.query 0, rep 0 100 .healthy, .query (100 + freshFor), .query (100 + freshFor + 1)] },
  { name := "duplicate delivery changes nothing"
    msgs := [rep 0 10 .degraded, rep 0 10 .degraded, rep 0 10 .degraded] }
]

#guard (status (deliver [⟨0, 10, .healthy, .primary⟩, ⟨0, 10, .unhealthy, .standby⟩]) 10 0) == .unhealthy
#guard (status (deliver [⟨0, 10, .healthy, .primary⟩]) (10 + freshFor + 1) 0) == .unknown

/-! ## Generated traces -/

def genReport (clock : Nat) (r : Rng) : Report × Rng :=
  let (unit, r) := r.below (siteUnits + 1)                -- siteUnits itself is invalid
  let (back, r) := r.pick [0, 0, 1, 5, 15]
  let (h, r) := r.pick Health.all
  let (o, r) := r.pick Observer.all
  (⟨unit, clock - min clock back, h, o⟩, r)

def genMsgs : Nat → Nat → Rng → List Msg × Rng
  | 0, _, r => ([], r)
  | n + 1, clock, r =>
    let (k, r) := r.below 10
    let (dt, r) := r.pick [0, 1, 3, 10]
    let clock := clock + dt
    if k < 7 then
      let (rp, r) := genReport clock r
      let (ms, r) := genMsgs n clock r
      (.report rp :: ms, r)
    else
      let (ahead, r) := r.pick [0, freshFor, freshFor + 1, 100]
      let (ms, r) := genMsgs n clock r
      (.query (clock + ahead) :: ms, r)

def generated (count : Nat) (seed : UInt64) : List Trace :=
  go count ⟨seed⟩ []
where
  go : Nat → Rng → List Trace → List Trace
    | 0, _, acc => acc.reverse
    | n + 1, r, acc =>
      let (len, r) := r.below 20
      let (ms, r) := genMsgs (4 + len) 20 r
      go n r ({ name := s!"generated #{count - n}", msgs := ms } :: acc)

/-! ## Convergence cases -/

/-- Shuffle by repeatedly removing a random element. -/
def shuffle {α} [Inhabited α] (xs : List α) (r : Rng) : List α × Rng :=
  go xs.length xs [] r
where
  go : Nat → List α → List α → Rng → List α × Rng
    | 0, _, acc, r => (acc, r)
    | n + 1, xs, acc, r =>
      let (i, r) := r.below xs.length
      go n (xs.eraseIdx i) (xs[i]! :: acc) r

instance : Inhabited Report := ⟨⟨0, 0, .healthy, .primary⟩⟩

/-- A random inbox containing every report of `set` at least once, in random order. -/
def inbox (set : List Report) (r : Rng) : List Report × Rng :=
  let (dups, r) := r.below (set.length + 1)
  let (extra, r) := shuffle set r
  shuffle (set ++ extra.take dups) r

def convergenceCase (i : Nat) (r : Rng) : Json × Rng :=
  let (n, r) := r.below 12
  let rec reports : Nat → Rng → List Report × Rng
    | 0, r => ([], r)
    | k + 1, r =>
      let (t, r) := r.below 40
      let (rp, r) := genReport (10 + t) r
      let (rest, r) := reports k r
      (rp :: rest, r)
  let (set, r) := reports (n + 1) r
  let (a, r) := inbox set r
  let (b, r) := inbox set r
  let split := a.length / 2
  let expect := deliver a
  -- The theorems say these agree; the exporter double-checks before writing.
  let checks := [encodeView (deliver b), encodeView (merge (deliver (a.take split)) (deliver (a.drop split)))]
  if checks.any (·.compact != (encodeView expect).compact) then
    panic! s!"convergence case {i}: spec disagrees with its own theorem"
  else
  (.obj [("name", .str s!"convergence #{i}"),
         ("inboxA", .arr (a.map encodeReport)), ("inboxB", .arr (b.map encodeReport)),
         ("split", .num split), ("expect", encodeView expect)], r)

def convergenceCases (count : Nat) (seed : UInt64) : List Json :=
  go 1 count ⟨seed⟩ []
where
  go : Nat → Nat → Rng → List Json → List Json
    | _, 0, _, acc => acc.reverse
    | i, n + 1, r, acc =>
      let (c, r) := convergenceCase i r
      go (i + 1) n r (c :: acc)

def seed : UInt64 := 20230101
def traceCount : Nat := 150
def caseCount : Nat := 60

def vectors : Json :=
  .obj [("specVersion", .str specVersion), ("seed", .num seed.toNat),
        ("traces", .arr ((scenarios ++ generated traceCount seed).map encodeTrace)),
        ("convergence", .arr (convergenceCases caseCount (seed + 1)))]

/-! ## Manifest and code -/

/-- (wire name, value, documentation). The documentation flows into C# and Go. -/
def constants : List (String × Nat × String) := [
  ("siteUnits", siteUnits, "the number of service units at the site, identical on every instance."),
  ("probeInterval", probeInterval, "the number of seconds between two probes of a unit."),
  ("probeTimeout", probeTimeout, "the number of seconds a probe may take."),
  ("freshFor", freshFor, "the number of seconds a report stays evidence: 2 * probeInterval + probeTimeout.")]

def toConst : String × Nat × String → Const
  | (n, v, d) => { name := n.capitalize, value := toString v, doc := d, csType := "int",
                   -- siteUnits sizes arrays and indexes units, so it is an int in Go.
                   goType := if n == "siteUnits" then "int" else "int64" }

def capitalize (s : String) : String :=
  match s.toList with
  | c :: cs => String.ofList (c.toUpper :: cs)
  | [] => s

def manifest : Json :=
  .obj [("specVersion", .str specVersion),
        ("constants", .obj (constants.map fun (n, v, _) => (n, .num v))),
        ("health", .arr (Health.all.map (.str ·.name))),
        ("observers", .arr (Observer.all.map (.str ·.name))),
        ("statuses", .arr (Status.all.map (.str ·.name))),
        ("errorCodes", .arr (ErrorCode.all.map (.str ·.name))),
        ("ordering", .arr [.str "ts", .str "health (worse wins)", .str "observer", .str "unit"])]

def csharp : String :=
  csHeader "Health" specVersion ++ "namespace Surveillance.Health;\n\n" ++
  csEnum "Health" "Probe result, ordered by severity (worse is greater)." (Health.all.map Health.name) ++
  csEnum "Observer" "Platform instance that produced a report." (Observer.all.map Observer.name) ++
  csEnum "Status" "What an operator console shows for a unit." (Status.all.map Status.name) ++
  csEnum "ErrorCode" "Why a report was rejected." (ErrorCode.all.map ErrorCode.name) ++
  csPolicy specVersion (constants.map toConst)

def golang : String :=
  goHeader "Health" specVersion "health" ++
  goEnum "Health" "is a probe result, ordered by severity (worse is greater)." "Health" "AllHealth"
    (Health.all.map Health.name) ++
  goEnum "Observer" "is the platform instance that produced a report." "Observer" "AllObservers"
    (Observer.all.map Observer.name) ++
  goEnum "Status" "is what an operator console shows for a unit." "Status" "AllStatuses"
    (Status.all.map Status.name) ++
  goEnum "ErrorCode" "says why a report was rejected." "Err" "AllErrorCodes" (ErrorCode.all.map ErrorCode.name) ++
  goPolicy specVersion (constants.map toConst)

/-! ## Reference page, derived by running the spec -/

def winner (a b : Health) (oa ob : Observer) : String :=
  match join (some ⟨0, 10, a, oa⟩) (some ⟨0, 10, b, ob⟩) with
  | some r => s!"{r.health.name} ({r.observer.name})"
  | none => "-"

def doc : String :=
  mdHeader "Health" specVersion ++
  s!"# Site health view (spec {specVersion})\n\n" ++
  "!!! info \"Generated from the specification\"\n" ++
  "    This page is produced by running `join` and `status` from `lean/Truth/Health/Spec.lean`.\n" ++
  "    CI regenerates it and fails on any difference.\n\n" ++
  "## Which report wins at equal probe time\n\n" ++
  "Primary reported the row value, standby reported the column value, both at the same time.\n\n" ++
  mdTable ("primary \\ standby" :: Health.all.map Health.name)
    (Health.all.map fun a => s!"**{a.name}**" :: Health.all.map fun b => winner a b .primary .standby) ++ "\n" ++
  "## Freshness\n\n" ++
  s!"A report is evidence for `freshFor = 2 * probeInterval + probeTimeout = {freshFor}` seconds.\n\n" ++
  mdTable ["Age of newest report (s)", "Status shown"]
    ([0, freshFor, freshFor + 1].map fun age =>
      [toString age, (status (deliver [⟨0, 100, .healthy, .primary⟩]) (100 + age) 0).name]) ++
  "| no report | " ++ (status View.empty 0 0).name ++ " |\n\n" ++
  "## Policy constants\n\n" ++
  mdTable ["Constant", "Value", "Meaning"] (constants.map fun (n, v, d) => [s!"`{n}`", toString v, d]) ++ "\n" ++
  "## Error codes\n\n" ++ String.join (ErrorCode.all.map fun e => s!"- `{e.name}`\n")

end Truth.Export.Health
