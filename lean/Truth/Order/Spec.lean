/-!
# The Order domain – executable specification (the "truth")

This file is owned by architecture. It defines the vocabulary (types),
the policy constants and the *behaviour* (`step`) of an order aggregate.

Implementation teams (.NET, Go, …) do **not** import this file. They get:

* generated types/constants (`truth export` → `Contract.g.cs`, `contract_gen.go`),
* generated conformance vectors (`contracts/order/vectors.json`)
  that their implementation must reproduce exactly.

Everything here is deliberately boring, total and deterministic:
no IO, no clocks, no floating point. Money is in minor units (cents).
-/

namespace Truth.Order

/-- Semantic version of the specification. Bump on any behavioural change. -/
def specVersion : String := "1.0.0"

/-! ## Policy constants -/

-- --8<-- [start:policy]
/-- Orders with a total strictly above this amount need an explicit approval (four-eyes). -/
def approvalThreshold : Nat := 1_000_000 -- 10 000.00

def maxLines : Nat := 10
def maxQty : Nat := 10_000
def maxUnitPrice : Nat := 100_000_000 -- 1 000 000.00
-- --8<-- [end:policy]

/-! ## Vocabulary -/

inductive Status where
  | draft
  | pendingApproval
  | approved
  | shipped
  | cancelled
  deriving DecidableEq, Repr, Inhabited

def Status.all : List Status := [.draft, .pendingApproval, .approved, .shipped, .cancelled]

/-- Wire/canonical name, shared by every implementation. -/
def Status.name : Status → String
  | .draft => "Draft"
  | .pendingApproval => "PendingApproval"
  | .approved => "Approved"
  | .shipped => "Shipped"
  | .cancelled => "Cancelled"

/-- Statuses in which the order has been submitted and not cancelled. -/
def Status.isCommitted : Status → Bool
  | .pendingApproval | .approved | .shipped => true
  | .draft | .cancelled => false

inductive ErrorCode where
  | invalidQuantity
  | invalidPrice
  | tooManyLines
  | emptyOrder
  | invalidTransition
  deriving DecidableEq, Repr, Inhabited

def ErrorCode.all : List ErrorCode :=
  [.invalidQuantity, .invalidPrice, .tooManyLines, .emptyOrder, .invalidTransition]

def ErrorCode.name : ErrorCode → String
  | .invalidQuantity => "InvalidQuantity"
  | .invalidPrice => "InvalidPrice"
  | .tooManyLines => "TooManyLines"
  | .emptyOrder => "EmptyOrder"
  | .invalidTransition => "InvalidTransition"

structure Line where
  sku : String
  qty : Nat
  unitPrice : Nat
  deriving DecidableEq, Repr

def Line.amount (l : Line) : Nat := l.qty * l.unitPrice

inductive Event where
  | addLine (sku : String) (qty : Nat) (unitPrice : Nat)
  | submit
  | approve
  | reject
  | ship
  | cancel
  deriving DecidableEq, Repr

def Event.kind : Event → String
  | .addLine .. => "AddLine"
  | .submit => "Submit"
  | .approve => "Approve"
  | .reject => "Reject"
  | .ship => "Ship"
  | .cancel => "Cancel"

-- --8<-- [start:order]
structure Order where
  status : Status
  lines : List Line
  /-- `true` once a human approved the order (four-eyes principle). -/
  approved : Bool
  deriving DecidableEq, Repr

def Order.total (o : Order) : Nat := (o.lines.map Line.amount).sum

def Order.new : Order := { status := .draft, lines := [], approved := false }
-- --8<-- [end:order]

/-! ## Behaviour

`step` is the single source of truth for how an order reacts to an event.
A rejected command returns an error and leaves the order unchanged
(the type makes partial updates impossible).
-/

-- --8<-- [start:step]
def step (o : Order) : Event → Except ErrorCode Order
  | .addLine sku qty price =>
    if o.status ≠ .draft then .error .invalidTransition
    else if qty = 0 ∨ qty > maxQty then .error .invalidQuantity
    else if price = 0 ∨ price > maxUnitPrice then .error .invalidPrice
    else if o.lines.length ≥ maxLines then .error .tooManyLines
    else .ok { o with lines := o.lines ++ [⟨sku, qty, price⟩] }
  | .submit =>
    if o.status ≠ .draft then .error .invalidTransition
    else if o.lines = [] then .error .emptyOrder
    else if o.total > approvalThreshold then .ok { o with status := .pendingApproval }
    else .ok { o with status := .approved }
  | .approve =>
    if o.status = .pendingApproval then .ok { o with status := .approved, approved := true }
    else .error .invalidTransition
  | .reject =>
    if o.status = .pendingApproval then .ok { o with status := .draft }
    else .error .invalidTransition
  | .ship =>
    if o.status = .approved then .ok { o with status := .shipped }
    else .error .invalidTransition
  | .cancel =>
    if o.status = .shipped ∨ o.status = .cancelled then .error .invalidTransition
    else .ok { o with status := .cancelled }
-- --8<-- [end:step]

/-- Apply events, stopping at the first error. -/
def run (o : Order) : List Event → Except ErrorCode Order
  | [] => .ok o
  | e :: es => do run (← step o e) es

/-- Apply events like a real service would: a rejected command is reported
and the order keeps its previous state. Returns every intermediate result. -/
def replay (o : Order) : List Event → List (Except ErrorCode Order)
  | [] => []
  | e :: es =>
    match step o e with
    | .ok o' => .ok o' :: replay o' es
    | .error err => .error err :: replay o es

/-- The state after `replay` (errors skip the event). -/
def replayState (o : Order) : List Event → Order
  | [] => o
  | e :: es =>
    match step o e with
    | .ok o' => replayState o' es
    | .error _ => replayState o es

end Truth.Order
