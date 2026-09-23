using System.Text.Json;
using Surveillance.Health;

namespace Surveillance.Conformance;

/// <summary>Replays contracts/health/vectors.json against <see cref="SiteView"/>.</summary>
public class HealthConformanceTests
{
    private static readonly Lazy<JsonElement> Vectors = new(() => Contracts.Load("health", "vectors.json"));

    public static TheoryData<string> Traces() => Contracts.TraceNames("health");

    public static TheoryData<string> ConvergenceCases()
    {
        var data = new TheoryData<string>();
        foreach (var c in Contracts.Load("health", "vectors.json").GetProperty("convergence").EnumerateArray())
            data.Add(c.GetProperty("name").GetString()!);
        return data;
    }

    [Theory]
    [MemberData(nameof(Traces))]
    public void Trace_matches_specification(string name)
    {
        var view = SiteView.Empty;
        var stepNo = 0;
        foreach (var step in Contracts.Trace(Vectors.Value, name).GetProperty("steps").EnumerateArray())
        {
            stepNo++;
            var e = step.GetProperty("event");
            var expect = step.GetProperty("expect");
            var where = $"step {stepNo}: {e}";
            if (e.GetProperty("type").GetString() == "Query")
            {
                var now = e.GetProperty("now").GetInt64();
                var statuses = Enumerable.Range(0, Policy.SiteUnits).Select(u => view.StatusOf(now, u).ToString());
                Assert.Equal(Contracts.Strings(expect.GetProperty("statuses")), statuses);
                continue;
            }

            var result = view.Receive(ToReport(e));

            if (!expect.GetProperty("ok").GetBoolean())
            {
                Assert.False(result.IsOk, $"{where}: spec rejects, implementation accepted");
                Assert.Equal(expect.GetProperty("error").GetString(), result.Error.ToString());
                Assert.Same(view, result.Value);
                continue;
            }
            Assert.True(result.IsOk, $"{where}: spec accepts, implementation rejected with {result.Error}");
            view = result.Value;
            Assert.Equal(Wire(expect.GetProperty("view")), Wire(view));
        }
    }

    [Theory]
    [MemberData(nameof(ConvergenceCases))]
    public void Delivery_order_duplicates_and_merge_never_change_the_view(string name)
    {
        // Arrange
        var c = Vectors.Value.GetProperty("convergence").EnumerateArray()
            .Single(x => x.GetProperty("name").GetString() == name);
        var inboxA = c.GetProperty("inboxA").EnumerateArray().Select(ToReport).ToArray();
        var inboxB = c.GetProperty("inboxB").EnumerateArray().Select(ToReport).ToArray();
        var split = c.GetProperty("split").GetInt32();
        var expect = Wire(c.GetProperty("expect"));

        // Act
        var replicaA = Deliver(inboxA);
        var replicaB = Deliver(inboxB);
        var primary = Deliver(inboxA[..split]);
        var standby = Deliver(inboxA[split..]);

        // Assert
        Assert.Equal(expect, Wire(replicaA));
        Assert.Equal(expect, Wire(replicaB));
        Assert.Equal(expect, Wire(primary.Merge(standby)));
        Assert.Equal(expect, Wire(standby.Merge(primary)));
    }

    [Fact]
    public void Generated_code_matches_manifest()
    {
        var m = Contracts.Load("health", "manifest.json");
        var c = m.GetProperty("constants");
        Assert.Equal(Policy.SpecVersion, m.GetProperty("specVersion").GetString());
        Assert.Equal(Policy.SpecVersion, Vectors.Value.GetProperty("specVersion").GetString());
        Assert.Equal(Policy.SiteUnits, c.GetProperty("siteUnits").GetInt32());
        Assert.Equal(Policy.ProbeInterval, c.GetProperty("probeInterval").GetInt32());
        Assert.Equal(Policy.ProbeTimeout, c.GetProperty("probeTimeout").GetInt32());
        Assert.Equal(Policy.FreshFor, c.GetProperty("freshFor").GetInt32());
        Assert.Equal(Contracts.Strings(m.GetProperty("health")), Enum.GetNames<Health.Health>());
        Assert.Equal(Contracts.Strings(m.GetProperty("observers")), Enum.GetNames<Observer>());
        Assert.Equal(Contracts.Strings(m.GetProperty("statuses")), Enum.GetNames<Status>());
        Assert.Equal(Contracts.Strings(m.GetProperty("errorCodes")), Enum.GetNames<ErrorCode>());
    }

    private static SiteView Deliver(IEnumerable<Report> inbox) =>
        inbox.Aggregate(SiteView.Empty, (v, r) => v.Receive(r).Value);

    private static Report ToReport(JsonElement e) => new(
        e.GetProperty("unit").GetInt32(),
        e.GetProperty("ts").GetInt64(),
        Enum.Parse<Health.Health>(e.GetProperty("health").GetString()!),
        Enum.Parse<Observer>(e.GetProperty("observer").GetString()!));

    /// <summary>Canonical text form of a view, one entry per unit, for comparison.</summary>
    private static string[] Wire(SiteView v) =>
        Enumerable.Range(0, Policy.SiteUnits)
            .Select(u => v[u] is { } r ? $"{r.Ts}/{r.Health}/{r.Observer}" : "-").ToArray();

    private static string[] Wire(JsonElement view) =>
        view.EnumerateArray()
            .Select(e => e.ValueKind == JsonValueKind.Null
                ? "-"
                : $"{e.GetProperty("ts").GetInt64()}/{e.GetProperty("health").GetString()}/{e.GetProperty("observer").GetString()}")
            .ToArray();
}
