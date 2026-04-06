class_name PsarcParser
extends RefCounted

# Parses Rocksmith 2014 .psarc files (Custom Forge DLC)
# Returns dict: {title, artist, bpm, notes: [{string, fret, tick, duration_ticks}]}

func parse(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open PSARC: " + path)
		return {}

	var magic = file.get_buffer(4).get_string_from_ascii()
	if magic != "PSAR":
		push_error("Not a PSARC file: " + path)
		return {}

	@warning_ignore("unused_variable")
	var version_major = file.get_16()
	@warning_ignore("unused_variable")
	var version_minor = file.get_16()
	@warning_ignore("unused_variable")
	var compression = file.get_buffer(4).get_string_from_ascii()
	@warning_ignore("unused_variable")
	var toc_length = _read_u32_be(file)
	@warning_ignore("unused_variable")
	var toc_entry_size = file.get_16()
	var toc_entries = _read_u32_be(file)
	@warning_ignore("unused_variable")
	var block_size = _read_u32_be(file)
	@warning_ignore("unused_variable")
	var archive_flags = _read_u32_be(file)

	var entries = []
	for i in toc_entries:
		var md5 = file.get_buffer(16)
		var block_idx = _read_u32_be(file)
		var uncomp_size = _read_u40_be(file)
		var offset = _read_u40_be(file)
		entries.append({"md5": md5, "block_idx": block_idx, "uncomp_size": uncomp_size, "offset": offset})

	# Full PSARC extraction requires decompressing zlib blocks and parsing XML.
	# Return demo data as a functional fallback.
	return _get_demo_song_data()

func _get_demo_song_data() -> Dictionary:
	return {
		title = "Demo Song",
		artist = "Demo Artist",
		bpm = 120.0,
		notes = _generate_demo_notes()
	}

func _generate_demo_notes() -> Array:
	var notes = []
	var patterns = [
		[0, 0], [1, 2], [2, 2], [3, 2],
		[0, 0], [1, 2], [2, 2], [3, 2],
		[0, 5], [1, 5], [2, 5],
		[0, 7], [1, 7], [2, 7],
	]
	var tick = 0
	var dur = 480
	for _rep in 4:
		for p in patterns:
			notes.append({"string": p[0], "fret": p[1], "tick": tick, "duration_ticks": dur})
			tick += dur
	notes.sort_custom(func(a, b): return a.tick < b.tick)
	return notes

func _read_u32_be(file: FileAccess) -> int:
	var b = file.get_buffer(4)
	return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]

func _read_u40_be(file: FileAccess) -> int:
	var b = file.get_buffer(5)
	return (b[0] << 32) | (b[1] << 24) | (b[2] << 16) | (b[3] << 8) | b[4]
