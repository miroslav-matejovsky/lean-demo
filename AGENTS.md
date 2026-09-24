# AGENTS.md

## Core Rules

- Never commit changes. NEVER!
- Be brave; Be Honest; Be kind; Be true;
- Research and learning repo. Favor progress and clean code over backwards compatibility.
- Communicate clearly and directly. Short sentences. Simple language.
- No praise. No filler. No fluff. No motivational text.
- Be concise in output. Be thorough in reasoning.
- Think before acting. Read existing files before changing code.
- Prefer editing existing files over rewriting whole files.
- When unclear, explain the problem and ask, or write a note to `.todo` and stop.
- Before a task is complete, run `task all`. `task all` must pass.

## Repository Model

- `lean/Truth/*/Spec.lean` is the truth. Behaviour changes start there.
- `lean/Truth/*/Properties.lean` holds the theorems. A theorem that no longer holds is a finding, not an obstacle. Report it; do not weaken the statement to make it pass.
- Everything marked generated (`contracts/`, `*_gen.go`, `Generated/*.g.cs`, `docs/reference/*-*.md` with a generated header) is written by `task contracts`. Never edit it by hand.
- `impl/go` and `impl/dotnet` are independent implementations. They must not share code. They share only the generated contracts.
- A surviving mutant in `task mutate` means the vector generator in `lean/Truth/Export` is too weak. Fix the generator, not the mutant.

## Documentation

- Root `README.md`: overview. `docs/`: the site (Zensical).
- Keep documentation close to code and synchronized with the implementation.
- Outdated documentation is a defect.
- Go package: `doc.go`. Other folders: `README.md` when needed.
- Document assumptions, constraints, and invariants.
- Docs embed Lean code with snippet markers (`-- --8<-- [start:name]`). Keep markers balanced.

## Lean Specific

- Lean core only. No Mathlib unless a plan says so.
- No `sorry`, no custom `axiom`, no `native_decide`. `task audit` enforces it.
- Specs are pure, total and deterministic: no IO, no clock, no floating point.
- Keep theorem statements short and in business language. Put complexity in the proofs.
- Prefer `omega`, `simp`, `decide`, `grind` over long manual proofs when they work.
- Pin the toolchain in `lean/lean-toolchain`.

## Architecture and Design

- Prefer boring, pragmatic solutions. KISS and YAGNI.
- Accept duplication until a pattern appears at least 3 times.
- Fail fast. Fail visibly. Validate messages at boundaries.
- Model business capabilities as actors with one owner per state.
- Actor behavior must be deterministic for a given message sequence. In this repo that behaviour is a pure `Apply`/`step` function, specified in Lean.
- Assume messages may arrive late, out of order, and more than once. State what the spec does in each case, and prove it where practical.

## Error Handling

- Never swallow errors.
- Distinguish business rejections (typed error codes from the spec) from system failures (exceptions, wrapped errors).
- A rejected message never changes state.

## Testing

- Conformance tests replay generated vectors. They know the wire format, not the business rules.
- New behaviour requires a spec change, a regenerated vector set, and passing implementations.
- Keep tests deterministic. No sleeps. No timing dependencies.

## Go Specific

- Idiomatic Go. Small interfaces. Package docs in `doc.go`.
- Use `require` from `testify` for assertions.
- golangci-lint must pass, including `exhaustive` over spec enums.

## .NET Specific

- Solution-level builds. Warnings are errors.
- Nullable reference types enabled. Analyzers on (`latest-recommended`). Do not suppress without a stated reason.
- Arrange / Act / Assert in tests.

## Output

- No em dashes. Plain ASCII punctuation in prose.
- Code must be copy-paste safe.
- If implementation is incomplete, document remaining work in `.todo` at the repository root.
