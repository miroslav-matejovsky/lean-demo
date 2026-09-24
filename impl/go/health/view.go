package health

import "fmt"

// Report is one probe result for one unit.
type Report struct {
	Unit int
	// TS is the probe time in seconds.
	TS       int64
	Health   Health
	Observer Observer
}

// Entry is the best report known for one unit. Present is false until a report arrives.
type Entry struct {
	Report  Report
	Present bool
}

// View is one replica's picture of the site. It is a comparable value:
// two views are equal exactly when every unit shows the same report.
type View struct {
	entries [SiteUnits]Entry
}

// RejectedError is a business rejection. The view is unchanged.
type RejectedError struct {
	Code ErrorCode
}

func (e *RejectedError) Error() string { return "health: rejected: " + string(e.Code) }

// Entry returns the best report known for unit. Unknown units have no entry.
func (v View) Entry(unit int) Entry {
	if unit < 0 || unit >= SiteUnits {
		return Entry{}
	}
	return v.entries[unit]
}

// Receive merges one report into the view (a one-entry delta).
func (v View) Receive(r Report) (View, error) {
	if r.Unit < 0 || r.Unit >= SiteUnits {
		return v, &RejectedError{Code: ErrUnknownUnit}
	}
	v.entries[r.Unit] = join(v.entries[r.Unit], Entry{Report: r, Present: true})
	return v, nil
}

// Merge combines two replicas (anti-entropy). Merge is commutative,
// associative and idempotent, so replicas may sync in any direction.
func (v View) Merge(other View) View {
	for u := range v.entries {
		v.entries[u] = join(v.entries[u], other.entries[u])
	}
	return v
}

// Status is what an operator console shows for unit at time now.
// A missing or expired report is Unknown: silence is not health.
func (v View) Status(now int64, unit int) Status {
	e := v.Entry(unit)
	if !e.Present || now > e.Report.TS+FreshFor {
		return StatusUnknown
	}
	switch e.Report.Health {
	case HealthHealthy:
		return StatusHealthy
	case HealthDegraded:
		return StatusDegraded
	case HealthUnhealthy:
		return StatusUnhealthy
	}
	panic(fmt.Sprintf("health: unknown health %q", e.Report.Health))
}

func join(a, b Entry) Entry {
	switch {
	case !a.Present:
		return b
	case !b.Present:
		return a
	case less(a.Report, b.Report):
		return b
	default:
		return a
	}
}

// less is the total order that decides which report wins.
func less(a, b Report) bool {
	if a.TS != b.TS {
		return a.TS < b.TS
	}
	if ha, hb := healthRank(a.Health), healthRank(b.Health); ha != hb {
		return ha < hb
	}
	if oa, ob := observerRank(a.Observer), observerRank(b.Observer); oa != ob {
		return oa < ob
	}
	return a.Unit < b.Unit
}

// healthRank orders by severity: higher is worse.
func healthRank(h Health) int {
	switch h {
	case HealthHealthy:
		return 0
	case HealthDegraded:
		return 1
	case HealthUnhealthy:
		return 2
	}
	panic(fmt.Sprintf("health: unknown health %q", h))
}

func observerRank(o Observer) int {
	switch o {
	case ObserverPrimary:
		return 0
	case ObserverStandby:
		return 1
	}
	panic(fmt.Sprintf("health: unknown observer %q", o))
}
