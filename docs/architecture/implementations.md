# Implementations

Two "teams" implement the same truth in their own idioms. Neither imports
Lean, and neither needs to know it exists, apart from the generated file and
the vectors.

=== ".NET: immutable record aggregate"

    `impl/dotnet/src/Orders/Order.cs`

    ```csharp
    --8<-- "impl/dotnet/src/Orders/Order.cs"
    ```

=== "Go: value-type aggregate"

    `impl/go/orders/order.go`

    ```go
    --8<-- "impl/go/orders/order.go"
    ```

## What the spec does *not* dictate

This is intentional. The truth constrains **observable behaviour**, not design:

| Free for teams | Fixed by the truth |
|---|---|
| Records vs. structs, mutable vs. immutable | State after each event |
| Exceptions vs. result types internally | Which error code is returned |
| Persistence, APIs, messaging, DI | Canonical names on the wire |
| Performance tricks (caching totals, …) | Limits, thresholds, precedence |

## The replay harness

The only Lean-aware code in each project is a generic harness. It reads the
vectors, maps wire events to domain events, applies them, and compares results.

=== ".NET (xUnit)"

    ```csharp
    --8<-- "impl/dotnet/tests/Orders.Conformance/ConformanceTests.cs"
    ```

=== "Go (testing)"

    ```go
    --8<-- "impl/go/orders/conformance_test.go"
    ```

!!! tip "Adding a third language"
    Write the harness (about 100 lines), add a generator in
    `lean/Truth/Export/Codegen.lean` for its constants, add the output path in
    `lean/Main.lean`, and add a stage in `taskfile/verify.ps1`. Nothing in
    the business rules changes.
