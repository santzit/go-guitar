use godot::prelude::*;
use godot::classes::RefCounted;
use godot::obj::Base;
use scorelib::model::key_signature::DURATION_QUARTER_TIME;
use scorelib::model::song::Song;
use scorelib::model::key_signature::Duration as GpDuration;
use std::fs;

struct GoGuitarExtension;

#[gdextension]
unsafe impl ExtensionLibrary for GoGuitarExtension {}

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct GpParser {
base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for GpParser {
fn init(base: Base<RefCounted>) -> Self {
Self { base }
}
}

#[godot_api]
impl GpParser {
/// Parse a Guitar Pro file (.gp3/.gp4/.gp5) and return song data as a Dictionary.
/// Returns: {name, artist, tempo, tracks: [{name, notes: [{string_idx, fret, tick, duration_ticks}]}]}
#[func]
fn parse_file(&self, path: GString) -> VarDictionary {
let path_str: String = path.to_string();
let data = match fs::read(&path_str) {
Ok(d) => d,
Err(e) => {
godot_error!("GpParser: cannot read {}: {}", path_str, e);
return VarDictionary::new();
}
};

let mut song = Song::default();
let ext = std::path::Path::new(&path_str)
.extension()
.and_then(|e| e.to_str())
.unwrap_or("")
.to_lowercase();

let result = match ext.as_str() {
"gp3" => song.read_gp3(&data),
"gp4" => song.read_gp4(&data),
"gp5" => song.read_gp5(&data),
"gp" | "gpx" => song.read_gpx(&data),
_ => song.read_gp5(&data),
};

if let Err(e) = result {
godot_error!("GpParser: failed to parse {}: {}", path_str, e);
return VarDictionary::new();
}

self.song_to_dict(&song)
}

fn song_to_dict(&self, song: &Song) -> VarDictionary {
let mut dict = VarDictionary::new();
dict.set("name", song.name.as_str());
dict.set("artist", song.artist.as_str());
dict.set("tempo", song.tempo as i64);

let mut tracks_arr = VarArray::new();
for track in &song.tracks {
let mut track_dict = VarDictionary::new();
track_dict.set("name", track.name.as_str());

let num_strings = track.strings.len();

// Build flat notes array with absolute tick positions
let mut all_notes = VarArray::new();

for measure in &track.measures {
let header_idx = measure.header_index;
let header = &song.measure_headers[header_idx];
let measure_start = header.start;

for voice in &measure.voices {
for beat in &voice.beats {
let beat_start = beat.start.unwrap_or(DURATION_QUARTER_TIME);
let abs_tick = measure_start + beat_start - DURATION_QUARTER_TIME;
let dur_ticks = Self::compute_duration_ticks(&beat.duration);

for note in &beat.notes {
let string_idx = (num_strings as i64 - note.string as i64)
.clamp(0, 5);
let mut note_dict = VarDictionary::new();
note_dict.set("string_idx", string_idx);
note_dict.set("fret", note.value as i64);
note_dict.set("tick", abs_tick);
note_dict.set("duration_ticks", dur_ticks);
let note_v = note_dict.to_variant();
all_notes.push(&note_v);
}
}
}
}

let notes_v = all_notes.to_variant();
track_dict.set("notes", &notes_v);
let track_v = track_dict.to_variant();
tracks_arr.push(&track_v);
}

let tracks_v = tracks_arr.to_variant();
dict.set("tracks", &tracks_v);
dict
}

fn compute_duration_ticks(dur: &GpDuration) -> i64 {
let base = (DURATION_QUARTER_TIME * 4) / dur.value as i64;
let dotted_ticks = if dur.double_dotted {
base + base / 2 + base / 4
} else if dur.dotted {
base + base / 2
} else {
base
};
if dur.tuplet_times > 0 {
dotted_ticks * dur.tuplet_enters as i64 / dur.tuplet_times as i64
} else {
dotted_ticks
}
}
}
