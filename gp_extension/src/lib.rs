use godot::prelude::*;
use godot::classes::RefCounted;
use godot::obj::Base;
use guitarpro::models::*;

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
    /// Parse a Guitar Pro file and return song data as a Dictionary.
    /// Returns: {title, artist, tempo, tracks: [{name, measures: [{notes: [{string_idx, fret, tick, duration_ticks}]}]}]}
    #[func]
    fn parse_file(&self, path: GString) -> Dictionary {
        let path_str: String = path.to_string();
        match guitarpro::parse(&path_str) {
            Ok(song) => self.song_to_dict(&song),
            Err(e) => {
                godot_error!("GpParser: failed to parse {}: {}", path_str, e);
                Dictionary::new()
            }
        }
    }

    fn song_to_dict(&self, song: &guitarpro::models::Song) -> Dictionary {
        let mut dict = Dictionary::new();
        dict.set("title", GString::from(song.title.as_str()));
        dict.set("artist", GString::from(song.artist.as_str()));
        dict.set("tempo", song.tempo as i64);

        let mut tracks_arr = Array::<Dictionary>::new();
        for track in &song.tracks {
            let mut track_dict = Dictionary::new();
            track_dict.set("name", GString::from(track.name.as_str()));

            // Build string tuning array (MIDI notes)
            let mut strings_arr = Array::<i64>::new();
            for s in &track.strings {
                strings_arr.push(s.value as i64);
            }
            track_dict.set("strings", strings_arr.to_variant());

            let mut all_notes: Array<Dictionary> = Array::new();
            let mut measure_tick_offset: i64 = 0;

            for measure in &track.measures {
                let header = &measure.header;
                let ticks_in_measure = (header.time_signature.numerator as i64)
                    * (guitarpro::models::DURATION_QUARTER_TIME as i64 * 4
                        / header.time_signature.denominator.value as i64);

                for voice in &measure.voices {
                    for beat in &voice.beats {
                        let abs_tick = measure_tick_offset + beat.start as i64
                            - guitarpro::models::DURATION_QUARTER_TIME as i64;
                        for note in &beat.notes {
                            let mut note_dict = Dictionary::new();
                            // string index: Guitar Pro strings are 1-based, highest pitch first.
                            // Map to 0=lowest(E2)..5=highest(e5) by reversing.
                            let string_idx = (track.strings.len() as i64 - note.string as i64)
                                .clamp(0, 5);
                            note_dict.set("string_idx", string_idx);
                            note_dict.set("fret", note.value as i64);
                            note_dict.set("tick", abs_tick);
                            note_dict.set(
                                "duration_ticks",
                                beat.duration.value as i64,
                            );
                            all_notes.push(note_dict);
                        }
                    }
                }
                measure_tick_offset += ticks_in_measure;
            }

            track_dict.set("notes", all_notes.to_variant());
            tracks_arr.push(track_dict);
        }

        dict.set("tracks", tracks_arr.to_variant());
        dict
    }
}
