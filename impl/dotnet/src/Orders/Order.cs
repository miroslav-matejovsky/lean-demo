using System.Collections.Immutable;

namespace Orders;

// Hand-written by the ".NET team". Types and constants come from
// Generated/Contract.g.cs; behaviour must match the Lean spec, which is
// enforced by the conformance tests (contracts/order/vectors.json).

public sealed record OrderLine(string Sku, long Qty, long UnitPrice)
{
    public long Amount => Qty * UnitPrice;
}

public abstract record OrderEvent
{
    public sealed record AddLine(string Sku, long Qty, long UnitPrice) : OrderEvent;
    public sealed record Submit : OrderEvent;
    public sealed record Approve : OrderEvent;
    public sealed record Reject : OrderEvent;
    public sealed record Ship : OrderEvent;
    public sealed record Cancel : OrderEvent;
}

public readonly record struct Result<T>(T? Value, ErrorCode? Error)
{
    public bool IsOk => Error is null;
    public static Result<T> Ok(T value) => new(value, null);
    public static Result<T> Fail(ErrorCode error) => new(default, error);
}

/// <summary>Immutable order aggregate. <see cref="Apply"/> never mutates; a rejected command returns an error.</summary>
public sealed record Order(OrderStatus Status, ImmutableList<OrderLine> Lines, bool Approved)
{
    public static Order New { get; } = new(OrderStatus.Draft, ImmutableList<OrderLine>.Empty, false);

    public long Total => Lines.Sum(l => l.Amount);

    public Result<Order> Apply(OrderEvent evt) => evt switch
    {
        OrderEvent.AddLine a => AddLine(a),
        OrderEvent.Submit => Submit(),
        OrderEvent.Approve => Status == OrderStatus.PendingApproval
            ? Ok(this with { Status = OrderStatus.Approved, Approved = true })
            : Fail(ErrorCode.InvalidTransition),
        OrderEvent.Reject => Status == OrderStatus.PendingApproval
            ? Ok(this with { Status = OrderStatus.Draft })
            : Fail(ErrorCode.InvalidTransition),
        OrderEvent.Ship => Status == OrderStatus.Approved
            ? Ok(this with { Status = OrderStatus.Shipped })
            : Fail(ErrorCode.InvalidTransition),
        OrderEvent.Cancel => Status is OrderStatus.Shipped or OrderStatus.Cancelled
            ? Fail(ErrorCode.InvalidTransition)
            : Ok(this with { Status = OrderStatus.Cancelled }),
        _ => throw new ArgumentOutOfRangeException(nameof(evt)),
    };

    private Result<Order> AddLine(OrderEvent.AddLine a)
    {
        if (Status != OrderStatus.Draft) return Fail(ErrorCode.InvalidTransition);
        if (a.Qty <= 0 || a.Qty > Policy.MaxQty) return Fail(ErrorCode.InvalidQuantity);
        if (a.UnitPrice <= 0 || a.UnitPrice > Policy.MaxUnitPrice) return Fail(ErrorCode.InvalidPrice);
        if (Lines.Count >= Policy.MaxLines) return Fail(ErrorCode.TooManyLines);
        return Ok(this with { Lines = Lines.Add(new OrderLine(a.Sku, a.Qty, a.UnitPrice)) });
    }

    private Result<Order> Submit()
    {
        if (Status != OrderStatus.Draft) return Fail(ErrorCode.InvalidTransition);
        if (Lines.IsEmpty) return Fail(ErrorCode.EmptyOrder);
        return Ok(this with
        {
            Status = Total > Policy.ApprovalThreshold ? OrderStatus.PendingApproval : OrderStatus.Approved,
        });
    }

    private static Result<Order> Ok(Order o) => Result<Order>.Ok(o);
    private static Result<Order> Fail(ErrorCode e) => Result<Order>.Fail(e);
}
