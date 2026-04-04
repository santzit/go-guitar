//! # gp_extension
//!
//! Godot 4 GDExtension that exposes a `GpParser` class to GDScript.
//! Uses [`scorelib`] (<https://github.com/slundi/guitarpro>) to parse
//! Guitar Pro 3 / 4 / 5 files and returns the song data as a Godot
//! `Dictionary` consumed by `music_play.gd`.
//!
//! ## GDScript usage
//! ```gdscript
//! var file  = FileAccess.open(path, FileAccess.READ)
//! var bytes = file.get_buffer(file.get_length())
//! file.close()
//! var data  = GpParser.new().parse_bytes(bytes, path.get_extension())
//! # data = { title, artist, album, bpm, notes:[{time,string,fret,duration}…] }
//! ```

use godot::prelude::*;
use scorelib::model::{
    enums::NoteType,
    headers::MeasureHeader,
    key_signature::{Duration, DURATION_QUARTER_TIME},
    song::Song,
};

// ── Extension entry-point ────────────────────────────────────────────────────

struct GpExtension;

#[gdextension]
unsafe impl ExtensionLibrary for GpExtension {}

// ── Type alias ───────────────────────────────────────────────────────────────

/// Godot untyped dictionary (key=Variant, value=Variant) compatible with
/// GDScript's plain `Dictionary`.
type VDict = Dictionary<Variant, Variant>;

// ── GpParser ─────────────────────────────────────────────────────────────────

/// Parses Guitar Pro files and exposes the data to GDScript.
#[derive(GodotClass)]
#[class(base = RefCounted)]
pub struct GpParser {
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for GpParser {
    fn init(base: Base<RefCounted>) -> Self {
        GpParser { base }
    }
}

#[godot_api]
impl GpParser {
    /// Parse a Guitar Pro file from raw bytes.
    ///
    /// - `data`      – raw bytes from `FileAccess.get_buffer()`
    /// - `extension` – file extension without dot, e.g. `"gp5"`
    ///
    /// Returns `{ title, artist, album, bpm, notes }` or an empty dict on error.
    /// Each element of `notes` is `{ time:float, string:int, fret:int, duration:float }`.
    /// `string` is 0-indexed from low-E (0) to high-e (5).
    #[func]
    pub fn parse_bytes(&self, data: PackedByteArray, extension: GString) -> VDict {
        let bytes = data.to_vec();
        let ext   = extension.to_string().to_lowercase();

        let mut song = Song::default();
        let result = match ext.as_str() {
            "gp5"        => song.read_gp5(&bytes),
            "gp4"        => song.read_gp4(&bytes),
            "gp3" | "gp" => song.read_gp3(&bytes),
            _ => song
                .read_gp5(&bytes)
                .or_else(|_| { song = Song::default(); song.read_gp4(&bytes) })
                .or_else(|_| { song = Song::default(); song.read_gp3(&bytes) }),
        };

        if let Err(e) = result {
            godot_error!("GpParser: failed to parse '{}' file: {:?}", ext, e);
            return VDict::new();
        }

        self.song_to_dict(&song)
    }

    // ── Conversion ───────────────────────────────────────────────────────────

    fn song_to_dict(&self, song: &Song) -> VDict {
        // GString values are passed as &GString (implements AsArg<Variant>).
        // i64 / f64 are passed directly (trivially AsArg<Variant>).
        let title  = GString::from(song.name.trim());
        let artist = GString::from(song.artist.trim());
        let album  = GString::from(song.album.trim());
        let notes  = self.extract_notes(song);

        let mut d = VDict::new();
        d.set(&GString::from("title"),  &title);
        d.set(&GString::from("artist"), &artist);
        d.set(&GString::from("album"),  &album);
        d.set(&GString::from("bpm"),    song.tempo.max(1) as i64);
        d.set(&GString::from("notes"),  &notes);
        d
    }

    fn extract_notes(&self, song: &Song) -> Array<Variant> {
        let mut out: Array<Variant> = Array::new();

        let bpm          = song.tempo.max(1) as f64;
        let quarter_secs = 60.0 / bpm;

        // First non-percussion track (lead guitar)
        let track = match song.tracks.iter().find(|t| !t.percussion_track) {
            Some(t) => t,
            None    => return out,
        };
        let num_strings = track.strings.len() as i8;

        // beat.start is always within-measure: the first beat of every measure
        // resets to DURATION_QUARTER_TIME (960).  To obtain the absolute tick
        // position in the song we track a running measure offset and add
        // (beat.start - DURATION_QUARTER_TIME) to it.
        let mut measure_tick_offset: i64 = 0;

        for measure in &track.measures {
            let header = &song.measure_headers[measure.header_index];

            let voice = match measure.voices.first() {
                Some(v) => v,
                None    => {
                    measure_tick_offset += Self::measure_duration_ticks(header);
                    continue;
                }
            };

            for beat in &voice.beats {
                let start_ticks = match beat.start {
                    Some(s) => s,
                    None    => continue,
                };
                // Absolute tick = accumulated measure offset + within-measure offset.
                // beat.start counts from DURATION_QUARTER_TIME at the first beat of
                // every measure, so we subtract that base to get 0-relative offsets.
                let abs_ticks = measure_tick_offset + start_ticks - DURATION_QUARTER_TIME as i64;
                let time_sec: f64 = abs_ticks as f64
                    / DURATION_QUARTER_TIME as f64
                    * quarter_secs;

                // Duration::time() is pub(crate); replicated here.
                let dur_ticks = Self::duration_ticks(&beat.duration);
                let dur_sec: f64 = dur_ticks / DURATION_QUARTER_TIME as f64 * quarter_secs;

                for note in &beat.notes {
                    if !matches!(note.kind, NoteType::Normal) {
                        continue;
                    }
                    // GP string: 1 = high-e, 6 = low-E
                    // Game string: 0 = low-E, 5 = high-e
                    let game_str: i64 = ((num_strings - note.string).max(0) as i64).min(5);

                    let mut nd = VDict::new();
                    // f64 and i64 pass directly (AsArg<Variant> is trivially implemented).
                    nd.set(&GString::from("time"),     time_sec);
                    nd.set(&GString::from("string"),   game_str);
                    nd.set(&GString::from("fret"),     note.value as i64);
                    nd.set(&GString::from("duration"), dur_sec);
                    out.push(&nd);
                }
            }

            measure_tick_offset += Self::measure_duration_ticks(header);
        }
        out
    }

    /// Compute a measure's total duration in ticks from its time signature.
    ///
    /// Examples:
    /// - 4/4 at DURATION_QUARTER_TIME = 960:  4 beats × 960 ticks/beat = 3840 ticks
    /// - 3/4:                                  3 beats × 960 ticks/beat = 2880 ticks
    /// - 6/8:                                  6 beats × 480 ticks/beat = 2880 ticks
    fn measure_duration_ticks(header: &MeasureHeader) -> i64 {
        let beat_ticks = Self::duration_ticks(&header.time_signature.denominator) as i64;
        header.time_signature.numerator as i64 * beat_ticks
    }

    /// Replicate `Duration::time()` (which is `pub(crate)` in scorelib).
    ///
    /// Returns beat duration in ticks (quarter note = 960).
    ///
    /// Formula from scorelib source:
    /// ```text
    /// ticks = floor(960 * 4 / value)
    /// if dotted: ticks += floor(ticks / 2)
    /// ticks = floor(ticks * tuplet_enters / tuplet_times)
    /// ```
    fn duration_ticks(dur: &Duration) -> f64 {
        let mut t = (DURATION_QUARTER_TIME as f64 * 4.0 / f64::from(dur.value)).trunc();
        if dur.dotted {
            t += (t / 2.0).trunc();
        }
        if dur.tuplet_times > 0 {
            t = (t * f64::from(dur.tuplet_enters) / f64::from(dur.tuplet_times)).trunc();
        }
        t
    }
}
