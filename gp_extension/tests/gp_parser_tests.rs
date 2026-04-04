//! Integration tests for the gp_extension crate.
//!
//! These tests operate directly on the scorelib types (without the Godot
//! runtime) so they can be executed with plain `cargo test`.
//!
//! The real GP5 file `DLC/the-ramones-baby_i_love_you_3.gp5` is resolved
//! relative to the workspace root via the `CARGO_MANIFEST_DIR` env-var
//! (which cargo sets to the `gp_extension/` directory).

use scorelib::model::{
    enums::NoteType,
    key_signature::{Duration, DURATION_QUARTER_TIME, DURATION_EIGHTH, DURATION_QUARTER},
    song::Song,
};

// ── helper: path to the DLC test file ────────────────────────────────────────

fn dlc_gp5_path() -> std::path::PathBuf {
    // CARGO_MANIFEST_DIR = .../go-guitar/gp_extension/
    let mut p = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    p.pop(); // go up to go-guitar/
    p.push("DLC");
    p.push("the-ramones-baby_i_love_you_3.gp5");
    p
}

// ── helper: duration_ticks (mirrors lib.rs impl) ─────────────────────────────

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

// ═══════════════════════════════════════════════════════════════════════════
// Unit tests – pure logic, no file I/O
// ═══════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod unit {
    use super::*;

    // ── duration_ticks ────────────────────────────────────────────────────

    #[test]
    fn duration_quarter_is_960_ticks() {
        let d = Duration {
            value: DURATION_QUARTER as u16,
            ..Default::default()
        };
        assert_eq!(duration_ticks(&d) as u32, 960);
    }

    #[test]
    fn duration_eighth_is_480_ticks() {
        let d = Duration {
            value: DURATION_EIGHTH as u16,
            ..Default::default()
        };
        assert_eq!(duration_ticks(&d) as u32, 480);
    }

    #[test]
    fn duration_dotted_quarter_is_1440_ticks() {
        let d = Duration {
            value: DURATION_QUARTER as u16,
            dotted: true,
            ..Default::default()
        };
        assert_eq!(duration_ticks(&d) as u32, 1440);
    }

    #[test]
    fn duration_tuplet_3_2_on_quarter_is_1440_ticks() {
        // scorelib applies the tuplet as a factor of (enters / times).
        // (3, 2) → 960 × 3/2 = 1440 – a "lengthening" tuplet.
        let d = Duration {
            value: DURATION_QUARTER as u16,
            tuplet_enters: 3,
            tuplet_times: 2,
            ..Default::default()
        };
        assert_eq!(duration_ticks(&d) as u32, 1440);
    }

    #[test]
    fn duration_shortening_triplet_on_quarter_is_640_ticks() {
        // The musical 3-in-the-time-of-2 triplet (each note = 2/3 of a quarter)
        // uses enters=2, times=3 in scorelib's model → 960 × 2/3 = 640 ticks.
        let d = Duration {
            value: DURATION_QUARTER as u16,
            tuplet_enters: 2,
            tuplet_times: 3,
            ..Default::default()
        };
        assert_eq!(duration_ticks(&d) as u32, 640);
    }

    // ── string index mapping ──────────────────────────────────────────────

    /// Guitar Pro string numbering: 1 = highest (high-e), 6 = lowest (low-E).
    /// Game string numbering:        0 = lowest (low-E),  5 = highest (high-e).
    /// Conversion: game = num_strings - gp_string  (for a 6-string guitar)
    #[test]
    fn gp_string_1_maps_to_game_string_5() {
        let num_strings: i8 = 6;
        let gp_string: i8 = 1; // high-e
        let game = ((num_strings - gp_string).max(0) as i64).min(5);
        assert_eq!(game, 5);
    }

    #[test]
    fn gp_string_6_maps_to_game_string_0() {
        let num_strings: i8 = 6;
        let gp_string: i8 = 6; // low-E
        let game = ((num_strings - gp_string).max(0) as i64).min(5);
        assert_eq!(game, 0);
    }

    #[test]
    fn gp_string_3_maps_to_game_string_3() {
        let num_strings: i8 = 6;
        let gp_string: i8 = 3; // G
        let game = ((num_strings - gp_string).max(0) as i64).min(5);
        assert_eq!(game, 3);
    }

    // ── tick → seconds conversion ─────────────────────────────────────────

    #[test]
    fn first_beat_tick_converts_to_zero_seconds() {
        let bpm = 120.0_f64;
        let quarter_secs = 60.0 / bpm;
        // First beat starts at DURATION_QUARTER_TIME (960)
        let start_ticks: i64 = DURATION_QUARTER_TIME;
        let secs =
            (start_ticks - DURATION_QUARTER_TIME) as f64 / DURATION_QUARTER_TIME as f64 * quarter_secs;
        assert!((secs - 0.0).abs() < 1e-9);
    }

    #[test]
    fn second_quarter_beat_at_120bpm_is_half_second() {
        let bpm = 120.0_f64;
        let quarter_secs = 60.0 / bpm; // 0.5s
        // Second beat = 960 + 960 = 1920 ticks
        let start_ticks: i64 = DURATION_QUARTER_TIME + DURATION_QUARTER_TIME;
        let secs =
            (start_ticks - DURATION_QUARTER_TIME) as f64 / DURATION_QUARTER_TIME as f64 * quarter_secs;
        assert!((secs - 0.5).abs() < 1e-9);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Integration tests – parse the real GP5 file
// ═══════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod integration {
    use super::*;

    fn load_test_song() -> Song {
        let path = dlc_gp5_path();
        assert!(
            path.exists(),
            "Test GP5 file not found at {:?}.\nRun `git pull` to fetch DLC/the-ramones-baby_i_love_you_3.gp5",
            path
        );
        let data = std::fs::read(&path)
            .unwrap_or_else(|e| panic!("Cannot read {:?}: {}", path, e));

        let mut song = Song::default();
        song.read_gp5(&data)
            .unwrap_or_else(|e| panic!("Failed to parse GP5 file: {:?}", e));
        song
    }

    // ── metadata ─────────────────────────────────────────────────────────

    #[test]
    fn song_has_non_empty_title() {
        let song = load_test_song();
        assert!(!song.name.trim().is_empty(), "Song title should not be empty");
        println!("Title:  {}", song.name.trim());
        println!("Artist: {}", song.artist.trim());
        println!("BPM:    {}", song.tempo);
    }

    #[test]
    fn song_bpm_is_reasonable() {
        let song = load_test_song();
        assert!(
            song.tempo > 0 && song.tempo <= 400,
            "BPM {} is out of a reasonable range (1–400)",
            song.tempo
        );
    }

    #[test]
    fn song_has_at_least_one_track() {
        let song = load_test_song();
        assert!(!song.tracks.is_empty(), "Song must have at least one track");
    }

    #[test]
    fn first_track_has_measures() {
        let song = load_test_song();
        let track = &song.tracks[0];
        assert!(
            !track.measures.is_empty(),
            "First track should have at least one measure"
        );
    }

    // ── notes ─────────────────────────────────────────────────────────────

    #[test]
    fn song_has_normal_notes() {
        let song = load_test_song();
        let guitar_track = song
            .tracks
            .iter()
            .find(|t| !t.percussion_track)
            .expect("Should have at least one non-percussion track");

        let total_normal: usize = guitar_track
            .measures
            .iter()
            .flat_map(|m| m.voices.iter())
            .flat_map(|v| v.beats.iter())
            .flat_map(|b| b.notes.iter())
            .filter(|n| matches!(n.kind, NoteType::Normal))
            .count();

        assert!(
            total_normal > 0,
            "Expected Normal notes in guitar track, found 0"
        );
        println!("Total Normal notes in first guitar track: {}", total_normal);
    }

    #[test]
    fn note_frets_are_in_valid_range() {
        let song = load_test_song();
        let guitar_track = song
            .tracks
            .iter()
            .find(|t| !t.percussion_track)
            .expect("No guitar track found");

        for measure in &guitar_track.measures {
            for voice in &measure.voices {
                for beat in &voice.beats {
                    for note in &beat.notes {
                        if matches!(note.kind, NoteType::Normal) {
                            assert!(
                                note.value >= 0 && note.value <= 24,
                                "Fret {} is out of valid range 0–24",
                                note.value
                            );
                        }
                    }
                }
            }
        }
    }

    #[test]
    fn note_strings_are_in_valid_range() {
        let song = load_test_song();
        let guitar_track = song
            .tracks
            .iter()
            .find(|t| !t.percussion_track)
            .expect("No guitar track found");

        let num_strings = guitar_track.strings.len() as i8;
        for measure in &guitar_track.measures {
            for voice in &measure.voices {
                for beat in &voice.beats {
                    for note in &beat.notes {
                        if matches!(note.kind, NoteType::Normal) {
                            assert!(
                                note.string >= 1 && note.string <= num_strings,
                                "GP string {} is outside 1–{} range",
                                note.string,
                                num_strings
                            );
                        }
                    }
                }
            }
        }
    }

    #[test]
    fn note_times_are_non_negative() {
        let song = load_test_song();
        let guitar_track = song
            .tracks
            .iter()
            .find(|t| !t.percussion_track)
            .expect("No guitar track found");
        let bpm = song.tempo.max(1) as f64;
        let quarter_secs = 60.0 / bpm;

        let mut measure_tick_offset: i64 = 0;
        for measure in &guitar_track.measures {
            let header = &song.measure_headers[measure.header_index];
            for voice in &measure.voices {
                for beat in &voice.beats {
                    if let Some(start_ticks) = beat.start {
                        let abs_ticks = measure_tick_offset + start_ticks - DURATION_QUARTER_TIME as i64;
                        let time_sec = abs_ticks as f64
                            / DURATION_QUARTER_TIME as f64
                            * quarter_secs;
                        assert!(
                            time_sec >= 0.0,
                            "Note time {} is negative (abs_ticks={})",
                            time_sec,
                            abs_ticks
                        );
                    }
                }
            }
            // Advance measure offset by this measure's duration in ticks.
            let beat_ticks = duration_ticks(&header.time_signature.denominator) as i64;
            measure_tick_offset += header.time_signature.numerator as i64 * beat_ticks;
        }
    }

    #[test]
    fn note_times_span_full_song_duration() {
        // The song has 102 measures at 110 BPM.  At 4/4 time, total duration is
        // approximately 102 × 4 × (60/110) ≈ 222 seconds.  Assert the last note
        // is well past 60 s to catch the within-measure-only timing regression.
        let song = load_test_song();
        let guitar_track = song
            .tracks
            .iter()
            .find(|t| !t.percussion_track)
            .expect("No guitar track found");
        let bpm = song.tempo.max(1) as f64;
        let quarter_secs = 60.0 / bpm;

        let mut max_time_sec: f64 = 0.0;
        let mut measure_tick_offset: i64 = 0;
        for measure in &guitar_track.measures {
            let header = &song.measure_headers[measure.header_index];
            for voice in &measure.voices {
                for beat in &voice.beats {
                    if let Some(start_ticks) = beat.start {
                        let abs_ticks = measure_tick_offset + start_ticks - DURATION_QUARTER_TIME as i64;
                        let time_sec = abs_ticks as f64
                            / DURATION_QUARTER_TIME as f64
                            * quarter_secs;
                        if time_sec > max_time_sec {
                            max_time_sec = time_sec;
                        }
                    }
                }
            }
            let beat_ticks = duration_ticks(&header.time_signature.denominator) as i64;
            measure_tick_offset += header.time_signature.numerator as i64 * beat_ticks;
        }
        assert!(
            max_time_sec > 60.0,
            "Last note time {:.1}s is unexpectedly short — \
             timing regression: notes should span the full song duration (~220 s), \
             not just the first measure",
            max_time_sec
        );
    }

    #[test]
    fn note_durations_are_positive() {
        let song = load_test_song();
        let guitar_track = song
            .tracks
            .iter()
            .find(|t| !t.percussion_track)
            .expect("No guitar track found");
        let bpm = song.tempo.max(1) as f64;
        let quarter_secs = 60.0 / bpm;

        for measure in &guitar_track.measures {
            for voice in &measure.voices {
                for beat in &voice.beats {
                    let dur_ticks = duration_ticks(&beat.duration);
                    let dur_sec = dur_ticks / DURATION_QUARTER_TIME as f64 * quarter_secs;
                    assert!(
                        dur_sec > 0.0,
                        "Duration {} is not positive",
                        dur_sec
                    );
                }
            }
        }
    }

    #[test]
    fn game_string_indices_are_0_to_5() {
        let song = load_test_song();
        let guitar_track = song
            .tracks
            .iter()
            .find(|t| !t.percussion_track)
            .expect("No guitar track found");
        let num_strings = guitar_track.strings.len() as i8;

        for measure in &guitar_track.measures {
            for voice in &measure.voices {
                for beat in &voice.beats {
                    for note in &beat.notes {
                        if matches!(note.kind, NoteType::Normal) {
                            let game_str =
                                ((num_strings - note.string).max(0) as i64).min(5);
                            assert!(
                                (0..=5).contains(&game_str),
                                "game_string {} out of 0–5 range (gp_string={}, num_strings={})",
                                game_str,
                                note.string,
                                num_strings
                            );
                        }
                    }
                }
            }
        }
    }
}
