/-!
# Replicated site health view - executable specification

A site runs a primary and a standby platform instance. Both probe the same
service units and publish health reports. Reports travel over a constrained
network: they arrive late, out of order, and more than once. Each instance
keeps its own **view** of the site.

The requirement: two instances that received the same reports, in any
order, with any duplicates, must show the same view. Otherwise operators
on two consoles see two different truths.

The design is a state-based CRDT (a join-semilattice):

* a view keeps, per unit, the "best" report seen so far,
* "best" is a total order: newer wins, on a tie the worse health wins,
* receiving a report is a join, and joins commute and are idempotent.

`Properties.lean` proves the convergence requirement from these laws.
-/

namespace Truth.Health

/-- Semantic version of this specification. Bump on any behavioural change. -/
def specVersion : String := "1.0.0"

/-! ## Policy -/

-- --8<-- [start:policy]
/-- Service units at the site. Every instance is built with the same list in the same order. -/
def siteUnits : Nat := 4
/-- Seconds between two probes of a unit. -/
def probeInterval : Nat := 10
/-- Seconds a probe may take. -/
def probeTimeout : Nat := 3
/-- A report older than this is not evidence any more: one missed probe is
tolerated, two are not. Every receiver expires a report at the same age. -/
def freshFor : Nat := 2 * probeInterval + probeTimeout
-- --8<-- [end:policy]

/-! ## Vocabulary -/

inductive Health where
  | healthy
  | degraded
  | unhealthy
  deriving DecidableEq, Repr, Inhabited

def Health.all : List Health := [.healthy, .degraded, .unhealthy]

/-- Severity: higher is worse. -/
def Health.rank : Health → Nat
  | .healthy => 0
  | .degraded => 1
  | .unhealthy => 2

def Health.name : Health → String
  | .healthy => "Healthy"
  | .degraded => "Degraded"
  | .unhealthy => "Unhealthy"

inductive Observer where
  | primary
  | standby
  deriving DecidableEq, Repr, Inhabited

def Observer.all : List Observer := [.primary, .standby]

def Observer.rank : Observer → Nat
  | .primary => 0
  | .standby => 1

def Observer.name : Observer → String
  | .primary => "Primary"
  | .standby => "Standby"

/-- What an operator console shows for a unit. -/
inductive Status where
  | healthy
  | degraded
  | unhealthy
  | unknown
  deriving DecidableEq, Repr, Inhabited

def Status.all : List Status := [.healthy, .degraded, .unhealthy, .unknown]

def Status.name : Status → String
  | .healthy => "Healthy"
  | .degraded => "Degraded"
  | .unhealthy => "Unhealthy"
  | .unknown => "Unknown"

def Health.toStatus : Health → Status
  | .healthy => .healthy
  | .degraded => .degraded
  | .unhealthy => .unhealthy

inductive ErrorCode where
  | unknownUnit
  deriving DecidableEq, Repr, Inhabited

def ErrorCode.all : List ErrorCode := [.unknownUnit]

def ErrorCode.name : ErrorCode → String
  | .unknownUnit => "UnknownUnit"

-- --8<-- [start:report]
structure Report where
  unit : Nat
  /-- Probe time in seconds. -/
  ts : Nat
  health : Health
  observer : Observer
  deriving DecidableEq, Repr

/-- The total order that decides which report wins:
1. the newer report,
2. on equal time, the worse health (a disagreement never hides a failure),
3. then observer, then unit, so that no two different reports tie. -/
def Report.lt (a b : Report) : Prop :=
  a.ts < b.ts ∨ (a.ts = b.ts ∧
    (a.health.rank < b.health.rank ∨ (a.health.rank = b.health.rank ∧
      (a.observer.rank < b.observer.rank ∨ (a.observer.rank = b.observer.rank ∧
        a.unit < b.unit)))))
-- --8<-- [end:report]

instance (a b : Report) : Decidable (Report.lt a b) := by
  unfold Report.lt; infer_instance

/-! ## Behaviour -/

-- --8<-- [start:view]
/-- The better of two optional reports (the semilattice join). -/
def join : Option Report → Option Report → Option Report
  | none, b => b
  | some a, none => some a
  | some a, some b => if Report.lt a b then some b else some a

/-- A view maps each unit index to the best report seen for it. -/
abbrev View := Nat → Option Report

def View.empty : View := fun _ => none

/-- Receive one report (a one-entry delta). -/
def receive (v : View) (r : Report) : Except ErrorCode View :=
  if r.unit < siteUnits then .ok fun u => if u = r.unit then join (v u) (some r) else v u
  else .error .unknownUnit

/-- Merge two whole views (anti-entropy between primary and standby). -/
def merge (v w : View) : View := fun u => join (v u) (w u)

/-- What the console shows for unit `u` at time `now`. -/
def status (v : View) (now u : Nat) : Status :=
  match v u with
  | none => .unknown
  | some r => if now > r.ts + freshFor then .unknown else r.health.toStatus
-- --8<-- [end:view]

/-- Receive, ignoring rejected reports (what a replica does with its inbox). -/
def ingest (v : View) (r : Report) : View :=
  match receive v r with
  | .ok w => w
  | .error _ => v

/-- A replica that starts empty and receives `rs` in this order. -/
def deliver (rs : List Report) : View := rs.foldl ingest View.empty

end Truth.Health
