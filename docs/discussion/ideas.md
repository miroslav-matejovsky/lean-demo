# Ideas and experiments

A backlog of experiments. Each is small enough for an evening or a weekend.
Actionable, committed work lives in `.todo`.

## Closer to the domain

- [ ] **Primary ownership (split-brain safety).** Model a lease with explicit
      clocks, bounded drift and message delay. Prove "at most one primary at any
      time" under stated timing assumptions. Then do the same in TLA+ and compare
      effort, readability and what each tool found.
- [ ] **AIS type 1 decoder spec.** Extend `Tutorial/Nmea.lean` into
      `Truth/Ais`: full field layout, round-trip `decode (encode m) = m`,
      multi-fragment sentences. Export vectors and run them against a Go decoder
      and a .NET decoder. Use a synthetic traffic generator as a second source of
      inputs.
- [ ] **Polygon zones.** Point-in-polygon with integer arithmetic on a local
      grid. Prove the result does not depend on the polygon's starting vertex.
- [ ] **CPA/TCPA alerts.** Closest point of approach with fixed-point math.
      Prove monotonicity properties ("closer vessels never get a later alert").
- [ ] **Late alarms.** Change the zone spec so a late intrusion report raises a
      late alarm. Re-prove `no_silent_clear`. Compare the operator experience.
- [ ] **Event-sourced recovery.** Prove that rebuilding a track from its
      persisted message log (`replayState`) equals the state before the crash.
      That is the actor restart contract.
- [ ] **Clocks in the health view.** Replace timestamps with hybrid logical
      clocks and prove convergence *and* "never older than a causally earlier report".

## Stronger link between spec and code

- [ ] **Live oracle / differential fuzzing.** Add `truth oracle` (JSON lines on
      stdin/stdout). Drive it from `go test -fuzz` and from FsCheck: generate
      message sequences, send them to both the implementation and Lean, compare.
      The Cedar approach, with far more coverage than committed vectors.
- [ ] **Coverage-guided vectors.** Generate until every (alarm state x message x
      outcome) cell of the [reaction table](../reference/zone-alarm.md) is hit at
      least *k* times. Emit a coverage report next to the vectors.
- [ ] **Shrinking.** On a conformance failure, minimise the trace and print it
      as a Lean `#guard` ready to paste.
- [ ] **Run the spec itself.** Lean compiles to C. Call the compiled `step`
      through cgo or P/Invoke. The implementation *is* the verified spec. What is
      the operational cost on Windows services?
- [ ] **Actor wrappers.** Wrap `Track.Apply` in an Ergo actor (Go) and a .NET
      virtual actor, and run the same vectors through the mailbox, including
      restarts.

## Better generation

- [ ] **Deriving handlers.** Use Lean metaprogramming to derive `name` and `all`
      for enums, removing hand-written lists in the specs.
- [ ] **More export targets.** CUE schemas for messages, OpenAPI for an alarm
      API, D2 diagrams instead of Mermaid.
- [ ] **Canonical information model.** Treat the Lean types as the canonical
      model and generate the language-specific projections from it.
- [ ] **Theorem catalogue.** Export theorem names and docstrings into the docs:
      a list of "rules guaranteed by proof" for operations and safety reviews.

## LLMs, with the checker in charge

LLMs are advanced autocomplete. The useful setup is one where their output is
checked by something that does not guess.

- [ ] **LLM proposes proofs, kernel decides.** A wrong proof does not compile.
      There is no trust issue, only a time issue.
- [ ] **LLM writes an implementation, vectors judge it.** Give an agent
      `Spec.lean` plus the harness and ask for a Rust implementation. The
      conformance suite and mutation score are the acceptance test.
- [ ] **Spec from prose.** Draft `Spec.lean` from an operating procedure with an
      LLM, then review only the theorem statements. Does that lower the barrier,
      or does it create an illusion of competence one level up?

## Open questions

1. Who is accountable when a theorem is wrong: the architect who wrote it or the
   operations lead who approved its statement?
2. Should conformance be a **deployment gate** or a **visibility signal**? What
   happens to an incident hotfix that fails the vectors?
3. Does a formal truth centralise power in architecture and slow teams down? Or
   does it free them, because anything that passes the vectors is acceptable?
4. Is an executable spec plus vectors already 80 % of the value, with proofs as a
   nice-to-have? Or are the proofs what keep the spec honest over years?
