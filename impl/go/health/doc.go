// Package health is the Go implementation of the replicated site health view.
//
// A primary and a standby platform instance each keep a View. Reports arrive
// late, out of order and more than once. The View is a state-based CRDT:
// per unit it keeps the best report seen so far, where "best" is a total
// order (newer wins, on equal time the worse health wins, then observer,
// then unit). Receive and Merge are therefore commutative and idempotent,
// and two replicas that saw the same reports show the same view.
//
// The behaviour is specified in lean/Truth/Health/Spec.lean, where
// convergence is proven. Types and constants in contract_gen.go are
// generated from that specification. conformance_test.go replays
// contracts/health/vectors.json, including the convergence cases.
package health
