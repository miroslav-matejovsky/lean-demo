namespace Surveillance;

/// <summary>
/// Outcome of handling one message: the new state, or a business rejection.
/// A rejection never changes state. System failures are exceptions, not results.
/// </summary>
/// <param name="Value">The new state, or the unchanged state when rejected.</param>
/// <param name="Error">The rejection reason, or null when accepted.</param>
public readonly record struct Result<T, TError>(T Value, TError? Error)
    where TError : struct, Enum
{
    /// <summary>True when the message was accepted.</summary>
    public bool IsOk => Error is null;
}

/// <summary>Factory methods for <see cref="Result{T, TError}"/>.</summary>
public static class Result
{
    /// <summary>Accepted with a new state.</summary>
    public static Result<T, TError> Ok<T, TError>(T value)
        where TError : struct, Enum => new(value, null);

    /// <summary>Rejected; <paramref name="unchanged"/> is the state before the message.</summary>
    public static Result<T, TError> Rejected<T, TError>(T unchanged, TError error)
        where TError : struct, Enum => new(unchanged, error);
}
