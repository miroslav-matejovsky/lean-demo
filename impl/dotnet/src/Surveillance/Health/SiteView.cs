using System.Collections.Immutable;

namespace Surveillance.Health;

// Behaviour specified in lean/Truth/Health/Spec.lean (convergence is proven there).
// Types and constants come from Generated/Contract.g.cs.
// Conformance is checked against contracts/health/vectors.json.

/// <summary>One probe result for one unit. Ts is the probe time in seconds.</summary>
public sealed record Report(int Unit, long Ts, Health Health, Observer Observer);

/// <summary>
/// One replica's picture of the site: per unit, the best report seen so far.
/// A state-based CRDT: <see cref="Receive"/> and <see cref="Merge"/> are commutative
/// and idempotent, so replicas that saw the same reports show the same view.
/// Immutable.
/// </summary>
public sealed class SiteView
{
    private readonly ImmutableArray<Report?> _entries;

    private SiteView(ImmutableArray<Report?> entries) => _entries = entries;

    /// <summary>A view with no reports.</summary>
    public static SiteView Empty { get; } = new(Enumerable.Repeat<Report?>(null, Policy.SiteUnits).ToImmutableArray());

    /// <summary>Best report for a unit, or null.</summary>
    public Report? this[int unit] => unit >= 0 && unit < Policy.SiteUnits ? _entries[unit] : null;

    /// <summary>Merge one report (a one-entry delta).</summary>
    public Result<SiteView, ErrorCode> Receive(Report report)
    {
        if (report.Unit < 0 || report.Unit >= Policy.SiteUnits)
            return Result.Rejected(this, ErrorCode.UnknownUnit);
        return Result.Ok<SiteView, ErrorCode>(
            new SiteView(_entries.SetItem(report.Unit, Join(_entries[report.Unit], report))));
    }

    /// <summary>Combine two replicas (anti-entropy). Commutative, associative, idempotent.</summary>
    public SiteView Merge(SiteView other) =>
        new(_entries.Select((e, u) => Join(e, other._entries[u])).ToImmutableArray());

    /// <summary>What an operator console shows. Missing or expired reports are Unknown.</summary>
    public Status StatusOf(long now, int unit) => this[unit] switch
    {
        null => Status.Unknown,
        var r when now > r.Ts + Policy.FreshFor => Status.Unknown,
        { Health: Health.Healthy } => Status.Healthy,
        { Health: Health.Degraded } => Status.Degraded,
        { Health: Health.Unhealthy } => Status.Unhealthy,
        var r => throw new InvalidOperationException($"unknown health {r.Health}"),
    };

    private static Report? Join(Report? a, Report? b) => (a, b) switch
    {
        (null, _) => b,
        (_, null) => a,
        _ => Less(a, b) ? b : a,
    };

    /// <summary>Newer wins; on equal time the worse health wins; then observer; then unit.</summary>
    internal static bool Less(Report a, Report b)
    {
        if (a.Ts != b.Ts) return a.Ts < b.Ts;
        if (Rank(a.Health) != Rank(b.Health)) return Rank(a.Health) < Rank(b.Health);
        if (Rank(a.Observer) != Rank(b.Observer)) return Rank(a.Observer) < Rank(b.Observer);
        return a.Unit < b.Unit;
    }

    private static int Rank(Health h) => h switch
    {
        Health.Healthy => 0,
        Health.Degraded => 1,
        Health.Unhealthy => 2,
        _ => throw new ArgumentOutOfRangeException(nameof(h), h, null),
    };

    private static int Rank(Observer o) => o switch
    {
        Observer.Primary => 0,
        Observer.Standby => 1,
        _ => throw new ArgumentOutOfRangeException(nameof(o), o, null),
    };
}
