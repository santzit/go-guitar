/// PsarcLoader — Godot GDExtension class
/// Exposes PSARC/SNG parsing to GDScript entirely in memory.
use godot::prelude::*;
use std::fs;
use crate::{psarc, sng};

// ── Minimal JSON field reader (no serde dependency) ───────────────────────────

fn json_str_field<'a>(json: &'a str, key: &str) -> Option<&'a str> {
    let needle = format!("\"{}\"", key);
    let kpos = json.find(&needle)?;
    let rest = json[kpos + needle.len()..].trim_start();
    let rest = rest.trim_start_matches(':').trim_start();
    if !rest.starts_with('"') { return None; }
    let inner = &rest[1..];
    Some(&inner[..inner.find('"')?])
}

fn json_f32_field(json: &str, key: &str) -> Option<f32> {
    let needle = format!("\"{}\"", key);
    let kpos = json.find(&needle)?;
    let rest = json[kpos + needle.len()..].trim_start();
    let rest = rest.trim_start_matches(':').trim_start();
    rest.split(|c: char| !c.is_ascii_digit() && c != '.' && c != '-')
        .next()?.parse().ok()
}

// ── helper: build a VarDictionary manually to avoid AsArg<Variant> issues ────


// ── GDExtension class ─────────────────────────────────────────────────────────

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct PsarcLoader {
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for PsarcLoader {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl PsarcLoader {
    /// Load notes for an arrangement ("lead", "rhythm", or "bass") from a PSARC file.
    ///
    /// Returns:
    ///   { "ok": bool, "error": String, "title": String, "artist": String,
    ///     "song_length": float,
    ///     "notes": Array[{time:float, string_index:int, fret:int, sustain:float}] }
    #[func]
    fn load_notes(&self, path: GString, arrangement: GString) -> VarDictionary {
        let mut d = VarDictionary::new();
        match self.do_load_notes(path.to_string(), arrangement.to_string()) {
            Ok((title, artist, song_length, notes)) => {
                let mut note_arr = VarArray::new();
                for n in &notes {
                    let mut nd = VarDictionary::new();
                    nd.set(&"time".to_variant(),         &(n.time as f64).to_variant());
                    nd.set(&"string_index".to_variant(), &(n.string_index as i64).to_variant());
                    nd.set(&"fret".to_variant(),         &(n.fret as i64).to_variant());
                    nd.set(&"sustain".to_variant(),      &(n.sustain as f64).to_variant());
                    note_arr.push(&nd.to_variant());
                }
                d.set(&"ok".to_variant(),          &true.to_variant());
                d.set(&"error".to_variant(),        &GString::from("").to_variant());
                d.set(&"title".to_variant(),        &GString::from(title.as_str()).to_variant());
                d.set(&"artist".to_variant(),       &GString::from(artist.as_str()).to_variant());
                d.set(&"song_length".to_variant(),  &(song_length as f64).to_variant());
                d.set(&"notes".to_variant(),        &note_arr.to_variant());
            }
            Err(e) => {
                d.set(&"ok".to_variant(),          &false.to_variant());
                d.set(&"error".to_variant(),        &GString::from(e.as_str()).to_variant());
                d.set(&"title".to_variant(),        &GString::from("").to_variant());
                d.set(&"artist".to_variant(),       &GString::from("").to_variant());
                d.set(&"song_length".to_variant(),  &0.0_f64.to_variant());
                d.set(&"notes".to_variant(),        &VarArray::new().to_variant());
            }
        }
        d
    }

    /// List arrangements available in a PSARC file.
    /// Returns PackedStringArray, e.g. ["lead", "rhythm", "bass"].
    #[func]
    fn list_arrangements(&self, path: GString) -> PackedStringArray {
        let mut result = PackedStringArray::new();
        let raw = match fs::read(path.to_string()) {
            Ok(v) => v, Err(_) => return result,
        };
        let psarc = match psarc::parse(&raw) {
            Ok(p) => p, Err(_) => return result,
        };
        for arr in &["lead", "rhythm", "bass"] {
            let suffix = format!("_{}.sng", arr);
            if psarc.entries.iter().any(|e| e.name.to_lowercase().ends_with(&suffix)) {
                result.push(&GString::from(*arr));
            }
        }
        result
    }

    /// Extract the OGG audio for the main song track (no disk write).
    /// Returns empty PackedByteArray on error.
    #[func]
    fn load_audio(&self, path: GString) -> PackedByteArray {
        let raw = match fs::read(path.to_string()) {
            Ok(v) => v, Err(_) => return PackedByteArray::new(),
        };
        let psarc = match psarc::parse(&raw) {
            Ok(p) => p, Err(_) => return PackedByteArray::new(),
        };
        for entry in &psarc.entries {
            let n = entry.name.to_lowercase();
            if (n.contains("audio/windows/") || n.contains("audio\\windows\\"))
                && n.ends_with(".ogg") && !n.contains("preview")
            {
                let mut out = PackedByteArray::new();
                out.resize(entry.data.len());
                out.as_mut_slice().copy_from_slice(&entry.data);
                return out;
            }
        }
        PackedByteArray::new()
    }

    // ── internal ─────────────────────────────────────────────────────────────

    fn do_load_notes(
        &self, path: String, arrangement: String,
    ) -> Result<(String, String, f32, Vec<sng::Note>), String> {
        let raw = fs::read(&path).map_err(|e| format!("read {}: {}", path, e))?;
        let psarc = psarc::parse(&raw)?;

        let arr_lc      = arrangement.to_lowercase();
        let suffix_json = format!("_{}.json", arr_lc);
        let suffix_sng  = format!("_{}.sng",  arr_lc);

        let json_entry = psarc.entries.iter()
            .find(|e| e.name.to_lowercase().ends_with(&suffix_json))
            .ok_or_else(|| format!("no {} manifest in psarc", arr_lc))?;
        let json_str = String::from_utf8_lossy(&json_entry.data).into_owned();

        let title  = json_str_field(&json_str, "SongName").unwrap_or("Unknown").to_owned();
        let artist = json_str_field(&json_str, "ArtistName").unwrap_or("Unknown").to_owned();
        let length = json_f32_field(&json_str, "SongLength").unwrap_or(0.0);

        let sng_entry = psarc.entries.iter()
            .find(|e| e.name.to_lowercase().ends_with(&suffix_sng))
            .ok_or_else(|| format!("no {} sng in psarc", arr_lc))?;
        let sng_data = sng::parse(&sng_entry.data)?;

        let song_length = if length > 0.0 { length } else { sng_data.song_length };
        Ok((title, artist, song_length, sng_data.notes))
    }
}
