/// PSARC parser implementing the same algorithms as iminashi/Rocksmith2014.NET
/// (Rocksmith2014.PSARC/Cryptography.fs and PSARC.fs)
use aes::Aes256;
use cfb_mode::Decryptor;
use cipher::{KeyIvInit, StreamCipher};
use flate2::read::ZlibDecoder;
use std::io::Read;

// AES-256-CFB-128 key from Rocksmith2014.PSARC/Cryptography.fs
const PSARC_KEY: [u8; 32] = [
    0xC5, 0x3D, 0xB2, 0x38, 0x70, 0xA1, 0xA2, 0xF7,
    0x1C, 0xAE, 0x64, 0x06, 0x1F, 0xDD, 0x0E, 0x11,
    0x57, 0x30, 0x9D, 0xC8, 0x52, 0x04, 0xD4, 0xC5,
    0xBF, 0xDF, 0x25, 0x09, 0x0D, 0xF2, 0x57, 0x2C,
];

pub struct PsarcEntry {
    pub name: String,
    pub data: Vec<u8>,
}

pub struct Psarc {
    pub entries: Vec<PsarcEntry>,
}

fn read_be_u32(b: &[u8], off: usize) -> u32 {
    u32::from_be_bytes([b[off], b[off+1], b[off+2], b[off+3]])
}

fn read_be_u16(b: &[u8], off: usize) -> u16 {
    u16::from_be_bytes([b[off], b[off+1]])
}

/// Read a 5-byte big-endian integer (used for file offsets and sizes in PSARC)
fn read_be_u40(b: &[u8], off: usize) -> u64 {
    ((b[off] as u64) << 32)
        | ((b[off+1] as u64) << 24)
        | ((b[off+2] as u64) << 16)
        | ((b[off+3] as u64) << 8)
        | (b[off+4] as u64)
}

/// Decrypt the PSARC TOC using AES-256-CFB-128 with a zero IV
fn decrypt_toc(data: &mut [u8]) {
    let iv = [0u8; 16];
    let mut dec = Decryptor::<Aes256>::new((&PSARC_KEY).into(), (&iv).into());
    dec.apply_keystream(data);
}

/// Decompress a zlib-compressed block
fn decompress_block(data: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    ZlibDecoder::new(data).read_to_end(&mut out).unwrap_or(0);
    if out.is_empty() {
        out.extend_from_slice(data); // raw (uncompressed) block
    }
    out
}

pub fn parse(raw: &[u8]) -> Result<Psarc, String> {
    if raw.len() < 32 { return Err("Too short".into()); }

    // Header (32 bytes, big-endian)
    let toc_len       = read_be_u32(raw,  12) as usize;
    let entry_size    = read_be_u32(raw,  16) as usize; // always 30
    let num_entries   = read_be_u32(raw,  20) as usize;
    let block_size    = read_be_u32(raw,  24) as usize; // 65536
    let _arch_flags   = read_be_u32(raw,  28);

    if toc_len > raw.len() { return Err("TOC length exceeds file".into()); }

    // Decrypt TOC (everything after the 32-byte header up to toc_len)
    let mut toc = raw[32..toc_len].to_vec();
    decrypt_toc(&mut toc);

    // Parse entries (each 30 bytes)
    let entries_bytes = num_entries * entry_size;
    if entries_bytes > toc.len() { return Err("Entry table overflow".into()); }

    struct RawEntry {
        zblock_index: u32,
        orig_size: u64,
        offset: u64,
    }
    let mut raw_entries: Vec<RawEntry> = Vec::with_capacity(num_entries);
    for i in 0..num_entries {
        let base = i * entry_size;
        // [0..16] = MD5, [16..20] = zblock_index, [20..25] = orig_size, [25..30] = offset
        let zblock_index = read_be_u32(&toc, base + 16);
        let orig_size    = read_be_u40(&toc, base + 20);
        let offset       = read_be_u40(&toc, base + 25);
        raw_entries.push(RawEntry { zblock_index, orig_size, offset });
    }

    // Block size table: 2-byte big-endian entries after the TOC entries
    let bst_offset = entries_bytes;
    let bst_count = (toc.len() - bst_offset) / 2;
    let mut block_sizes: Vec<u16> = Vec::with_capacity(bst_count);
    for i in 0..bst_count {
        block_sizes.push(read_be_u16(&toc, bst_offset + i * 2));
    }

    // Read manifest (entry 0) to get file names
    let manifest_data = read_entry_data(raw, &raw_entries[0], &block_sizes, block_size);
    let manifest_str = String::from_utf8_lossy(&manifest_data).into_owned();
    let names: Vec<String> = manifest_str.split('\n').filter(|s| !s.is_empty())
        .map(|s| s.to_owned()).collect();

    // Read remaining entries
    let mut entries: Vec<PsarcEntry> = Vec::new();
    for (i, name) in names.iter().enumerate() {
        if i + 1 >= raw_entries.len() { break; }
        let data = read_entry_data(raw, &raw_entries[i + 1], &block_sizes, block_size);
        entries.push(PsarcEntry { name: name.clone(), data });
    }

    Ok(Psarc { entries })
}

struct RawEntry {
    zblock_index: u32,
    orig_size: u64,
    offset: u64,
}

fn read_entry_data(
    raw: &[u8],
    entry: &RawEntry,
    block_sizes: &[u16],
    block_size: usize,
) -> Vec<u8> {
    let mut result = Vec::new();
    let mut zbi = entry.zblock_index as usize;
    let mut remaining = entry.orig_size as usize;
    let mut pos = entry.offset as usize;

    while remaining > 0 && zbi < block_sizes.len() {
        let bs = block_sizes[zbi] as usize;
        if bs == 0 {
            // Uncompressed full block
            let take = remaining.min(block_size);
            if pos + take <= raw.len() {
                result.extend_from_slice(&raw[pos..pos + take]);
            }
            pos += take;
            remaining = remaining.saturating_sub(take);
        } else {
            if pos + bs > raw.len() { break; }
            let chunk = &raw[pos..pos + bs];
            // Check for zlib header (0x78 DA or similar)
            let decompressed = if chunk.len() >= 2 && chunk[0] == 0x78 {
                let mut out = Vec::new();
                let _ = ZlibDecoder::new(chunk).read_to_end(&mut out);
                if out.is_empty() { chunk.to_vec() } else { out }
            } else {
                chunk.to_vec()
            };
            let take = remaining.min(decompressed.len());
            result.extend_from_slice(&decompressed[..take]);
            remaining = remaining.saturating_sub(take);
            pos += bs;
        }
        zbi += 1;
    }
    result
}

impl RawEntry {
    fn zblock_index(&self) -> u32 { self.zblock_index }
    fn orig_size(&self) -> u64 { self.orig_size }
    fn offset(&self) -> u64 { self.offset }
}
