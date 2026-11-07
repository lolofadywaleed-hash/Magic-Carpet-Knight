class_name MagicCarpetGame
extends Node3D
## Magic Carpet Knight: stylized fantasy 3D endless runner.
## Gameplay remains owned by this node while imported free models provide the
## visible knight, flying monster, rocks, ruins, gate and sky landmarks.

enum GameState { TITLE, PLAYING, PAUSED, GAME_OVER }

const LANE_X := [-3.6, 0.0, 3.6]
const HEIGHT_Y := [1.35, 3.1, 4.85]
const TRACK_GAP := 14.0
const TRACK_COUNT := 15
const HAZARD_COUNT := 20
const GEM_COUNT := 30
const KNIGHT_FBX := "res://assets/models/quaternius/knight/KnightCharacter.fbx"
const KNIGHT_OBJ := "res://assets/models/quaternius/knight/KnightCharacter.obj"
const FLYING_DEMON_MODEL := "res://assets/models/quaternius/monsters/FlyingDemon.fbx"
const GATE_MODEL := "res://assets/models/catalog/gate/gate.glb"
const RUG_MODEL := "res://assets/models/catalog/rug/rug.obj"
const ISLAND_MODEL := "res://assets/models/catalog/island/fbx/island_small.fbx"
const ROCK_MODELS := [
	"res://assets/models/catalog/rocks/FBX__Rock_1.fbx",
	"res://assets/models/catalog/rocks/FBX__Rock_4.fbx",
	"res://assets/models/catalog/rocks/FBX__Rock_Moss_2.fbx",
]
const RUIN_MODELS := [
	"res://assets/models/quaternius/ruins/Arch_Gothic_RoundColumn.fbx",
	"res://assets/models/quaternius/ruins/Wall_ArchRound.fbx",
	"res://assets/models/quaternius/ruins/Flag_GothicArch.fbx",
]
const COLLECT_SOUND := "res://assets/audio/collect.wav"
const IMPACT_SOUND := "res://assets/audio/impact.wav"
var ui_font: Font
var ui_bold: Font

var state: GameState = GameState.TITLE
var world_root: Node3D
var player: CharacterBody3D
var player_model: Node3D
var carpet_model: Node3D
var camera: Camera3D
var track_segments: Array[Node3D] = []
var background_props: Array[Node3D] = []
var hazards: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

var lane_index := 1
var height_index := 1
var forward_distance := 0.0
var speed := 11.5
var score := 0
var best_score := 0
var elapsed := 0.0
var last_score_text := ""
var swipe_start := Vector2.ZERO
var pulse_time := 0.0
var collect_player: AudioStreamPlayer
var impact_player: AudioStreamPlayer

var title_layer: CanvasLayer
var hud_layer: CanvasLayer
var pause_layer: CanvasLayer
var result_layer: CanvasLayer
var title_card: PanelContainer
var title_status: Label
var score_label: Label
var speed_label: Label
var best_label: Label
var altitude_label: Label
var toast_label: Label
var pause_button: Button
var start_button: Button
var resume_button: Button
var retry_button: Button
var title_button: Button
var dimmer: ColorRect

func _ready() -> void:
	ui_font = load("res://assets/fonts/NotoSansArabic-wght.ttf") as Font
	if ui_font == null:
		ui_font = load("res://assets/template/fonts/ui_regular.tres") as Font
	ui_bold = ui_font
	rng.seed = 20261107
	best_score = _load_best_score()
	_build_audio()
	_build_world()
	_build_ui()
	_show_title()

func _process(delta: float) -> void:
	pulse_time += delta
	if state == GameState.PLAYING:
		_update_run(delta)
	_update_presentation(delta)

func _physics_process(_delta: float) -> void:
	if player != null:
		player.velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.physical_keycode)
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start = event.position
		elif state == GameState.PLAYING:
			_handle_swipe(event.position - swipe_start)

func _handle_key(code: int) -> void:
	if state == GameState.TITLE and code in [KEY_ENTER, KEY_SPACE]:
		start_run()
		return
	if state == GameState.GAME_OVER and code in [KEY_ENTER, KEY_SPACE]:
		start_run()
		return
	if code in [KEY_ESCAPE, KEY_P] and state in [GameState.PLAYING, GameState.PAUSED]:
		_toggle_pause()
		return
	if state != GameState.PLAYING:
		return
	match code:
		KEY_LEFT, KEY_A:
			_change_lane(-1)
		KEY_RIGHT, KEY_D:
			_change_lane(1)
		KEY_UP, KEY_W:
			_change_height(1)
		KEY_DOWN, KEY_S:
			_change_height(-1)

func _handle_swipe(delta: Vector2) -> void:
	if delta.length() < 28.0:
		return
	if absf(delta.x) > absf(delta.y):
		_change_lane(1 if delta.x > 0.0 else -1)
	else:
		_change_height(1 if delta.y < 0.0 else -1)

func _build_audio() -> void:
	collect_player = AudioStreamPlayer.new()
	collect_player.name = "CollectSound"
	collect_player.stream = load(COLLECT_SOUND)
	collect_player.volume_db = -5.0
	add_child(collect_player)
	impact_player = AudioStreamPlayer.new()
	impact_player.name = "ImpactSound"
	impact_player.stream = load(IMPACT_SOUND)
	impact_player.volume_db = -4.0
	add_child(impact_player)

func _build_world() -> void:
	world_root = Node3D.new()
	world_root.name = "FlightWorld"
	add_child(world_root)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07133b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8da8ff")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment_node.environment = environment
	world_root.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "MoonlitSun"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("d9e6ff")
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	world_root.add_child(sun)

	_create_track()
	_create_background()
	_create_player()
	_create_items()

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, 6.8, 11.5)
	camera.fov = 62.0
	world_root.add_child(camera)
	camera.look_at(Vector3(0.0, 2.45, -18.0), Vector3.UP)

func _create_track() -> void:
	var track_material := _material(Color("172d61"), 0.28, Color("0c173c"))
	var edge_material := _material(Color("35aeea"), 0.35, Color("0d75bc"), 1.7)
	for index in TRACK_COUNT:
		var segment := Node3D.new()
		segment.name = "TrackSegment_%02d" % index
		segment.position = Vector3(0.0, 0.0, -float(index) * TRACK_GAP)
		var platform_mesh := BoxMesh.new()
		platform_mesh.size = Vector3(15.5, 0.3, 13.2)
		_add_mesh(segment, platform_mesh, track_material, Vector3(0.0, -0.32, 0.0))
		for x in [-5.2, 5.2]:
			var rail := BoxMesh.new()
			rail.size = Vector3(0.12, 0.22, 12.5)
			_add_mesh(segment, rail, edge_material, Vector3(x, 0.08, 0.0))
		for x in [-1.8, 1.8]:
			var lane_line := BoxMesh.new()
			lane_line.size = Vector3(0.035, 0.012, 12.5)
			_add_mesh(segment, lane_line, edge_material, Vector3(x, -0.15, 0.0))
		world_root.add_child(segment)
		track_segments.append(segment)

func _create_background() -> void:
	var mountain_material := _material(Color("1a2c68"), 0.05, Color("0b123d"), 0.25)
	var cloud_material := _material(Color("b4d9ff"), 0.0, Color("6e9ce8"), 0.6)
	var specs := [
		[ISLAND_MODEL, Vector3(-12.0, -2.1, -58.0), Vector3(2.8, 2.8, 2.8), 0.18],
		[ISLAND_MODEL, Vector3(14.0, -1.8, -112.0), Vector3(3.4, 3.4, 3.4), -0.26],
		[RUIN_MODELS[0], Vector3(-12.5, 1.4, -92.0), Vector3(0.9, 0.9, 0.9), 0.4],
		[RUIN_MODELS[1], Vector3(13.5, 2.0, -154.0), Vector3(0.85, 0.85, 0.85), -0.3],
		[RUIN_MODELS[2], Vector3(-15.0, 2.4, -214.0), Vector3(1.2, 1.2, 1.2), 0.1],
	]
	for index in specs.size():
		var spec: Array = specs[index]
		var prop := Node3D.new()
		prop.name = "ImportedLandmark_%02d" % index
		if not _load_model(prop, String(spec[0]), Vector3(spec[2]), Vector3.ZERO, Vector3(0.0, float(spec[3]), 0.0)):
			prop.queue_free()
			continue
		prop.position = Vector3(spec[1])
		world_root.add_child(prop)
		background_props.append(prop)
	for index in 18:
		var prop := Node3D.new()
		prop.name = "SkyCloudOrMountain_%02d" % index
		if index % 3 == 0:
			var cloud := SphereMesh.new()
			cloud.radius = 1.5
			cloud.height = 2.5
			_add_mesh(prop, cloud, cloud_material, Vector3.ZERO, Vector3(2.7, 0.6, 1.1))
		else:
			var peak := CylinderMesh.new()
			peak.top_radius = 0.1
			peak.bottom_radius = 2.4
			peak.height = 4.8
			_add_mesh(prop, peak, mountain_material)
		prop.position = Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(5.0, 10.5), -20.0 - float(index) * 20.0)
		world_root.add_child(prop)
		background_props.append(prop)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.0, HEIGHT_Y[height_index], 0.0)
	world_root.add_child(player)
	player_model = Node3D.new()
	player_model.name = "ImportedKnightAndMagicCarpet"
	player.add_child(player_model)
	carpet_model = Node3D.new()
	carpet_model.name = "MagicCarpet"
	player_model.add_child(carpet_model)
	var carpet_material := _material(Color("b83f9f"), 0.35, Color("38104b"), 0.7)
	var carpet_trim := _material(Color("f5bd5c"), 0.75, Color("8a4b20"), 0.3)
	var rug_loaded := _load_model(carpet_model, RUG_MODEL, Vector3(2.65, 1.0, 1.0), Vector3(0.0, -0.82, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	if not rug_loaded:
		var carpet := PlaneMesh.new()
		carpet.size = Vector2(4.7, 1.7)
		_add_mesh(carpet_model, carpet, carpet_material, Vector3(0.0, -0.85, 0.0))
	var carpet_base := BoxMesh.new()
	carpet_base.size = Vector3(4.55, 0.1, 1.6)
	_add_mesh(carpet_model, carpet_base, carpet_trim, Vector3(0.0, -0.91, 0.0))
	for x in [-2.15, -1.45, 1.45, 2.15]:
		var tassel := CylinderMesh.new()
		tassel.top_radius = 0.045
		tassel.bottom_radius = 0.07
		tassel.height = 0.42
		_add_mesh(carpet_model, tassel, carpet_trim, Vector3(x, -0.98, 0.0), Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	var ornament := TorusMesh.new()
	ornament.inner_radius = 0.28
	ornament.outer_radius = 0.36
	ornament.rings = 16
	ornament.ring_segments = 8
	_add_mesh(carpet_model, ornament, carpet_trim, Vector3(0.0, -0.82, -0.3), Vector3(1.0, 0.35, 1.0), Vector3(PI * 0.5, 0.0, 0.0))
	if not _load_model(player_model, KNIGHT_FBX, Vector3(0.72, 0.72, 0.72), Vector3(0.0, -0.18, 0.0), Vector3.ZERO):
		_load_model(player_model, KNIGHT_OBJ, Vector3(0.72, 0.72, 0.72), Vector3(0.0, -0.18, 0.0), Vector3.ZERO)
	var light := OmniLight3D.new()
	light.name = "CarpetGlow"
	light.light_color = Color("ff71dc")
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = Vector3(0.0, -0.5, 0.0)
	player.add_child(light)

func _create_items() -> void:
	for index in HAZARD_COUNT:
		var kind := _hazard_kind(index)
		var item := _make_hazard(kind, index)
		var data := {"node": item, "kind": kind, "lane": 1, "height": 1, "serial": index}
		hazards.append(data)
		world_root.add_child(item)
	for index in GEM_COUNT:
		var item := _make_gem(index)
		var data := {"node": item, "lane": 1, "height": 1, "collected": false, "serial": index}
		gems.append(data)
		world_root.add_child(item)
	_reset_items()

func _hazard_kind(index: int) -> String:
	match index % 8:
		0, 4:
			return "rock"
		1, 6:
			return "gate"
		2, 7:
			return "flying"
		_:
			return "ruins"

func _make_hazard(kind: String, index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%02d" % [kind.capitalize(), index]
	var model_path := ""
	var model_scale := Vector3.ONE
	var model_position := Vector3.ZERO
	match kind:
		"rock":
			model_path = String(ROCK_MODELS[index % ROCK_MODELS.size()])
			model_scale = Vector3(2.25, 2.25, 2.25)
			model_position = Vector3(0.0, -0.25, 0.0)
		"gate":
			model_path = GATE_MODEL
			model_scale = Vector3(0.62, 0.62, 0.62)
			model_position = Vector3(0.0, -1.0, 0.0)
		"flying":
			model_path = FLYING_DEMON_MODEL
			model_scale = Vector3(0.72, 0.72, 0.72)
			model_position = Vector3(0.0, 0.65, 0.0)
		"ruins":
			model_path = String(RUIN_MODELS[index % RUIN_MODELS.size()])
			model_scale = Vector3(0.9, 0.9, 0.9)
			model_position = Vector3(0.0, -0.65, 0.0)
	if not _load_model(root, model_path, model_scale, model_position, Vector3.ZERO):
		push_warning("Imported hazard model unavailable: %s" % model_path)
	root.set_meta("spin_rate", 0.08 if kind == "flying" else 0.02)
	root.set_meta("collision_radius", 1.75 if kind in ["gate", "ruins"] else 1.5)
	return root

func _make_gem(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Crystal_%02d" % index
	var crystal_material := _material(Color("70f1ff"), 0.35, Color("1db8ff"), 4.2)
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.0
	crystal.bottom_radius = 0.36
	crystal.height = 0.95
	_add_mesh(root, crystal, crystal_material, Vector3.ZERO, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.0, 0.0))
	var halo := TorusMesh.new()
	halo.inner_radius = 0.46
	halo.outer_radius = 0.5
	halo.rings = 16
	halo.ring_segments = 8
	_add_mesh(root, halo, crystal_material, Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	var light := OmniLight3D.new()
	light.light_color = Color("54ddff")
	light.light_energy = 2.0
	light.omni_range = 3.2
	root.add_child(light)
	root.set_meta("spin_rate", 1.5 + float(index % 5) * 0.18)
	return root

func _reset_items() -> void:
	var z := -30.0
	var lane_pattern := [0, 2, 1, 1, 0, 2, 2, 0]
	var height_pattern := [0, 1, 2, 1, 2, 0, 1, 2]
	var previous_lane := -1
	for index in hazards.size():
		var data: Dictionary = hazards[index]
		var lane := int(lane_pattern[index % lane_pattern.size()])
		if lane == previous_lane:
			lane = (lane + 1) % 3
		var height := int(height_pattern[index % height_pattern.size()])
		data["lane"] = lane
		data["height"] = height
		data["serial"] = index
		var node := data["node"] as Node3D
		node.position = Vector3(LANE_X[lane], HEIGHT_Y[height], z)
		node.visible = true
		previous_lane = lane
		z -= rng.randf_range(13.5, 18.5)
	z = -36.0
	for index in gems.size():
		var data: Dictionary = gems[index]
		var lane := (index * 2 + 1) % 3
		var height := (index + int(index / 4)) % 3
		data["lane"] = lane
		data["height"] = height
		data["serial"] = index
		var node := data["node"] as Node3D
		node.position = Vector3(LANE_X[lane], HEIGHT_Y[height], z)
		node.visible = true
		data["collected"] = false
		z -= rng.randf_range(6.0, 10.0)

func start_run() -> void:
	state = GameState.PLAYING
	lane_index = 1
	height_index = 1
	forward_distance = 0.0
	speed = 15.5
	score = 0
	elapsed = 0.0
	player.position = Vector3(0.0, HEIGHT_Y[height_index], 0.0)
	_reset_items()
	_hide_all_overlays()
	hud_layer.visible = true
	_update_hud()
	_show_toast("انطلق! السرعة ترتفع تدريجيًا — اسحب للمناورة")

func _update_run(delta: float) -> void:
	elapsed += delta
	forward_distance += speed * delta
	speed = minf(34.0, 15.5 + elapsed * 0.72)
	score += int(speed * delta * 1.2)
	player.position.x = lerpf(player.position.x, float(LANE_X[lane_index]), minf(1.0, delta * 9.0))
	player.position.y = lerpf(player.position.y, float(HEIGHT_Y[height_index]), minf(1.0, delta * 7.0))
	var movement_factor := sin(pulse_time * 7.0) * 0.07
	player_model.position.y = movement_factor
	player_model.rotation.z = lerpf(player_model.rotation.z, float(lane_index - 1) * -0.1, delta * 5.0)
	carpet_model.rotation.x = sin(pulse_time * 3.4) * 0.045
	carpet_model.rotation.z = sin(pulse_time * 2.8) * 0.07
	for segment in track_segments:
		segment.position.z += speed * delta
		if segment.position.z > 16.0:
			segment.position.z = _furthest_track_z() - TRACK_GAP
	for prop in background_props:
		prop.position.z += speed * delta * 0.34
		prop.rotation.y += delta * 0.06
		if prop.position.z > 24.0:
			prop.position.z = -380.0 - rng.randf_range(0.0, 80.0)
	for data in hazards:
		_move_item(data, delta, true)
	for data in gems:
		_move_item(data, delta, false)
	camera.position.x = lerpf(camera.position.x, player.position.x * 0.24, delta * 2.5)
	camera.position.y = lerpf(camera.position.y, 6.8 + (player.position.y - 3.1) * 0.18, delta * 2.2)
	camera.look_at(Vector3(player.position.x * 0.22, 2.55 + (player.position.y - 3.1) * 0.12, -18.0), Vector3.UP)
	_update_hud()

func _move_item(data: Dictionary, delta: float, is_hazard: bool) -> void:
	var node := data["node"] as Node3D
	if node == null:
		return
	if node.visible:
		node.position.z += speed * delta
		node.rotation.y += delta * float(node.get_meta("spin_rate", 0.0))
		if not is_hazard and not bool(data["collected"]):
			if node.position.distance_to(player.position) < 1.55:
				_collect_gem(data)
		if is_hazard and absf(node.position.z) < 1.35:
			var radius := float(node.get_meta("collision_radius", 1.5))
			if absf(node.position.x - player.position.x) < radius and absf(node.position.y - player.position.y) < 1.4:
				_game_over()
	if node.position.z > 18.0:
		_recycle_item(data, is_hazard)

func _recycle_item(data: Dictionary, is_hazard: bool) -> void:
	var collection: Array[Dictionary] = hazards if is_hazard else gems
	var farthest := -30.0
	for other in collection:
		var other_node := other["node"] as Node3D
		farthest = minf(farthest, other_node.position.z)
	var serial := int(data.get("serial", 0)) + 1
	var lane := (serial * 2 + 1) % 3
	var height := (serial + (serial / 3 if is_hazard else serial / 4)) % 3
	var node := data["node"] as Node3D
	var gap := rng.randf_range(14.0, 19.0) if is_hazard else rng.randf_range(6.0, 10.0)
	node.position = Vector3(LANE_X[lane], HEIGHT_Y[height], farthest - gap)
	data["lane"] = lane
	data["height"] = height
	data["serial"] = serial
	data["collected"] = false
	node.visible = true

func _collect_gem(data: Dictionary) -> void:
	data["collected"] = true
	var node := data["node"] as Node3D
	_spawn_burst(node.global_position, Color("70f1ff"))
	node.visible = false
	score += 25
	if collect_player != null:
		collect_player.play()
	_show_toast("+25 جوهرة")

func _game_over() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.GAME_OVER
	best_score = maxi(best_score, score)
	_save_best_score(best_score)
	_spawn_burst(player.global_position, Color("ff557b"), true)
	if impact_player != null:
		impact_player.play()
	hud_layer.visible = false
	result_layer.visible = true
	var panel := result_layer.get_node("Center/Panel") as PanelContainer
	var score_result := panel.get_node("Content/Score") as Label
	var best_result := panel.get_node("Content/Best") as Label
	score_result.text = "النتيجة: %d" % score
	best_result.text = "أفضل نتيجة: %d" % best_score
	_show_toast("انتهت الرحلة")

func _spawn_burst(position: Vector3, color: Color, impact := false) -> void:
	if world_root == null:
		return
	var burst := GPUParticles3D.new()
	burst.name = "ImpactBurst" if impact else "GemBurst"
	burst.amount = 24 if impact else 16
	burst.lifetime = 0.75 if impact else 0.5
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.position = position
	var particle_material := ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0.0, 1.0, 0.0)
	particle_material.spread = 55.0 if impact else 35.0
	particle_material.initial_velocity_min = 3.0 if impact else 1.8
	particle_material.initial_velocity_max = 5.0 if impact else 3.2
	particle_material.gravity = Vector3(0.0, -5.0, 0.0)
	particle_material.scale_min = 0.08
	particle_material.scale_max = 0.18 if impact else 0.13
	particle_material.color = color
	burst.process_material = particle_material
	var shard := SphereMesh.new()
	shard.radius = 0.07
	shard.height = 0.14
	shard.material = _material(color, 0.15, color, 3.0)
	burst.draw_pass_1 = shard
	world_root.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)

func _change_lane(delta: int) -> void:
	if state != GameState.PLAYING:
		return
	lane_index = clampi(lane_index + delta, 0, 2)

func _change_height(delta: int) -> void:
	if state != GameState.PLAYING:
		return
	height_index = clampi(height_index + delta, 0, 2)

func _toggle_pause() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
		pause_layer.visible = true
		hud_layer.visible = false
	elif state == GameState.PAUSED:
		state = GameState.PLAYING
		pause_layer.visible = false
		hud_layer.visible = true

func _furthest_track_z() -> float:
	var result := 0.0
	for segment in track_segments:
		result = minf(result, segment.position.z)
	return result

func _update_presentation(delta: float) -> void:
	if toast_label == null:
		return
	if toast_label.modulate.a > 0.0 and state == GameState.PLAYING:
		toast_label.modulate.a = maxf(0.0, toast_label.modulate.a - delta * 0.65)

func _update_hud() -> void:
	if score_label == null:
		return
	var text := "النقاط  %06d" % score
	if text != last_score_text:
		score_label.text = text
		last_score_text = text
	speed_label.text = "السرعة  %02d" % int(speed)
	best_label.text = "الأفضل  %06d" % best_score
	altitude_label.text = "الارتفاع  %d / 3" % (height_index + 1)

func _build_ui() -> void:
	title_layer = CanvasLayer.new()
	title_layer.name = "TitleScreen"
	add_child(title_layer)
	title_card = _make_panel(Color("0a1740"), Color("5de0ff"))
	title_card.name = "TitleCard"
	title_card.set_anchors_preset(Control.PRESET_CENTER)
	title_card.position = Vector2(-290.0, -230.0)
	title_card.size = Vector2(580.0, 460.0)
	title_layer.add_child(title_card)
	var title_content := VBoxContainer.new()
	title_content.name = "Content"
	title_content.add_theme_constant_override("separation", 14)
	title_content.alignment = BoxContainer.ALIGNMENT_CENTER
	title_card.add_child(title_content)
	var eyebrow := _label("رحلة فوق السحاب", 18, Color("78e5ff"), ui_bold)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_content.add_child(eyebrow)
	var title := _label("فارس البساط السحري", 38, Color("fff0a8"), ui_bold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_content.add_child(title)
	var subtitle := _label("Magic Carpet Knight", 19, Color("d7e6ff"), ui_font)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_content.add_child(subtitle)
	var rule := ColorRect.new()
	rule.color = Color("ef63cb")
	rule.custom_minimum_size = Vector2(170.0, 3.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_content.add_child(rule)
	var hint := _label("بدّل المسار والارتفاع، تفادَ الصخور والبوابات، واجمع البلورات.", 18, Color("b9c9ef"), ui_font)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_content.add_child(hint)
	var controls := _label("لوحة المفاتيح: الأسهم أو WASD  •  الهاتف: اسحب", 15, Color("8aa6d6"), ui_font)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_content.add_child(controls)
	start_button = Button.new()
	start_button.text = "ابدأ الرحلة"
	start_button.custom_minimum_size = Vector2(250.0, 58.0)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.add_theme_font_override("font", ui_bold)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.add_theme_color_override("font_color", Color("06112f"))
	start_button.add_theme_stylebox_override("normal", _style(Color("ffd86a"), Color("fff3ae")))
	start_button.add_theme_stylebox_override("hover", _style(Color("ffe997"), Color.WHITE))
	start_button.add_theme_stylebox_override("pressed", _style(Color("e7aa45"), Color("fff3ae")))
	start_button.pressed.connect(start_run)
	title_content.add_child(start_button)
	title_status = _label("أفضل نتيجة: %d" % best_score, 16, Color("91a8d4"), ui_font)
	title_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_content.add_child(title_status)
	_build_hud()
	_build_pause_layer()
	_build_result_layer()

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.visible = false
	add_child(hud_layer)
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 22.0
	bar.offset_top = 18.0
	bar.offset_right = -22.0
	bar.offset_bottom = 96.0
	bar.add_theme_stylebox_override("panel", _style(Color(0.02, 0.06, 0.18, 0.86), Color(0.25, 0.72, 1.0, 0.48), 12))
	hud_layer.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar.add_child(row)
	score_label = _label("النقاط  000000", 23, Color("fff0a8"), ui_bold)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(score_label)
	speed_label = _label("السرعة  11", 18, Color("9feaff"), ui_font)
	row.add_child(speed_label)
	altitude_label = _label("الارتفاع  2 / 3", 18, Color("e8b6ff"), ui_font)
	row.add_child(altitude_label)
	best_label = _label("الأفضل  000000", 18, Color("c8d8ff"), ui_font)
	row.add_child(best_label)
	pause_button = Button.new()
	pause_button.text = "إيقاف مؤقت"
	pause_button.custom_minimum_size = Vector2(150.0, 45.0)
	pause_button.add_theme_font_override("font", ui_bold)
	pause_button.pressed.connect(_toggle_pause)
	row.add_child(pause_button)
	toast_label = _label("", 21, Color("fff0a8"), ui_bold)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-240.0, 112.0)
	toast_label.size = Vector2(480.0, 44.0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(toast_label)

func _build_pause_layer() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.name = "PauseScreen"
	pause_layer.visible = false
	add_child(pause_layer)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.08, 0.74)
	pause_layer.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)
	var panel := _make_panel(Color("0b1847"), Color("a887ff"))
	panel.custom_minimum_size = Vector2(420.0, 280.0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	var title := _label("الرحلة متوقفة", 30, Color("fff0a8"), ui_bold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var hint := _label("اضغط استئناف عندما تكون جاهزًا", 17, Color("cbd8ff"), ui_font)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)
	resume_button = _action_button("استئناف")
	resume_button.pressed.connect(_toggle_pause)
	content.add_child(resume_button)
	var quit := _action_button("العودة إلى العنوان")
	quit.pressed.connect(_show_title)
	content.add_child(quit)

func _build_result_layer() -> void:
	result_layer = CanvasLayer.new()
	result_layer.name = "ResultScreen"
	result_layer.visible = false
	add_child(result_layer)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.08, 0.8)
	result_layer.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(center)
	var panel := _make_panel(Color("140f42"), Color("ff8bcf"))
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(470.0, 330.0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 13)
	panel.add_child(content)
	var title := _label("انتهت الرحلة", 31, Color("ffb2da"), ui_bold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var score_result := _label("النتيجة: 0", 24, Color("fff0a8"), ui_bold)
	score_result.name = "Score"
	score_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(score_result)
	var best_result := _label("أفضل نتيجة: 0", 18, Color("cbd8ff"), ui_font)
	best_result.name = "Best"
	best_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(best_result)
	retry_button = _action_button("إعادة اللعب")
	retry_button.pressed.connect(start_run)
	content.add_child(retry_button)
	title_button = _action_button("العنوان الرئيسي")
	title_button.pressed.connect(_show_title)
	content.add_child(title_button)

func _show_title() -> void:
	state = GameState.TITLE
	_hide_all_overlays()
	title_layer.visible = true
	title_card.visible = true
	hud_layer.visible = false
	if title_status != null:
		title_status.text = "أفضل نتيجة: %d" % best_score

func _hide_all_overlays() -> void:
	if title_layer != null:
		title_layer.visible = false
	if pause_layer != null:
		pause_layer.visible = false
	if result_layer != null:
		result_layer.visible = false

func _show_toast(text: String) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.modulate.a = 1.0

func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(270.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", ui_bold)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("06112f"))
	button.add_theme_stylebox_override("normal", _style(Color("83e9ff"), Color("d4f8ff")))
	button.add_theme_stylebox_override("hover", _style(Color("b2f2ff"), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _style(Color("52bfd9"), Color("d4f8ff")))
	return button

func _make_panel(background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(background, 0.93), Color(border, 0.74), 18))
	return panel

func _style(background: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	style.shadow_color = Color(0.0, 0.0, 0.08, 0.45)
	style.shadow_size = 22
	return style

func _material(color: Color, metallic: float = 0.0, emission: Color = Color.TRANSPARENT, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.36
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material

func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, position := Vector3.ZERO, scale := Vector3.ONE, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.scale = scale
	instance.rotation = rotation
	parent.add_child(instance)
	return instance

func _load_model(parent: Node3D, path: String, scale: Vector3, position: Vector3, rotation: Vector3) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var resource := ResourceLoader.load(path)
	if resource == null:
		return false
	var instance: Node3D
	var packed := resource as PackedScene
	if packed != null:
		instance = packed.instantiate() as Node3D
	else:
		var mesh := resource as Mesh
		if mesh == null:
			return false
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		instance = mesh_instance
	if instance == null:
		return false
	instance.name = path.get_file().get_basename()
	instance.scale = scale
	instance.position = position
	instance.rotation = rotation
	parent.add_child(instance)
	return true

func _load_best_score() -> int:
	var config := ConfigFile.new()
	if config.load("user://magiccarpet.cfg") == OK:
		return int(config.get_value("scores", "best", 0))
	return 0

func _save_best_score(value: int) -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "best", value)
	config.save("user://magiccarpet.cfg")

func get_game_state() -> GameState:
	return state

func get_score() -> int:
	return score

func get_current_lane() -> int:
	return lane_index
