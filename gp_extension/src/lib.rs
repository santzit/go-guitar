use godot::prelude::*;

mod psarc;
mod sng;
mod loader;

struct GpExtension;

#[gdextension]
unsafe impl ExtensionLibrary for GpExtension {}
