using System.Collections;
using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;
using PKHeX.Core;

if (args.Length != 1)
    throw new ArgumentException("usage: Exporter <output.json>");

var rows = new List<RawEncounter>();
var assembly = typeof(GameInfo).Assembly;

var sources = new Source[]
{
    new("PKHeX.Core.Encounters8", "SlotsSW_Symbol", "sword", GameVersion.SW, EntityContext.Gen8, "wild"),
    new("PKHeX.Core.Encounters8", "SlotsSW_Hidden", "sword", GameVersion.SW, EntityContext.Gen8, "wild"),
    new("PKHeX.Core.Encounters8", "SlotsSH_Symbol", "shield", GameVersion.SH, EntityContext.Gen8, "wild"),
    new("PKHeX.Core.Encounters8", "SlotsSH_Hidden", "shield", GameVersion.SH, EntityContext.Gen8, "wild"),
    new("PKHeX.Core.Encounters8", "StaticSWSH", "sword+shield", GameVersion.SW, EntityContext.Gen8, "fixed"),
    new("PKHeX.Core.Encounters8Nest", "Nest_SW", "sword", GameVersion.SW, EntityContext.Gen8, "raid"),
    new("PKHeX.Core.Encounters8Nest", "Nest_SH", "shield", GameVersion.SH, EntityContext.Gen8, "raid"),
    new("PKHeX.Core.Encounters8a", "SlotsLA", "legends-arceus", GameVersion.PLA, EntityContext.Gen8a, "wild"),
    new("PKHeX.Core.Encounters8a", "StaticLA", "legends-arceus", GameVersion.PLA, EntityContext.Gen8a, "fixed"),
    new("PKHeX.Core.Encounters8b", "SlotsBD", "brilliant-diamond", GameVersion.BD, EntityContext.Gen8b, "wild"),
    new("PKHeX.Core.Encounters8b", "SlotsSP", "shining-pearl", GameVersion.SP, EntityContext.Gen8b, "wild"),
    new("PKHeX.Core.Encounters8b", "Encounter_BDSP", "brilliant-diamond+shining-pearl", GameVersion.BD, EntityContext.Gen8b, "fixed"),
    new("PKHeX.Core.Encounters8b", "StaticBD", "brilliant-diamond", GameVersion.BD, EntityContext.Gen8b, "fixed"),
    new("PKHeX.Core.Encounters8b", "StaticSP", "shining-pearl", GameVersion.SP, EntityContext.Gen8b, "fixed"),
    new("PKHeX.Core.Encounters9", "Slots", "scarlet+violet", GameVersion.SL, EntityContext.Gen9, "wild"),
    new("PKHeX.Core.Encounters9", "Encounter_SV", "scarlet+violet", GameVersion.SL, EntityContext.Gen9, "fixed"),
    new("PKHeX.Core.Encounters9", "StaticSL", "scarlet", GameVersion.SL, EntityContext.Gen9, "fixed"),
    new("PKHeX.Core.Encounters9", "StaticVL", "violet", GameVersion.VL, EntityContext.Gen9, "fixed"),
    new("PKHeX.Core.Encounters9", "TeraBase", "scarlet+violet", GameVersion.SL, EntityContext.Gen9, "raid"),
    new("PKHeX.Core.Encounters9", "TeraDLC1", "the-teal-mask-scarlet+the-teal-mask-violet", GameVersion.SL, EntityContext.Gen9, "raid"),
    new("PKHeX.Core.Encounters9", "TeraDLC2", "the-indigo-disk-scarlet+the-indigo-disk-violet", GameVersion.SL, EntityContext.Gen9, "raid"),
    new("PKHeX.Core.Encounters9", "Fixed", "scarlet+violet", GameVersion.SL, EntityContext.Gen9, "fixed"),
    new("PKHeX.Core.Encounters9", "Outbreak", "scarlet+violet", GameVersion.SL, EntityContext.Gen9, "outbreak"),
    new("PKHeX.Core.Encounters9a", "Slots", "legends-za", GameVersion.ZA, EntityContext.Gen9a, "wild"),
    new("PKHeX.Core.Encounters9a", "Hyperspace", "mega-dimension", GameVersion.ZA, EntityContext.Gen9a, "wild"),
    new("PKHeX.Core.Encounters9a", "Static", "legends-za", GameVersion.ZA, EntityContext.Gen9a, "fixed"),
};

foreach (var source in sources)
{
    var type = assembly.GetType(source.TypeName, throwOnError: true)!;
    var field = type.GetField(source.FieldName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static)
        ?? throw new MissingFieldException(source.TypeName, source.FieldName);
    if (field.GetValue(null) is not IEnumerable values)
        continue;
    foreach (var value in values)
        Flatten(value, source, rows);
}

rows = rows
    .Where(z => z.Species is > 0 and <= 1025 && z.Location > 0)
    .DistinctBy(z => new { z.SourceField, z.VersionHint, z.Species, z.Form, z.Location, z.LevelMin, z.LevelMax, z.Method, z.TeraType, z.IsAlpha, z.IsTitan })
    .OrderBy(z => z.VersionHint).ThenBy(z => z.Species).ThenBy(z => z.Form).ThenBy(z => z.Location)
    .ToList();

var payload = new
{
    schemaVersion = 1,
    sourceCommit = "5c9e949c9f0fa932a1b63511b32c2bee5ce75b4e",
    sourceLicense = "GPL-3.0-or-later",
    rows,
};
await File.WriteAllTextAsync(args[0], JsonSerializer.Serialize(payload, new JsonSerializerOptions
{
    WriteIndented = true,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
}) + Environment.NewLine);

static void Flatten(object? value, Source source, List<RawEncounter> rows)
{
    if (value is null) return;
    var slots = Get(value, "Slots") as IEnumerable;
    if (slots is not null)
    {
        foreach (var slot in slots)
            Flatten(slot, source, rows);
        return;
    }

    var species = ToInt(Get(value, "Species"));
    if (species <= 0) return;
    var fixedBall = Get(value, "FixedBall")?.ToString();
    var eggLocation = ToInt(Get(value, "EggLocation"));
    if (source.Method == "fixed" && (fixedBall is not null && fixedBall != "None" || eggLocation > 0))
        return; // gift, egg, fossil restoration, or scripted non-wild acquisition

    var form = ToInt(Get(value, "Form"));
    var location = ToInt(Get(value, "Location"));
    if (location <= 0 && source.Method == "raid")
        location = source.Context == EntityContext.Gen9 ? 30001 : 30000;
    var generation = source.Context.Generation;
    var english = GameInfo.GetStrings("en");
    var chinese = GameInfo.GetStrings("zh-Hans");
    string Location(GameStrings strings) => strings.GetLocationName(false, (ushort)location, generation, generation, source.GameVersion);
    var tera = Get(value, "TeraType")?.ToString();
    if (tera is "Default" or "Random" or "Any" or "None" or "0") tera = null;
    var formNameEn = FormConverter.GetStringFromForm((ushort)species, (byte)form, english, source.Context);
    var formNameZh = FormConverter.GetStringFromForm((ushort)species, (byte)form, chinese, source.Context);
    rows.Add(new RawEncounter(
        source.FieldName,
        source.VersionHint,
        species,
        english.specieslist[species],
        form,
        formNameEn,
        formNameZh,
        location,
        Location(english),
        Location(chinese),
        ToInt(Get(value, "LevelMin"), ToInt(Get(value, "Level"))),
        ToInt(Get(value, "LevelMax"), ToInt(Get(value, "Level"))),
        source.Method,
        tera?.ToLowerInvariant(),
        ToBool(Get(value, "IsAlpha")),
        ToBool(Get(value, "IsTitan")),
        ToInt(Get(value, "RandRate"))
    ));
}

static object? Get(object value, string name)
{
    var flags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
    var type = value.GetType();
    try
    {
        return type.GetProperty(name, flags)?.GetValue(value)
            ?? type.GetField(name, flags)?.GetValue(value);
    }
    catch (TargetInvocationException)
    {
        return null;
    }
}

static int ToInt(object? value, int fallback = 0)
{
    if (value is null) return fallback;
    try { return Convert.ToInt32(value); }
    catch { return fallback; }
}

static bool ToBool(object? value) => value is bool flag && flag;

internal sealed record Source(string TypeName, string FieldName, string VersionHint, GameVersion GameVersion, EntityContext Context, string Method);
internal sealed record RawEncounter(
    string SourceField,
    string VersionHint,
    int Species,
    string SpeciesNameEn,
    int Form,
    string FormNameEn,
    string FormNameZh,
    int Location,
    string AreaNameEn,
    string AreaLabelZh,
    int LevelMin,
    int LevelMax,
    string Method,
    string? TeraType,
    bool IsAlpha,
    bool IsTitan,
    int RateValue
);
