package zone

import "fmt"

// Event is a message accepted by a vessel-track actor.
type Event interface{ isEvent() }

// Report is an AIS position report.
// TS is the receive time in seconds, assigned ashore.
// Lat and Lon are in AIS units of 1/10 000 minute.
type Report struct {
	TS  int64
	Lat int64
	Lon int64
}

// Acknowledge is an operator acknowledging the alarm.
type Acknowledge struct{}

// Authorize grants or revokes permission to be inside the zone.
type Authorize struct {
	Authorized bool
}

// Tick tells the track that time has passed. Now is in seconds.
type Tick struct {
	Now int64
}

func (Report) isEvent()      {}
func (Acknowledge) isEvent() {}
func (Authorize) isEvent()   {}
func (Tick) isEvent()        {}

// RejectedError is a business rejection. The track is unchanged.
type RejectedError struct {
	Code ErrorCode
}

func (e *RejectedError) Error() string { return "zone: rejected: " + string(e.Code) }

func reject(code ErrorCode) error { return &RejectedError{Code: code} }

// Track is the state of one vessel track. It is a value: Apply returns a new
// Track and never mutates the receiver.
type Track struct {
	// LastTS is the receive time of the newest accepted report. 0 means never reported.
	LastTS int64
	// Inside is true when the last known position is inside the zone.
	Inside bool
	// Lost is true when no report arrived for StaleAfter seconds.
	Lost       bool
	Authorized bool
	Alarm      AlarmState
}

// NewTrack returns a track that has not received any message.
func NewTrack() Track { return Track{Alarm: AlarmNormal} }

// Intrusion reports whether the alarm condition holds.
func (t Track) Intrusion() bool { return t.Inside && !t.Authorized }

// Apply handles one message. On error the returned Track equals the receiver.
// A *RejectedError is a business rejection; any other error is a programming error.
func (t Track) Apply(e Event) (Track, error) {
	switch ev := e.(type) {
	case Report:
		return t.report(ev)
	case Acknowledge:
		return t.acknowledge()
	case Authorize:
		t.Authorized = ev.Authorized
		return t.evaluate(), nil
	case Tick:
		if t.LastTS > 0 && ev.Now >= t.LastTS+StaleAfter {
			t.Lost = true
		}
		return t, nil
	default:
		return t, fmt.Errorf("zone: unsupported event %T", e)
	}
}

func (t Track) report(r Report) (Track, error) {
	switch {
	case r.Lat == LatNotAvailable || r.Lon == LonNotAvailable:
		return t, reject(ErrPositionUnavailable)
	case r.Lat < -MaxLat || r.Lat > MaxLat || r.Lon < -MaxLon || r.Lon > MaxLon:
		return t, reject(ErrInvalidPosition)
	case r.TS <= t.LastTS:
		return t, reject(ErrStaleReport)
	}
	t.LastTS = r.TS
	t.Inside = inZone(r.Lat, r.Lon)
	t.Lost = false
	return t.evaluate(), nil
}

func (t Track) acknowledge() (Track, error) {
	switch t.Alarm {
	case AlarmUnackActive:
		t.Alarm = AlarmAckActive
		return t, nil
	case AlarmUnackCleared:
		t.Alarm = AlarmNormal
		return t, nil
	case AlarmNormal, AlarmAckActive:
		return t, reject(ErrNothingToAcknowledge)
	}
	return t, fmt.Errorf("zone: unknown alarm state %q", t.Alarm)
}

// evaluate moves the alarm according to the current condition.
// Acknowledgement is never implied.
func (t Track) evaluate() Track {
	condition := t.Intrusion()
	switch t.Alarm {
	case AlarmNormal, AlarmUnackCleared:
		if condition {
			t.Alarm = AlarmUnackActive
		}
	case AlarmUnackActive:
		if !condition {
			t.Alarm = AlarmUnackCleared
		}
	case AlarmAckActive:
		if !condition {
			t.Alarm = AlarmNormal
		}
	}
	return t
}

// inZone reports whether a position is inside the zone. Boundaries belong to the zone.
func inZone(lat, lon int64) bool {
	return ZoneLatMin <= lat && lat <= ZoneLatMax && ZoneLonMin <= lon && lon <= ZoneLonMax
}
