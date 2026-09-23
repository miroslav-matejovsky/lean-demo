# Ideas & experiments

A backlog of experiments, each small enough for an evening or a weekend.

## Strengthen the link between spec and code

- [ ] **Live oracle / differential fuzzing.** Add `truth oracle` (JSON lines on
      stdin/stdout). Go's native fuzzing (`go test -fuzz`) or FsCheck then generates
      event sequences, sends them to both the implementation and the Lean process,
      and compares. This is the Cedar approach, with far more coverage than committed vectors.
- [ ] **Coverage-guided vectors.** Generate traces until every (state × event ×
      error) cell of the [transition table](../reference/order-state-machine.md)
      is hit at least *k* times, then emit a coverage report next to `vectors.json`.
- [ ] **Shrinking.** When conformance fails, minimise the trace to the shortest
      failing prefix and print it as a Lean `#guard` ready to paste.
- [ ] **Verify a core in Lean and ship it.** Compile the Lean `step` to C (Lean
      does this natively) and call it through FFI from Go (cgo) or .NET (P/Invoke).
      The "implementation" then *is* the verified spec. What is the operational cost?
- [ ] **Dafny comparison.** Implement the same Order aggregate in Dafny, compile it
      to C# and Go, and compare effort, readability and guarantees.

## Richer truth

- [ ] **Separation of duties.** Add `submittedBy`/`approvedBy` and prove
      `approvedBy ≠ submittedBy`. This is the *real* four-eyes rule.
- [ ] **Cross-aggregate rules.** Model a customer credit limit over *all* open
      orders, and see how the invariant proof changes.
- [ ] **Temporal properties.** Prove "every pending order is eventually decided"
      under a fairness assumption, or hand this part to TLA+.
- [ ] **Event-sourcing projection.** Prove that folding the event log (`replayState`)
      equals the stored state, so the read model can't disagree with the aggregate.
- [ ] **API evolution theorem.** Specify v1 and v2 of the spec and *prove* backward
      compatibility: every v1 trace behaves the same in v2.

## Better generation

- [ ] **Use Lean metaprogramming** to derive codegen from `Status`/`ErrorCode`
      automatically (a `deriving` handler), removing the hand-written `Status.all`.
- [ ] **OpenAPI / JSON Schema export** for events, making the Lean spec the
      source for API contracts too.
- [ ] **Theorem catalogue.** Export theorem names and docstrings into the docs
      automatically, giving auditors a list of "rules guaranteed by proof".

## AI in the loop (2026 reality)

- [ ] **LLM writes the implementation, Lean judges it.** Give an agent `Spec.lean`
      plus the harness and ask for a Rust or Kotlin implementation. The conformance
      suite is the acceptance test, which makes the spec a guardrail for AI-generated code.
- [ ] **LLM proposes proofs.** Try recent provers or assistants on new invariants.
      The kernel still checks everything, so there is no trust issue.
- [ ] **Spec from prose.** Have an LLM draft `Spec.lean` from a policy document,
      then have humans review only the theorem *statements*. Does this
      lower the barrier for architects?

## Open questions to argue about

1. Who is accountable when the theorem is wrong, the architect or the compliance
   officer who approved its statement?
2. Should conformance be a **deployment gate** (can't deploy non-conforming
   services) or a **visibility signal** (dashboard)? What happens in an incident hotfix?
3. Does a formal "truth" centralise power in architecture in a way that slows
   teams down? Or does it *free* teams, since anything that passes the vectors is acceptable?
4. Is an executable spec plus vectors already 80 % of the value, with proofs as
   a nice-to-have? Or are the proofs what keep the spec honest over the years?
