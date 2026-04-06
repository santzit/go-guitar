/// PSARC parser — algorithms ported from iminashi/Rocksmith2014.NET
/// (Rocksmith2014.PSARC/Cryptography.fs and PSARC.fs)
use aes::Aes256;
use cfb_mode::cipher::{AsyncStreamCipher, KeyIvInit};
use flate2::read::ZlibDecoder;
use std::io::Read;

// AES-256-CFB-128 key  (Rocksmith2014.PSARC/Cryptography.fs – psarcKey)
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

// ── helpers ───────────────────────────────────────────────────────────────────

fn be_u32(b: &[u8], o: usize) -> u32 {
    u32::from_be_bytes([b[o], b[o+1], b[o+2], b[o+3]])
}
fn be_u16(b: &[u8], o: usize) -> u16 {
    u16::from_be_bytes([b[o], b[o+1]])
}
/// 5-byte big-endian integer (file offsets / original sizes in PSARC)
fn be_u40(b: &[u8], o: usize) -> u64 {
    ((b[o] as u64) << 32) | ((b[o+1] as u64) << 24)
        | ((b[o+2] as u64) << 16) | ((b[o+3] as u64) << 8)
        | (b[o+4] as u64)
}

// ── crypto ────────────────────────────────────────────────────────────────────

type Aes256CfbDec = cfb_mode::Decryptor<Aes256>;

fn decrypt_toc(data: &mut [u8]) {
    let iv = [0u8; 16];
    Aes256CfbDec::new((&PSARC_KEY).into(), (&iv).into()).decrypt(data);
}

// ── entry table ───────────────────────────────────────────────────────────────

struct RawEntry {
    zblock_index: u32,
    orig_size:    u64,
    offset:       u64,
}

fn inflate_entry(raw: &[u8], entry: &RawEntry, bsz: &[u16], block_size: usize) -> Vec<u8> {
    let mut out       = Vec::new();
    let mut remaining = entry.orig_size as usize;
    let mut pos       = entry.offset as usize;
    let mut zbi       = entry.zblock_index as usize;

    while remaining > 0 && zbi < bsz.len() {
        let bs = bsz[zbi] as usize;
        if bs == 0 {
            // uncompressed full block
            let take = remaining.min(block_size);
            if pos + take <= raw.len() {
                out.extend_from_slice(&raw[pos..pos + take]);
            }
            pos       += take;
            remaining  = remaining.saturating_sub(take);
        } else {
            if pos + bs > raw.len() { break; }
            let chunk = &raw[pos..pos + bs];
            // zlib magic byte 0x78 (deflate)
            let decompressed = if chunk.len() >= 2 && chunk[0] == 0x78 {
                let mut d = Vec::new();
                let _ = ZlibDecoder::new(chunk).read_to_end(&mut d);
                if d.is_empty() { chunk.to_vec() } else { d }
            } else {
                chunk.to_vec()
            };
            let take = remaining.min(decompressed.len());
            out.extend_from_slice(&decompressed[..take]);
            remaining  = remaining.saturating_sub(take);
            pos       += bs;
        }
        zbi += 1;
    }
    out
}

// ── public API ────────────────────────────────────────────────────────────────

pub fn parse(raw: &[u8]) -> Result<Psarc, String> {
    if raw.len() < 32 { return Err("file too short".into()); }

    let toc_len    = be_u32(raw, 12) as usize;
    let entry_size = be_u32(raw, 16) as usize; // 30
    let num_files  = be_u32(raw, 20) as usize;
    let block_size = be_u32(raw, 24) as usize; // 65536
    let _flags     = be_u32(raw, 28);

    if toc_len > raw.len() { return Err("TOC length exceeds file".into()); }

    let mut toc = raw[32..toc_len].to_vec();
    decrypt_toc(&mut toc);

    let entries_bytes = num_files * entry_size;
    if entries_bytes > toc.len() { return Err("TOC entries overflow".into()); }

    let mut raw_entries: Vec<RawEntry> = Vec::with_capacity(num_files);
    for i in 0..num_files {
        let b = i * entry_size;
        // layout: MD5[16] | zblock_index(u32) | orig_size(u40) | offset(u40)
        raw_entries.push(RawEntry {
            zblock_index: be_u32(&toc, b + 16),
            orig_size:    be_u40(&toc, b + 20),
            offset:       be_u40(&toc, b + 25),
        });
    }

    // block-size table: 2 bytes each, immediately after entry table
    let bst_off   = entries_bytes;
    let bst_count = (toc.len() - bst_off) / 2;
    let mut bsz: Vec<u16> = Vec::with_capacity(bst_count);
    for i in 0..bst_count {
        bsz.push(be_u16(&toc, bst_off + i * 2));
    }

    // manifest (entry 0) → newline-separated list of internal paths
    let manifest = inflate_entry(raw, &raw_entries[0], &bsz, block_size);
    let manifest_str = String::from_utf8_lossy(&manifest);
    let names: Vec<String> = manifest_str
        .split('\n').filter(|s| !s.is_empty()).map(|s| s.to_owned()).collect();

    let mut entries: Vec<PsarcEntry> = Vec::with_capacity(names.len());
    for (i, name) in names.iter().enumerate() {
        if i + 1 >= raw_entries.len() { break; }
        let data = inflate_entry(raw, &raw_entries[i + 1], &bsz, block_size);
        entries.push(PsarcEntry { name: name.clone(), data });
    }

    Ok(Psarc { entries })
}
