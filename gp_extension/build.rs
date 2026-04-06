//! Build script for gp_extension.
//!
//! The guitar-pitch-detection dependency has its own build.rs that compiles
//! the cycfi/q C++ wrapper.  This build script just validates the submodule
//! is initialised before Cargo tries to compile anything, giving a clear error.

use std::path::Path;

fn main() {
    let q_dir = "../vendor/guitar-pitch-detection/vendor/q/q_lib/include";
    if !Path::new(q_dir).exists() {
        panic!(
            "\n\n\
             ── cycfi/q submodule not found ─────────────────────────────\n\
             Expected: {}\n\
             Run:  git submodule update --init --recursive\n\
             ────────────────────────────────────────────────────────────\n",
            q_dir
        );
    }
}
