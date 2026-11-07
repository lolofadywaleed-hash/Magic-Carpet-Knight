extends SceneTree
## Bounded native check for the requested endless-runner outcomes.
const GAME_SCRIPT = preload("res://scripts/magic_carpet_game.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene must load")
	if packed == null:
		_finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	_check(game.get_script() == GAME_SCRIPT, "main scene must use the MagicCarpetGame script")
	_check(game.get_node_or_null("FlightWorld/Camera") is Camera3D, "camera must be present")
	_check(game.get_node_or_null("FlightWorld/Player") is CharacterBody3D, "player controller must be present")
	game.start_run()
	await process_frame
	_check(game.get_game_state() == 1, "start must enter PLAYING")
	var before: int = game.get_current_lane()
	game._change_lane(1)
	_check(game.get_current_lane() == mini(before + 1, 2), "lane input must change the lane")
	var initial_score: int = game.get_score()
	for frame in 12:
		await physics_frame
	_check(game.get_score() >= initial_score, "score must be monotonic during a run")
	game._toggle_pause()
	_check(game.get_game_state() == 2, "pause must enter PAUSED")
	game._toggle_pause()
	_check(game.get_game_state() == 1, "resume must return to PLAYING")
	game.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("[magic-carpet] PASS: scene, controller, start, movement, score and pause")
		quit(0)
		return
	for failure in failures:
		push_error("[magic-carpet] " + failure)
	quit(1)
