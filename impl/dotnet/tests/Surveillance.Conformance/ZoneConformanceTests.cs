using System.Text.Json;
using Surveillance.Zone;

namespace Surveillance.Conformance;

/// <summary>Replays contracts/zone/vectors.json against <see cref="Track"/>.</summary>
public class ZoneConformanceTests
{
    private static readonly Lazy<JsonElement> Vectors = new(() => Contracts.Load("zone", "vectors.json"));

    public static TheoryData<string> Traces() => Contracts.TraceNames("zone");

    [Theory]
    [MemberData(nameof(Traces))]
    public void Trace_matches_specification(string name)
    {
        var track = Track.New;
        var stepNo = 0;
        foreach (var step in Contracts.Trace(Vectors.Value, name).GetProperty("steps").EnumerateArray())
        {
            // Arrange
            stepNo++;
            var message = ToMessage(step.GetProperty("event"));
            var expect = step.GetProperty("expect");
            var where = $"step {stepNo}: {message}";

            // Act
            var result = track.Apply(message);

            // Assert
            if (!expect.GetProperty("ok").GetBoolean())
            {
                Assert.False(result.IsOk, $"{where}: spec rejects, implementation accepted");
                Assert.Equal(expect.GetProperty("error").GetString(), result.Error.ToString());
                Assert.Equal(track, result.Value);
                continue;
            }
            Assert.True(result.IsOk, $"{where}: spec accepts, implementation rejected with {result.Error}");
            track = result.Value;
            Assert.Equal(expect.GetProperty("alarm").GetString(), track.Alarm.ToString());
            Assert.Equal(expect.GetProperty("inside").GetBoolean(), track.Inside);
            Assert.Equal(expect.GetProperty("lost").GetBoolean(), track.Lost);
            Assert.Equal(expect.GetProperty("authorized").GetBoolean(), track.Authorized);
            Assert.Equal(expect.GetProperty("lastTs").GetInt64(), track.LastTs);
        }
    }

    [Fact]
    public void Generated_code_matches_manifest()
    {
        var m = Contracts.Load("zone", "manifest.json");
        var c = m.GetProperty("constants");
        Assert.Equal(Policy.SpecVersion, m.GetProperty("specVersion").GetString());
        Assert.Equal(Policy.SpecVersion, Vectors.Value.GetProperty("specVersion").GetString());
        Assert.Equal(Policy.UnitsPerDegree, c.GetProperty("unitsPerDegree").GetInt64());
        Assert.Equal(Policy.MaxLat, c.GetProperty("maxLat").GetInt64());
        Assert.Equal(Policy.MaxLon, c.GetProperty("maxLon").GetInt64());
        Assert.Equal(Policy.LatNotAvailable, c.GetProperty("latNotAvailable").GetInt64());
        Assert.Equal(Policy.LonNotAvailable, c.GetProperty("lonNotAvailable").GetInt64());
        Assert.Equal(Policy.ZoneLatMin, c.GetProperty("zoneLatMin").GetInt64());
        Assert.Equal(Policy.ZoneLatMax, c.GetProperty("zoneLatMax").GetInt64());
        Assert.Equal(Policy.ZoneLonMin, c.GetProperty("zoneLonMin").GetInt64());
        Assert.Equal(Policy.ZoneLonMax, c.GetProperty("zoneLonMax").GetInt64());
        Assert.Equal(Policy.StaleAfter, c.GetProperty("staleAfter").GetInt64());
        Assert.Equal(Contracts.Strings(m.GetProperty("alarmStates")), Enum.GetNames<AlarmState>());
        Assert.Equal(Contracts.Strings(m.GetProperty("errorCodes")), Enum.GetNames<ErrorCode>());
    }

    private static Message ToMessage(JsonElement e) => e.GetProperty("type").GetString() switch
    {
        "Report" => new Message.Report(
            e.GetProperty("ts").GetInt64(), e.GetProperty("lat").GetInt64(), e.GetProperty("lon").GetInt64()),
        "Acknowledge" => new Message.Acknowledge(),
        "Authorize" => new Message.Authorize(e.GetProperty("authorized").GetBoolean()),
        "Tick" => new Message.Tick(e.GetProperty("now").GetInt64()),
        var t => throw new InvalidDataException($"unknown event type {t}"),
    };
}
