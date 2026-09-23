// Package orders is the "Go team" implementation of the Order domain.
//
// Types and constants come from contract_gen.go (generated from the Lean spec);
// the behaviour below is hand-written and checked by conformance_test.go
// against contracts/order/vectors.json.
package orders

// Line is a single order line. Amounts are in minor units (cents).
type Line struct {
	SKU       string
	Qty       int64
	UnitPrice int64
}

// Amount is qty × unit price.
func (l Line) Amount() int64 { return l.Qty * l.UnitPrice }

// Event is a command sent to an order.
type Event interface{ kind() string }

type (
	AddLine struct {
		SKU       string
		Qty       int64
		UnitPrice int64
	}
	Submit  struct{}
	Approve struct{}
	Reject  struct{}
	Ship    struct{}
	Cancel  struct{}
)

func (AddLine) kind() string { return "AddLine" }
func (Submit) kind() string  { return "Submit" }
func (Approve) kind() string { return "Approve" }
func (Reject) kind() string  { return "Reject" }
func (Ship) kind() string    { return "Ship" }
func (Cancel) kind() string  { return "Cancel" }

// Order is a value type; Apply returns a new Order and never mutates the receiver.
type Order struct {
	Status   Status
	Lines    []Line
	Approved bool
}

// New returns an empty draft order.
func New() Order { return Order{Status: StatusDraft} }

// Total is the sum of all line amounts.
func (o Order) Total() int64 {
	var t int64
	for _, l := range o.Lines {
		t += l.Amount()
	}
	return t
}

// Apply handles an event. On error the returned order is the unchanged receiver.
func (o Order) Apply(e Event) (Order, *ErrorCode) {
	switch ev := e.(type) {
	case AddLine:
		return o.addLine(ev)
	case Submit:
		if o.Status != StatusDraft {
			return o.fail(ErrInvalidTransition)
		}
		if len(o.Lines) == 0 {
			return o.fail(ErrEmptyOrder)
		}
		if o.Total() > ApprovalThreshold {
			return o.with(StatusPendingApproval), nil
		}
		return o.with(StatusApproved), nil
	case Approve:
		if o.Status != StatusPendingApproval {
			return o.fail(ErrInvalidTransition)
		}
		n := o.with(StatusApproved)
		n.Approved = true
		return n, nil
	case Reject:
		if o.Status != StatusPendingApproval {
			return o.fail(ErrInvalidTransition)
		}
		return o.with(StatusDraft), nil
	case Ship:
		if o.Status != StatusApproved {
			return o.fail(ErrInvalidTransition)
		}
		return o.with(StatusShipped), nil
	case Cancel:
		if o.Status == StatusShipped || o.Status == StatusCancelled {
			return o.fail(ErrInvalidTransition)
		}
		return o.with(StatusCancelled), nil
	default:
		panic("unknown event")
	}
}

func (o Order) addLine(ev AddLine) (Order, *ErrorCode) {
	switch {
	case o.Status != StatusDraft:
		return o.fail(ErrInvalidTransition)
	case ev.Qty <= 0 || ev.Qty > MaxQty:
		return o.fail(ErrInvalidQuantity)
	case ev.UnitPrice <= 0 || ev.UnitPrice > MaxUnitPrice:
		return o.fail(ErrInvalidPrice)
	case len(o.Lines) >= MaxLines:
		return o.fail(ErrTooManyLines)
	}
	n := o
	n.Lines = append(append([]Line(nil), o.Lines...), Line{ev.SKU, ev.Qty, ev.UnitPrice})
	return n, nil
}

func (o Order) with(s Status) Order {
	o.Status = s
	return o
}

func (o Order) fail(code ErrorCode) (Order, *ErrorCode) { return o, &code }
