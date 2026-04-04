extends SceneTree

const SONG_PATH := "res://DLC/the-ramones-baby_i_love_you_3.gp5"
const START_DELAY := 3.0
const FINGER_PREVIEW := 2.0
const HIT_WINDOW := 0.18

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not ClassDB.class_exists("GpParser"):
        printerr("GpParser not found")
        quit(1)
        return
    
    var file := FileAccess.open(SONG_PATH, FileAccess.READ)
    var bytes := file.get_buffer(file.get_length())
    file.close()
    
    var parser = ClassDB.instantiate("GpParser")
    var data = parser.parse_bytes(bytes, "gp5")
    var notes = data.get("notes", [])
    
    print("Total notes: %d" % notes.size())
    
    # Check notes visible at current_time = 90.0
    var current_time = 90.0
    
    # Finger preview notes (fretboard dots)
    print("\n=== FINGER PREVIEW at t=90.0 (dots in fretboard) ===")
    var strings = ["E","A","D","G","B","e"]
    var dot_count = 0
    for note in notes:
        var tth = (float(note["time"]) + START_DELAY) - current_time
        if tth < -HIT_WINDOW or tth > FINGER_PREVIEW:
            continue
        var si = int(note["string"])
        var fret = int(note.get("fret", 0))
        print("  %s(str=%d) fret=%d at song_time=%.2fs tth=%.3fs" % [strings[si], si, fret, float(note["time"]), tth])
        dot_count += 1
    print("Total visible dots: %d" % dot_count)
    
    # Highway notes (3.5s look-ahead)
    print("\n=== HIGHWAY NOTES at t=90.0 (last 10 by time) ===")
    var hw_notes = []
    for note in notes:
        var tth = (float(note["time"]) + START_DELAY) - current_time
        if tth < -HIT_WINDOW or tth >= 3.5:
            continue
        hw_notes.append(note)
    hw_notes.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
    for note in hw_notes.slice(max(0, hw_notes.size()-20)):
        var si = int(note["string"])
        var fret = int(note.get("fret", 0))
        var tth = (float(note["time"]) + START_DELAY) - current_time
        print("  %s(str=%d) fret=%d at song_time=%.2fs tth=%.3fs" % [strings[si], si, fret, float(note["time"]), tth])
    
    quit(0)
