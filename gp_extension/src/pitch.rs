/// PitchDetector — Godot GDExtension class
/// Wraps guitar_pitch_detection::GuitarPitchDetector (cycfi/q BACF algorithm)
/// for real-time note, chord, and technique detection from microphone/RTC audio.
use godot::prelude::*;
use guitar_pitch_detection::{GuitarPitchDetector, GuitarTechnique};

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct PitchDetector {
    base: Base<RefCounted>,
    detector: Option<GuitarPitchDetector>,
}

#[godot_api]
impl IRefCounted for PitchDetector {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base, detector: None }
    }
}

#[godot_api]
impl PitchDetector {
    /// Initialise for the given sample rate and frame size.
    /// Must be called before `process_frame`.
    #[func]
    fn setup(&mut self, sample_rate: i64, frame_size: i64) {
        self.detector = Some(GuitarPitchDetector::new(
            sample_rate as u32,
            frame_size as usize,
        ));
    }

    /// Process a mono f32 PCM frame, return detected notes / chord / techniques.
    ///
    /// Returns:
    ///   { "notes":      Array[{"name":String,"frequency":float,"midi_note":int,"confidence":float}],
    ///     "chord_name": String,        # "" if none
    ///     "techniques": Array[String]  # e.g. "bend:+0.50", "vibrato:5.2hz:0.15st"
    ///   }
    #[func]
    fn process_frame(&mut self, samples: PackedFloat32Array) -> VarDictionary {
        let mut d = VarDictionary::new();
        let Some(det) = self.detector.as_mut() else {
            d.set(&"notes".to_variant(),      &VarArray::new().to_variant());
            d.set(&"chord_name".to_variant(),  &GString::from("").to_variant());
            d.set(&"techniques".to_variant(), &VarArray::new().to_variant());
            return d;
        };

        let result = det.process(samples.as_slice());

        // ── notes ────────────────────────────────────────────────────────────
        let mut notes_arr = VarArray::new();
        for n in &result.notes {
            let mut nd = VarDictionary::new();
            nd.set(&"name".to_variant(),       &GString::from(n.name).to_variant());
            nd.set(&"frequency".to_variant(),  &(n.frequency as f64).to_variant());
            nd.set(&"midi_note".to_variant(),  &(n.midi_note as i64).to_variant());
            nd.set(&"confidence".to_variant(), &(n.confidence as f64).to_variant());
            notes_arr.push(&nd.to_variant());
        }

        // ── chord ────────────────────────────────────────────────────────────
        let chord_name = result.chord
            .as_ref()
            .map(|c| c.name.as_str().to_owned())
            .unwrap_or_default();

        // ── techniques ───────────────────────────────────────────────────────
        let mut tech_arr = VarArray::new();
        for t in &result.techniques {
            let s: String = match t {
                GuitarTechnique::Bend { semitones } =>
                    format!("bend:{:+.2}", semitones),
                GuitarTechnique::Slide { from_midi, to_midi, ascending } =>
                    format!("slide:{}:{}:{}", from_midi, to_midi,
                            if *ascending { "up" } else { "down" }),
                GuitarTechnique::Vibrato { rate_hz, depth_semitones } =>
                    format!("vibrato:{:.1}hz:{:.2}st", rate_hz, depth_semitones),
                GuitarTechnique::PalmMute => "palm_mute".into(),
                GuitarTechnique::HammerOn => "hammer_on".into(),
                GuitarTechnique::PullOff  => "pull_off".into(),
            };
            tech_arr.push(&GString::from(s.as_str()).to_variant());
        }

        d.set(&"notes".to_variant(),      &notes_arr.to_variant());
        d.set(&"chord_name".to_variant(),  &GString::from(chord_name.as_str()).to_variant());
        d.set(&"techniques".to_variant(), &tech_arr.to_variant());
        d
    }

    /// Reset all detector state (call between songs).
    #[func]
    fn reset(&mut self) {
        if let Some(det) = self.detector.as_mut() {
            det.reset();
        }
    }
}
