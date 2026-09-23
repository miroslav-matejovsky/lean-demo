# Implementations

Two teams implement the same truth in their own idioms. Neither imports Lean.
Each sees only the generated contract file and the vectors.

## Safety zone

=== "Go: value-type Track"

    `impl/go/zone/track.go`

    ```go
    --8<-- "impl/go/zone/track.go"
    ```

=== ".NET: immutable record"

    `impl/dotnet/src/Surveillance/Zone/Track.cs`

    ```csharp
    --8<-- "impl/dotnet/src/Surveillance/Zone/Track.cs"
    ```

## Site health view

=== "Go: comparable value View"

    `impl/go/health/view.go`

    ```go
    --8<-- "impl/go/health/view.go"
    ```

=== ".NET: immutable SiteView"

    `impl/dotnet/src/Surveillance/Health/SiteView.cs`

    ```csharp
    --8<-- "impl/dotnet/src/Surveillance/Health/SiteView.cs"
    ```

## Actors

Both `Apply` functions are pure: state and message in, new state or a typed
rejection out. That is deliberate. In an actor runtime the actor adds identity,
mailbox, lifecycle and supervision, and delegates behaviour:

| Runtime | Actor | Calls |
|---|---|---|
| Go (for example Ergo) | one process per MMSI | `track.Apply(msg)` in the message handler |
| .NET (virtual actors) | one grain per MMSI | `Track.Apply(msg)` in the grain method |

The spec covers exactly the part that must be identical across runtimes: the
behaviour for a given message sequence. Mailbox order, restarts and
persistence are the runtime's job and are not covered. See
[Limits](../discussion/limits.md).

## What the spec leaves to teams

| Free for teams | Fixed by the truth |
|---|---|
| structs vs. records, arrays vs. immutable collections | state after each message |
| error style: typed error (Go), result value (.NET) | which error code is returned |
| persistence, APIs, messaging, actor runtime | canonical names on the wire |
| performance tricks | limits, boundaries, precedence, tie-breaks |

## The replay harness

The only spec-aware test code: read vectors, map wire messages to domain
messages, apply, compare.

=== "Go (testify)"

    ```go
    --8<-- "impl/go/zone/conformance_test.go"
    ```

=== ".NET (xUnit)"

    ```csharp
    --8<-- "impl/dotnet/tests/Surveillance.Conformance/ZoneConformanceTests.cs"
    ```

!!! tip "Adding a third implementation"
    Write a harness (about 100 lines), add a generator for its constants in
    `lean/Truth/Export`, add the output path in `lean/Main.lean`, and add a task.
    The business rules do not change.
