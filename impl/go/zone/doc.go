// Package zone is the Go implementation of safety zone monitoring.
//
// One Track is the state of one vessel (one MMSI). In an actor system a
// vessel-track actor owns one Track and calls Apply for every message it
// receives. Apply is pure and deterministic for a given message sequence, so
// the actor adds lifecycle and supervision, not behaviour.
//
// The behaviour is specified in lean/Truth/Zone/Spec.lean. Types and
// constants in contract_gen.go are generated from that specification.
// conformance_test.go replays contracts/zone/vectors.json and fails on any
// difference between this package and the specification.
//
// Invariants (proven for the specification, tested here):
//   - the alarm is active exactly when an unauthorized vessel is inside the zone,
//   - an unacknowledged alarm never returns to normal without Acknowledge,
//   - a rejected message leaves the Track unchanged.
package zone
