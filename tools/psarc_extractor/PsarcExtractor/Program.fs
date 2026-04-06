/// PSARC extractor using iminashi/Rocksmith2014.NET
/// Reads .psarc CDLC files and outputs note data as JSON for the go-guitar Godot game.
module PsarcExtractor.Program

open System
open System.IO
open System.Text.Json
open Rocksmith2014.PSARC
open Rocksmith2014.SNG
open Rocksmith2014.Common

// ---------------------------------------------------------------------------
// JSON output types consumed by the Godot game
// ---------------------------------------------------------------------------

[<CLIMutable>]
type NoteOut =
    { time: float32
      /// Rocksmith string index: 0 = Low E (string 6, top), 5 = High e (string 1, bottom)
      string_index: int
      fret: int
      sustain: float32 }

[<CLIMutable>]
type SongOut =
    { title: string
      artist: string
      song_length: float32
      arrangement: string
      notes: NoteOut array }

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let private readManifestJson (psarc: PSARC) (suffix: string) =
    psarc.Manifest
    |> Seq.tryFind (fun n -> n.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
    |> Option.map (fun name ->
        use ms = new MemoryStream()
        psarc.InflateFile(name, ms) |> Async.AwaitTask |> Async.RunSynchronously
        ms.Position <- 0L
        use reader = new StreamReader(ms)
        reader.ReadToEnd())

let private parseSongMetadata (json: string) =
    use doc = JsonDocument.Parse(json)
    let first =
        doc.RootElement.GetProperty("Entries").EnumerateObject()
        |> Seq.head
    let attrs = first.Value.GetProperty("Attributes")
    struct {|
        title  = attrs.GetProperty("SongName").GetString()
        artist = attrs.GetProperty("ArtistName").GetString()
        length = attrs.GetProperty("SongLength").GetSingle()
    |}

let private readSng (psarc: PSARC) (arrType: string) : SNG option =
    let sngName =
        psarc.Manifest
        |> Seq.tryFind (fun n ->
            n.EndsWith(sprintf "_%s.sng" arrType, StringComparison.OrdinalIgnoreCase))
    match sngName with
    | None -> None
    | Some name ->
        use ms = new MemoryStream()
        psarc.InflateFile(name, ms) |> Async.AwaitTask |> Async.RunSynchronously
        ms.Position <- 0L
        let sng = SNG.fromStream ms PC |> Async.RunSynchronously
        Some sng

let private extractNotes (sng: SNG) : NoteOut array =
    if sng.Levels.Length = 0 then [||]
    else
        // Use highest difficulty level
        let maxLevel = sng.Levels |> Array.maxBy (fun l -> l.Difficulty)
        maxLevel.Notes
        |> Array.map (fun n ->
            { time         = n.Time
              string_index = int n.StringIndex
              fret         = int n.Fret
              sustain      = n.Sustain })

// ---------------------------------------------------------------------------
// Per-arrangement extraction
// ---------------------------------------------------------------------------

let private extractArrangement (psarc: PSARC) (arrType: string) : SongOut option =
    match readManifestJson psarc (sprintf "_%s.json" arrType) with
    | None -> None
    | Some json ->
        match readSng psarc arrType with
        | None -> None
        | Some sng ->
            let meta = parseSongMetadata json
            let notes = extractNotes sng
            if notes.Length = 0 then None
            else
                Some { title       = meta.title
                       artist      = meta.artist
                       song_length = meta.length
                       arrangement = arrType
                       notes       = notes }

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

[<EntryPoint>]
let main argv =
    if argv.Length < 2 then
        eprintfn "Usage: psarc_extractor <input.psarc> <output_dir>"
        1
    else
        let psarcPath = argv.[0]
        let outDir    = argv.[1]

        if not (File.Exists psarcPath) then
            eprintfn "File not found: %s" psarcPath
            1
        else
            Directory.CreateDirectory(outDir) |> ignore

            use psarc = PSARC.OpenFile(psarcPath)

            let baseName =
                Path.GetFileNameWithoutExtension(psarcPath)
                    .Replace("_p", "").Replace("_m", "").TrimEnd('_')

            let opts = JsonSerializerOptions(WriteIndented = true)
            let mutable written = 0

            for arrType in [| "lead"; "rhythm"; "bass" |] do
                match extractArrangement psarc arrType with
                | None -> ()
                | Some song ->
                    let outPath = Path.Combine(outDir, sprintf "%s_%s.json" baseName arrType)
                    File.WriteAllText(outPath, JsonSerializer.Serialize(song, opts))
                    printfn "  %s: %d notes → %s" arrType song.notes.Length outPath
                    written <- written + 1

            if written = 0 then
                eprintfn "No arrangements found in %s" psarcPath
                1
            else
                0
