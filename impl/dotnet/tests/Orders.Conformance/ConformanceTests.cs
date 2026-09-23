using System.Text.Json;

namespace Orders.Conformance;

/// <summary>
/// Replays every trace generated from the Lean specification and checks that
/// this implementation answers exactly like the spec. The test code is generic:
/// it only knows the wire format, not the business rules.
/// </summary>
public class ConformanceTests
{
    private static readonly Lazy<Contracts> Data = new(Contracts.Load);

    public static TheoryData<string> TraceNames()
    {
        var data = new TheoryData<string>();
        foreach (var name in Data.Value.Traces.Keys) data.Add(name);
        return data;
    }

    [Theory]
    [MemberData(nameof(TraceNames))]
    public void Trace_matches_specification(string traceName)
    {
        var order = Order.New;
        var stepNo = 0;
        foreach (var step in Data.Value.Traces[traceName])
        {
            stepNo++;
            var evt = ParseEvent(step.GetProperty("event"));
            var expect = step.GetProperty("expect");
            var result = order.Apply(evt);
            var where = $"step {stepNo} ({evt})";

            if (expect.GetProperty("ok").GetBoolean())
            {
                Assert.True(result.IsOk, $"{where}: spec accepts, implementation rejected with {result.Error}");
                order = result.Value!;
                Assert.Equal(expect.GetProperty("status").GetString(), order.Status.ToString());
                Assert.Equal(expect.GetProperty("total").GetInt64(), order.Total);
                Assert.Equal(expect.GetProperty("lines").GetInt32(), order.Lines.Count);
                Assert.Equal(expect.GetProperty("approved").GetBoolean(), order.Approved);
            }
            else
            {
                Assert.False(result.IsOk, $"{where}: spec rejects with {expect.GetProperty("error")}, implementation accepted");
                Assert.Equal(expect.GetProperty("error").GetString(), result.Error.ToString());
                // a rejected command leaves the order unchanged: keep `order` as is
            }
        }
    }

    [Fact]
    public void Generated_code_matches_vectors_version()
    {
        Assert.Equal(Policy.SpecVersion, Data.Value.SpecVersion);
    }

    [Fact]
    public void Generated_code_matches_manifest()
    {
        var m = Data.Value.Manifest;
        var c = m.GetProperty("constants");
        Assert.Equal(Policy.ApprovalThreshold, c.GetProperty("approvalThreshold").GetInt64());
        Assert.Equal(Policy.MaxLines, c.GetProperty("maxLines").GetInt32());
        Assert.Equal(Policy.MaxQty, c.GetProperty("maxQty").GetInt32());
        Assert.Equal(Policy.MaxUnitPrice, c.GetProperty("maxUnitPrice").GetInt64());
        Assert.Equal(m.GetProperty("statuses").EnumerateArray().Select(s => s.GetString()), Enum.GetNames<OrderStatus>());
        Assert.Equal(m.GetProperty("errorCodes").EnumerateArray().Select(s => s.GetString()), Enum.GetNames<ErrorCode>());
    }

    private static OrderEvent ParseEvent(JsonElement e) => e.GetProperty("type").GetString() switch
    {
        "AddLine" => new OrderEvent.AddLine(
            e.GetProperty("sku").GetString()!, e.GetProperty("qty").GetInt64(), e.GetProperty("unitPrice").GetInt64()),
        "Submit" => new OrderEvent.Submit(),
        "Approve" => new OrderEvent.Approve(),
        "Reject" => new OrderEvent.Reject(),
        "Ship" => new OrderEvent.Ship(),
        "Cancel" => new OrderEvent.Cancel(),
        var t => throw new InvalidDataException($"unknown event type {t}"),
    };
}

internal sealed record Contracts(string SpecVersion, Dictionary<string, JsonElement[]> Traces, JsonElement Manifest)
{
    /// <summary>CONTRACTS_DIR overrides the location; otherwise walk up to the repo's contracts/order folder.</summary>
    public static Contracts Load()
    {
        var dir = Environment.GetEnvironmentVariable("CONTRACTS_DIR") ?? FindUp("contracts");
        var order = Path.Combine(dir, "order");
        var vectors = JsonDocument.Parse(File.ReadAllText(Path.Combine(order, "vectors.json"))).RootElement;
        var manifest = JsonDocument.Parse(File.ReadAllText(Path.Combine(order, "manifest.json"))).RootElement;
        var traces = vectors.GetProperty("traces").EnumerateArray().ToDictionary(
            t => t.GetProperty("name").GetString()!,
            t => t.GetProperty("steps").EnumerateArray().ToArray());
        return new Contracts(vectors.GetProperty("specVersion").GetString()!, traces, manifest);
    }

    private static string FindUp(string name)
    {
        for (var d = new DirectoryInfo(AppContext.BaseDirectory); d is not null; d = d.Parent)
        {
            var candidate = Path.Combine(d.FullName, name);
            if (Directory.Exists(candidate)) return candidate;
        }
        throw new DirectoryNotFoundException($"'{name}' not found above {AppContext.BaseDirectory}; set CONTRACTS_DIR");
    }
}
