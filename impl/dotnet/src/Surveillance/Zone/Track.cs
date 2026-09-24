namespace Surveillance.Zone;

// Behaviour specified in lean/Truth/Zone/Spec.lean. Types and constants come from
// Generated/Contract.g.cs. Conformance is checked against contracts/zone/vectors.json.

/// <summary>Messages accepted by a vessel-track actor.</summary>
public abstract record Message
{
    /// <summary>AIS position report. Ts: receive time in seconds. Lat/Lon: 1/10 000 minute.</summary>
    public sealed record Report(long Ts, long Lat, long Lon) : Message;

    /// <summary>Operator acknowledges the alarm.</summary>
    public sealed record Acknowledge : Message;

    /// <summary>Grants or revokes permission to be inside the zone.</summary>
    public sealed record Authorize(bool Authorized) : Message;

    /// <summary>Time passes. Now is in seconds.</summary>
    public sealed record Tick(long Now) : Message;
}

/// <summary>
/// State of one vessel track (one MMSI). Immutable: <see cref="Apply"/> returns a new track.
/// In an actor system (for example a virtual actor per MMSI) the actor owns one Track
/// and calls Apply for every message. Apply is deterministic for a given message sequence.
/// </summary>
/// <param name="LastTs">Receive time of the newest accepted report; 0 means never reported.</param>
/// <param name="Inside">Last known position is inside the zone.</param>
/// <param name="Lost">No report for <see cref="Policy.StaleAfter"/> seconds.</param>
/// <param name="Authorized">Vessel may be inside the zone.</param>
/// <param name="Alarm">Alarm lifecycle state.</param>
public sealed record Track(long LastTs, bool Inside, bool Lost, bool Authorized, AlarmState Alarm)
{
    /// <summary>A track that has not received any message.</summary>
    public static Track New { get; } = new(0, false, false, false, AlarmState.Normal);

    /// <summary>The alarm condition: an unauthorized vessel inside the zone.</summary>
    public bool Intrusion => Inside && !Authorized;

    /// <summary>Handle one message. A rejection returns this track unchanged.</summary>
    public Result<Track, ErrorCode> Apply(Message message) => message switch
    {
        Message.Report r => Report(r),
        Message.Acknowledge => Acknowledge(),
        Message.Authorize a => Ok((this with { Authorized = a.Authorized }).Evaluate()),
        Message.Tick t => Ok(LastTs > 0 && t.Now >= LastTs + Policy.StaleAfter ? this with { Lost = true } : this),
        _ => throw new ArgumentOutOfRangeException(nameof(message), message, "unsupported message"),
    };

    private Result<Track, ErrorCode> Report(Message.Report r)
    {
        if (r.Lat == Policy.LatNotAvailable || r.Lon == Policy.LonNotAvailable)
            return Reject(ErrorCode.PositionUnavailable);
        if (r.Lat < -Policy.MaxLat || r.Lat > Policy.MaxLat || r.Lon < -Policy.MaxLon || r.Lon > Policy.MaxLon)
            return Reject(ErrorCode.InvalidPosition);
        if (r.Ts <= LastTs)
            return Reject(ErrorCode.StaleReport);
        return Ok((this with { LastTs = r.Ts, Inside = InZone(r.Lat, r.Lon), Lost = false }).Evaluate());
    }

    private Result<Track, ErrorCode> Acknowledge() => Alarm switch
    {
        AlarmState.UnackActive => Ok(this with { Alarm = AlarmState.AckActive }),
        AlarmState.UnackCleared => Ok(this with { Alarm = AlarmState.Normal }),
        AlarmState.Normal or AlarmState.AckActive => Reject(ErrorCode.NothingToAcknowledge),
        _ => throw new InvalidOperationException($"unknown alarm state {Alarm}"),
    };

    /// <summary>Move the alarm according to the current condition. Acknowledgement is never implied.</summary>
    private Track Evaluate() => this with
    {
        Alarm = (Alarm, Intrusion) switch
        {
            (AlarmState.Normal or AlarmState.UnackCleared, true) => AlarmState.UnackActive,
            (AlarmState.UnackActive, false) => AlarmState.UnackCleared,
            (AlarmState.AckActive, false) => AlarmState.Normal,
            _ => Alarm,
        },
    };

    /// <summary>Boundaries belong to the zone.</summary>
    private static bool InZone(long lat, long lon) =>
        Policy.ZoneLatMin <= lat && lat <= Policy.ZoneLatMax && Policy.ZoneLonMin <= lon && lon <= Policy.ZoneLonMax;

    private static Result<Track, ErrorCode> Ok(Track t) => Result.Ok<Track, ErrorCode>(t);

    private Result<Track, ErrorCode> Reject(ErrorCode e) => Result.Rejected(this, e);
}
