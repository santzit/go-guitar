use godot::prelude::*;

mod psarc;
mod sng;
mod loader;
mod pitch;

struct GpExtension;

#[gdextension]
unsafe impl ExtensionLibrary for GpExtension {}
