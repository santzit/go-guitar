/// SNG parser implementing the same algorithms as iminashi/Rocksmith2014.NET
/// (Rocksmith2014.SNG/Cryptography.fs and all Types/*.fs)
use aes::{Aes256, cipher::{BlockEncrypt, KeyInit, generic_array::GenericArray}};
use flate2::read::ZlibDecoder;
use std::io::Read;

// AES-256 key from Rocksmith2014.SNG/Cryptography.fs (sngKeyPC)
const SNG_KEY_PC: [u8; 32] = [
    0xCB, 0x64, 0x8D, 0xF3, 0xD1, 0x2A, 0x16, 0xBF,
    0x71, 0x70, 0x14, 0x14, 0xE6, 0x96, 0x19, 0xEC,
    0x17, 0x1C, 0xCA, 0x5D, 0x2A, 0x14, 0x2E, 0x3E,
    0x59, 0xDE, 0x7A, 0xDD, 0xA1, 0x8A, 0x3A, 0x30,
];

#[derive(Debug, Clone)]
pub struct Note {
    pub time: f32,
    pub string_index: u8,  // 0=Low E (string 6), 5=High e (string 1)
    pub fret: u8,
    pub sustain: f32,
}

pub struct SngData {
    pub song_length: f32,
    pub max_difficulty_notes: Vec<Note>,
}

/// AES-256-CTR: increment counter from LSB, keystream = AES-ECB(counter)
/// Matches Rocksmith2014.SNG/Cryptography.fs aesCtrTransform
fn aes_ctr_decrypt(data: &[u8], iv: &[u8; 16]) -> Vec<u8> {
    let cipher = Aes256::new(GenericArray::from_slice(&SNG_KEY_PC));
    let mut counter = *iv;
    let mut out = Vec::with_capacity(data.len());
    let mut pos = 0usize;
    while pos < data.len() {
        let mut block = GenericArray::clone_from_slice(&counter);
        cipher.encrypt_block(&mut block);
        // Increment counter from LSB (matches `increment` in Cryptography.fs)
        let mut carry = true;
        for b in counter.iter_mut().rev() {
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

/// Read a little-endian u32
fn le_u32(b: &[u8], off: usize) -> u32 {
    u32::from_le_bytes([b[off], b[off+1], b[off+2], b[off+3]])
}

fn le_i32(b: &[u8], off: usize) -> i32 { le_u32(b, off) as i32 }

fn le_f32(b: &[u8], off: usize) -> f32 {
    f32::from_le_bytes([b[off], b[off+1], b[off+2], b[off+3]])
}

fn le_u16(b: &[u8], off: usize) -> u16 {
    u16::from_le_bytes([b[off], b[off+1]])
}

/// Skip a section: count(i32) followed by count * fixed_stride bytes
fn skip_fixed(b: &[u8], off: usize, stride: usize) -> usize {
    let count = le_u32(b, off) as usize;
    off + 4 + count * stride
}

/// Skip NewLinkedDifficulty entries (variable: each has LevelBreak(4) + count(4) + count*4)
fn skip_nld(b: &[u8], mut off: usize) -> usize {
    let count = le_u32(b, off) as usize;
    off += 4;
    for _ in 0..count {
        let n = le_u32(b, off + 4) as usize;
        off += 8 + n * 4;
    }
    off
}

/// Skip a Level (Arrangement) section, returning offset past all levels
fn skip_levels(b: &[u8], off: usize) -> usize {
    let count = le_u32(b, off) as usize;
    let mut pos = off + 4;
    for _ in 0..count {
        pos = skip_one_level(b, pos);
    }
    pos
}

/// Read the highest-difficulty level and return its notes
fn read_best_level_notes(b: &[u8], off: usize) -> Vec<Note> {
    let count = le_u32(b, off) as usize;
    let mut pos = off + 4;
    let mut best_diff = -1i32;
    let mut best_notes: Vec<Note> = Vec::new();
    for _ in 0..count {
        let diff = le_i32(b, pos);
        let (notes, next) = parse_level(b, pos);
        if diff > best_diff {
            best_diff = diff;
            best_notes = notes;
        }
        pos = next;
    }
    best_notes
}

fn skip_one_level(b: &[u8], pos: usize) -> usize {
    parse_level(b, pos).1
}

fn parse_level(b: &[u8], pos: usize) -> (Vec<Note>, usize) {
    let mut off = pos + 4; // skip difficulty (i32)

    // Anchors: count + count * 28 bytes each
    // (StartTime f32 + EndTime f32 + FirstNoteTime f32 + LastNoteTime f32 + FretId i8 + 3pad + Width i32 + PhraseIterationId i32)
    off = skip_fixed(b, off, 28);

    // AnchorExtensions: count + count * 12 bytes each
    // (BeatTime f32 + FretId i8 + i32 + i16 + i8)
    off = skip_fixed(b, off, 12);

    // Fingerprints1: count + count * 20 bytes each (ChordId i32 + 4*f32)
    off = skip_fixed(b, off, 20);
    // Fingerprints2
    off = skip_fixed(b, off, 20);

    // Notes
    let note_count = le_u32(b, off) as usize;
    off += 4;
    let mut notes = Vec::with_capacity(note_count);
    for _ in 0..note_count {
        let (note, next) = parse_note(b, off);
        notes.push(note);
        off = next;
    }

    // PhraseCount + AverageNotesPerIteration[phrase_count]
    let phrase_count = le_u32(b, off) as usize;
    off += 4 + phrase_count * 4;

    // PhraseIterationCount1 + NotesInIteration1[count]
    let pic1 = le_u32(b, off) as usize;
    off += 4 + pic1 * 4;

    // PhraseIterationCount2 + NotesInIteration2[count]
    let pic2 = le_u32(b, off) as usize;
    off += 4 + pic2 * 4;

    (notes, off)
}

/// Parse one Note, returning (Note, next_offset)
/// Layout matches Rocksmith2014.SNG/Types/Note.fs
fn parse_note(b: &[u8], off: usize) -> (Note, usize) {
    // Mask(u32) + Flags(u32) + Hash(u32) + Time(f32) = 16 bytes
    // StringIndex(i8) + Fret(i8) + AnchorFret(i8) + AnchorWidth(i8) = 4 bytes
    // ChordId(i32) + ChordNotesId(i32) + PhraseId(i32) + PhraseIterationId(i32) = 16 bytes
    // FingerPrintId[2](i16) = 4 bytes
    // NextIterNote(i16) + PrevIterNote(i16) + ParentPrevNote(i16) = 6 bytes
    // SlideTo(i8)+SlideUnpitchTo(i8)+LeftHand(i8)+Tap(i8)+PickDirection(i8)+Slap(i8)+Pluck(i8) = 7 bytes
    // Vibrato(i16) = 2 bytes
    // Sustain(f32) + MaxBend(f32) = 8 bytes
    // BendData: count(i32) + count * 12 bytes
    // Fixed prefix: 16+4+16+4+6+7+2+8 = 63 bytes, then BendData count at 63
    let time         = le_f32(b, off + 12);
    let string_index = b[off + 16];
    let fret         = b[off + 17];
    let sustain      = le_f32(b, off + 57);
    let bend_count   = le_u32(b, off + 65) as usize;
    let next = off + 69 + bend_count * 12;
    (Note { time, string_index, fret, sustain }, next)
}

/// Decrypt and decompress SNG bytes, then parse notes from highest difficulty
pub fn parse(raw: &[u8]) -> Result<SngData, String> {
    if raw.len() < 24 { return Err("SNG too short".into()); }

    // Validate magic (0x4A as LE u32)
    let magic = le_u32(raw, 0);
    if magic != 0x4A { return Err(format!("Bad SNG magic: {:#x}", magic)); }

    // IV is at bytes 8..24 (after magic u32 + header u32)
    let iv: [u8; 16] = raw[8..24].try_into().map_err(|_| "bad IV")?;
    let encrypted = &raw[24..];

    // Decrypt with AES-256-CTR
    let decrypted = aes_ctr_decrypt(encrypted, &iv);
    if decrypted.len() < 4 { return Err("Decrypted SNG too short".into()); }

    let plain_len = le_u32(&decrypted, 0) as usize;
    let compressed = &decrypted[4..];

    // Decompress with zlib
    let mut plain = Vec::with_capacity(plain_len);
    ZlibDecoder::new(compressed).read_to_end(&mut plain)
        .map_err(|e| format!("SNG decompress: {}", e))?;

    parse_plain(&plain)
}

fn parse_plain(b: &[u8]) -> Result<SngData, String> {
    if b.len() < 4 { return Err("Empty SNG".into()); }
    let mut off = 0usize;

    // Beat (16 bytes each): time(f32)+measure(i16)+beat(i16)+phraseIter(i32)+mask(i32)
    off = skip_fixed(b, off, 16);
    // Phrase (44 bytes each)
    off = skip_fixed(b, off, 44);
    // Chord (72 bytes each)
    off = skip_fixed(b, off, 72);
    // ChordNotes: 6*u32(24) + 6*BendData32(6*388=2328) + 6*i8(6) + 6*i8(6) + 6*i16(12) = 2376
    off = skip_fixed(b, off, 2376);

    // Vocals: if count > 0, also skip SymbolsHeader/Texture/Definition
    let vocal_count = le_u32(b, off) as usize;
    off += 4 + vocal_count * 60;
    if vocal_count > 0 {
        // SymbolsHeader: 8 * i32 = 32 bytes each
        off = skip_fixed(b, off, 32);
        // SymbolsTexture: Font[128]+FontPathLength(i32)+Unk(i32)+Width(i32)+Height(i32) = 144
        off = skip_fixed(b, off, 144);
        // SymbolDefinition: Symbol[12]+Outer(16)+Inner(16) = 44
        off = skip_fixed(b, off, 44);
    }

    // PhraseIteration: PhraseId(i32)+StartTime(f32)+EndTime(f32)+Difficulty[3](i32) = 24
    off = skip_fixed(b, off, 24);
    // PhraseExtraInfo: 3*i32 + i8 + i16 + 1pad = 16
    off = skip_fixed(b, off, 16);
    // NewLinkedDifficulty (variable)
    off = skip_nld(b, off);
    // Action: Time(f32)+ActionName[256] = 260
    off = skip_fixed(b, off, 260);
    // Event: Time(f32)+Name[256] = 260
    off = skip_fixed(b, off, 260);
    // Tone: f32+i32 = 8
    off = skip_fixed(b, off, 8);
    // DNA: f32+i32 = 8
    off = skip_fixed(b, off, 8);
    // Section: Name[32]+Number(i32)+StartTime(f32)+EndTime(f32)+StartPhraseIterationId(i32)+EndPhraseIterationId(i32)+StringMask[36](i8) = 88
    off = skip_fixed(b, off, 88);

    // Levels (arrangements) - find highest difficulty
    let notes = read_best_level_notes(b, off);
    let _ = skip_levels(b, off); // (already parsed above, just for completeness)

    // MetaData SongLength: skip MaxScore(f64*4) + FirstBeatLength(f32) + StartTime(f32) + CapoFretId(i8) + DateTime[32] + Part(i16) = 45
    // Then SongLength(f32)
    // For simplicity read it after levels
    let meta_off = skip_levels(b, off);
    let song_length = if meta_off + 45 + 4 <= b.len() {
        le_f32(b, meta_off + 45)
    } else {
        0.0
    };

    Ok(SngData { song_length, max_difficulty_notes: notes })
}
