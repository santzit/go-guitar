extends Node

## Global game state autoload singleton.
## Persists data between scene transitions.

var current_song: String = ""
var score: int = 0
var combo: int = 0
var high_scores: Dictionary = {}

func reset_session() -> void:
	score = 0
	combo = 0

func update_high_score(song_path: String, new_score: int) -> void:
	var existing: int = high_scores.get(song_path, 0)
	if new_score > existing:
		high_scores[song_path] = new_score
