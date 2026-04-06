/// SNG parser — algorithms ported from iminashi/Rocksmith2014.NET
/// (Rocksmith2014.SNG/Cryptography.fs + all Types/*.fs)
use aes::{Aes256, cipher::{BlockEncrypt, KeyInit, generic_array::GenericArray}};
use flate2::read::ZlibDecoder;
use std::io::Read;

// AES-256 ECB key  (Rocksmith2014.SNG/Cryptography.fs – sngKeyPC)
const SNG_KEY_PC: [u8; 32] = [
    0xCB, 0x64, 0x8D, 0xF3, 0xD1, 0x2A, 0x16, 0xBF,
    0x71, 0x70, 0x14, 0x14, 0xE6, 0x96, 0x19, 0xEC,
    0x17, 0x1C, 0xCA, 0x5D, 0x2A, 0x14, 0x2E, 0x3E,
    0x59, 0xDE, 0x7A, 0xDD, 0xA1, 0x8A, 0x3A, 0x30,
];

// ── public types ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct Note {
    /// Seconds from song start
    pub time: f32,
    /// Rocksmith string index: 0 = Low E (6th string), 5 = High e (1st string)
    pub string_index: u8,
    pub fret: u8,
    /// Sustain duration in seconds (0 = normal attack)
    pub sustain: f32,
}

pub struct SngData {
    pub song_length: f32,
    /// Notes from the highest-difficulty arrangement level
    pub notes: Vec<Note>,
}

// ── AES-256-CTR decryption ────────────────────────────────────────────────────
// Matches Rocksmith2014.SNG/Cryptography.fs aesCtrTransform:
//   keystream block i = AES-ECB(counter),  counter incremented from LSB.

fn aes_ctr_decrypt(data: &[u8], iv: &[u8; 16]) -> Vec<u8> {
    let cipher  = Aes256::new(GenericArray::from_slice(&SNG_KEY_PC));
    let mut ctr = *iv;
    let mut out = Vec::with_capacity(data.len());
    let mut pos = 0usize;
    while pos < data.len() {
        let mut block = GenericArray::clone_from_slice(&ctr);
        cipher.encrypt_block(&mut block);
        // increment counter from LSB
        let mut carry = true;
        for b in ctr.iter_mut().rev() {
            if carry { let (v, c) = b.overflowing_add(1); *b = v; carry = c; } else { break; }
        }
        let end = (pos + 16).min(data.len());
        for (i, byte) in data[pos..end].iter().enumerate() {
            out.push(byte ^ block[i]);
        }
        pos += 16;
    }
    out
}

// ── little-endian helpers ─────────────────────────────────────────────────────

fn le_u32(b: &[u8], o: usize) -> u32 {
    u32::from_le_bytes([b[o], b[o+1], b[o+2], b[o+3]])
}
fn le_i32(b: &[u8], o: usize) -> i32 { le_u32(b, o) as i32 }
fn le_f32(b: &[u8], o: usize) -> f32 {
    f32::from_le_bytes([b[o], b[o+1], b[o+2], b[o+3]])
}

// ── section skippers ──────────────────────────────────────────────────────────

/// Skip: count(u32) + count × stride bytes
fn skip_fixed(b: &[u8], o: usize, stride: usize) -> usize {
    o + 4 + le_u32(b, o) as usize * stride
}

/// Skip NewLinkedDifficulty (each entry: LevelBreak(4) + n_phrases(4) + n_phrases×4)
fn skip_nld(b: &[u8], mut o: usize) -> usize {
    let count = le_u32(b, o) as usize;
    o += 4;
    for _ in 0..count {
        let n = le_u32(b, o + 4) as usize;
        o += 8 + n * 4;
    }
    o
}

// ── Note parser ───────────────────────────────────────────────────────────────
// Binary layout (Rocksmith2014.SNG/Types/Note.fs), all little-endian:
//   0  Mask(u32)               4
//   4  Flags(u32)              4
//   8  Hash(u32)               4
//  12  Time(f32)               4
//  16  StringIndex(i8)         1
//  17  Fret(i8)                1
//  18  AnchorFret(i8)          1
//  19  AnchorWidth(i8)         1
//  20  ChordId(i32)            4
//  24  ChordNotesId(i32)       4
//  28  PhraseId(i32)           4
//  32  PhraseIterationId(i32)  4
//  36  FingerPrintId[2](i16)   4
//  40  NextIterNote(i16)       2
//  42  PrevIterNote(i16)       2
//  44  ParentPrevNote(i16)     2
//  46  SlideTo(i8)             1
//  47  SlideUnpitchTo(i8)      1
//  48  LeftHand(i8)            1
//  49  Tap(i8)                 1
//  50  PickDirection(i8)       1
//  51  Slap(i8)                1
//  52  Pluck(i8)               1
//  53  Vibrato(i16)            2
//  55  Sustain(f32)            4
//  59  MaxBend(f32)            4
//  63  BendData count(i32)     4
//  67  BendData[n] (12 bytes each)

fn parse_note(b: &[u8], o: usize) -> (Note, usize) {
    let time         = le_f32(b, o + 12);
    let string_index = b[o + 16];
    let fret         = b[o + 17];
    let sustain      = le_f32(b, o + 55);
    let bend_count   = le_u32(b, o + 63) as usize;
    let next         = o + 67 + bend_count * 12;
    (Note { time, string_index, fret, sustain }, next)
}

// ── Level parser ──────────────────────────────────────────────────────────────
// Rocksmith2014.SNG/Types/Level.fs read order:
//   Difficulty(i32)
//   Anchors          count + n×28
//   AnchorExtensions count + n×12
//   Fingerprints1    count + n×20
//   Fingerprints2    count + n×20
//   Notes            count + variable
//   PhraseCount(i32) + f32[n]
//   PhraseIterCount1 + i32[n]
//   PhraseIterCount2 + i32[n]

fn parse_level(b: &[u8], o: usize) -> (Vec<Note>, usize) {
    let mut off = o + 4;              // skip Difficulty(i32)
    off = skip_fixed(b, off, 28);    // Anchors
    off = skip_fixed(b, off, 12);    // AnchorExtensions
    off = skip_fixed(b, off, 20);    // Fingerprints1
    off = skip_fixed(b, off, 20);    // Fingerprints2

    let note_count = le_u32(b, off) as usize;
    off += 4;
    let mut notes = Vec::with_capacity(note_count);
    for _ in 0..note_count {
        let (note, next) = parse_note(b, off);
        notes.push(note);
        off = next;
    }

    let pc  = le_u32(b, off) as usize; off += 4 + pc * 4;
    let pi1 = le_u32(b, off) as usize; off += 4 + pi1 * 4;
    let pi2 = le_u32(b, off) as usize; off += 4 + pi2 * 4;

    (notes, off)
}

fn skip_level(b: &[u8], o: usize) -> usize { parse_level(b, o).1 }

fn best_level_notes(b: &[u8], o: usize) -> Vec<Note> {
    let count = le_u32(b, o) as usize;
    let mut pos = o + 4;
    let mut best_diff = -1i32;
    let mut best: Vec<Note> = Vec::new();
    for _ in 0..count {
        let diff = le_i32(b, pos);
        let (notes, next) = parse_level(b, pos);
        if diff > best_diff {
            best_diff = diff;
            best = notes;
        }
        pos = next;
    }
    best
}

fn skip_levels(b: &[u8], o: usize) -> usize {
    let count = le_u32(b, o) as usize;
    let mut pos = o + 4;
    for _ in 0..count { pos = skip_level(b, pos); }
    pos
}

// ── top-level SNG parse ───────────────────────────────────────────────────────

/// Decrypt + decompress raw SNG bytes, extract notes from highest difficulty level.
pub fn parse(raw: &[u8]) -> Result<SngData, String> {
    if raw.len() < 24 { return Err("SNG too short".into()); }
    let magic = le_u32(raw, 0);
    if magic != 0x4A { return Err(format!("bad SNG magic {:#x}", magic)); }

    // IV at bytes 8..24
    let iv: [u8; 16] = raw[8..24].try_into().map_err(|_| "bad IV")?;
    let decrypted = aes_ctr_decrypt(&raw[24..], &iv);
    if decrypted.len() < 4 { return Err("decrypted SNG too short".into()); }

    let plain_len = le_u32(&decrypted, 0) as usize;
    let mut plain = Vec::with_capacity(plain_len);
    ZlibDecoder::new(&decrypted[4..])
        .read_to_end(&mut plain)
        .map_err(|e| format!("SNG zlib: {}", e))?;

    parse_plain(&plain)
}

fn parse_plain(b: &[u8]) -> Result<SngData, String> {
    let mut off = 0usize;

    // ── section order: Rocksmith2014.SNG/Types/SNG.fs ─────────────────────────
    // Beat:        time(f32)+measure(i16)+beat(i16)+phraseIter(i32)+mask(i32) = 16
    off = skip_fixed(b, off, 16);
    // Phrase:      Solo(u8)+Disp(u8)+Ignore(u8)+Pad(u8)+MaxDiff(i32)+Links(i32)+Name[32] = 44
    off = skip_fixed(b, off, 44);
    // Chord:       Mask(u32)+Frets[6]+Fingers[6]+Notes[6](i32)+Name[32] = 72
    off = skip_fixed(b, off, 72);
    // ChordNotes:  NoteMask[6](u32)+BendData[6]+SlideTo[6]+SlideUnpitchTo[6]+Vibrato[6] = 2376
    off = skip_fixed(b, off, 2376);

    // Vocals (count + n×60; if count>0 also skip 3 symbol sections)
    let vocal_count = le_u32(b, off) as usize;
    off += 4 + vocal_count * 60;
    if vocal_count > 0 {
        off = skip_fixed(b, off, 32);  // SymbolsHeader: 8×i32
        off = skip_fixed(b, off, 144); // SymbolsTexture: Font[128]+4×i32
        off = skip_fixed(b, off, 44);  // SymbolDefinition: Symbol[12]+Outer+Inner
    }

    // PhraseIteration: PhraseId(i32)+StartTime(f32)+EndTime(f32)+Difficulty[3](i32) = 24
    off = skip_fixed(b, off, 24);
    // PhraseExtraInfo: 3×i32+i8+i16+1pad = 16
    off = skip_fixed(b, off, 16);
    off = skip_nld(b, off);            // NewLinkedDifficulty (variable)
    off = skip_fixed(b, off, 260);     // Action:  Time(f32)+Name[256]
    off = skip_fixed(b, off, 260);     // Event:   Time(f32)+Name[256]
    off = skip_fixed(b, off, 8);       // Tone:    f32+i32
    off = skip_fixed(b, off, 8);       // DNA:     f32+i32
    // Section: Name[32]+Number(i32)+StartTime(f32)+EndTime(f32)+StartPI(i32)+EndPI(i32)+StringMask[36] = 88
    off = skip_fixed(b, off, 88);

    // Levels — extract notes from the highest-difficulty level
    let notes   = best_level_notes(b, off);
    let meta_off = skip_levels(b, off);

    // MetaData layout (Rocksmith2014.SNG/Types/MetaData.fs):
    //   MaxScore(f64=8) + MaxNotesAndChords(f64=8) + MaxNotesAndChordsReal(f64=8)
    //   + PointsPerNote(f64=8) + FirstBeatLength(f32=4) + StartTime(f32=4)
    //   + CapoFretId(i8=1) + LastConversionDateTime[32] + Part(i16=2)
    //   + SongLength(f32=4) …
    // Offset of SongLength = 8+8+8+8+4+4+1+32+2 = 75
    let song_length = if meta_off + 79 <= b.len() {
        le_f32(b, meta_off + 75)
    } else {
        0.0
    };

    Ok(SngData { song_length, notes })
}
