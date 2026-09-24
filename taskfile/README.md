# taskfile

PowerShell 7 scripts behind `Taskfile.yml`. Each script is called as
`pwsh -NoProfile -NonInteractive -File taskfile/<name>.ps1` and can also be run directly.

| Script | Purpose |
| --- | --- |
| `common.ps1` | Shared paths and helpers. Dot-sourced by the other scripts. |
| `doctor.ps1` | Check that required tools are installed and print their versions. |
| `contracts.ps1` | Build the Lean project and regenerate everything derived from the specs. `-Check` fails on drift. |
| `audit.ps1` | Reject `sorry`, custom axioms and `native_decide`. Print the axioms behind key theorems. |
| `go-test.ps1` | Go conformance tests with gotestsum, log in `.test-results/`. |
| `dotnet-test.ps1` | .NET conformance tests, log in `.test-results/`. |
| `mutate.ps1` | Inject realistic bugs into copies of the implementations and require the tests to fail. |
| `docs.ps1` | Build or serve the Zensical site through uv. |
| `clean.ps1` | Remove build outputs and test results. |
