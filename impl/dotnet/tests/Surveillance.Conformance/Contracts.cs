using System.Text.Json;

namespace Surveillance.Conformance;

/// <summary>
/// Loads the Lean-generated contract files. CONTRACTS_DIR overrides the location;
/// otherwise the repository's contracts folder is found by walking up.
/// </summary>
internal static class Contracts
{
    public static JsonElement Load(string spec, string file)
    {
        var dir = Environment.GetEnvironmentVariable("CONTRACTS_DIR") ?? FindUp("contracts");
        var path = Path.Combine(dir, spec, file);
        return JsonDocument.Parse(File.ReadAllText(path)).RootElement;
    }

    /// <summary>Trace names for xUnit theories (one test case per trace).</summary>
    public static TheoryData<string> TraceNames(string spec)
    {
        var data = new TheoryData<string>();
        foreach (var t in Load(spec, "vectors.json").GetProperty("traces").EnumerateArray())
            data.Add(t.GetProperty("name").GetString()!);
        return data;
    }

    public static JsonElement Trace(JsonElement vectors, string name) =>
        vectors.GetProperty("traces").EnumerateArray().Single(t => t.GetProperty("name").GetString() == name);

    public static string[] Strings(JsonElement array) =>
        array.EnumerateArray().Select(s => s.GetString()!).ToArray();

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
