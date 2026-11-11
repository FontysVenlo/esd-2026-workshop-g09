extends CharacterBody2D

@export var move_speed: float = 200.0
@export var is_local_player: bool = false
@export var offline_mode: bool = false # Toggle ON for quick offline tests in Godot editor

@onready var mesh: MeshInstance2D = $MeshInstance2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var name_label: Label = $NameLabel

var player_id: String = ""
var score: int = 0

func _ready() -> void:
	if is_local_player:
		# 1. Listen for the signal if the server connection completes after spawning
		if not NetworkManager.player_initialized.is_connected(_on_player_initialized):
			NetworkManager.player_initialized.connect(_on_player_initialized)

		# 2. If NetworkManager ALREADY received the code before spawn, apply it immediately
		if not NetworkManager.my_code.is_empty():
			set_player_code(NetworkManager.my_code)
		elif offline_mode:
			set_player_code(generate_random_2char_code())
		else:
			set_player_code("..")
			
		# Connect to CheatManager signals
		CheatManager.camera_zoom_changed.connect(_on_cheat_zoom_changed)
			
		# Initialize the UI score display on frame 1
		set_score(score)
	else:
		# For remote dummy players spawned across the network
		if not player_id.is_empty():
			name_label.text = player_id
		else:
			name_label.text = ".."

func _on_player_initialized(_id: String, code: String) -> void:
	set_player_code(code)

func set_player_code(code_str: String) -> void:
	player_id = code_str
	if name_label:
		name_label.text = player_id

# --- SCORE MANAGEMENT LOGIC ---
func set_score(new_score: int) -> void:
	score = clamp(new_score, 0, 10000)
	
	# Update visual scale based on score
	_update_player_scale()
	
	if is_local_player:
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("update_score_hud"):
			main_node.update_score_hud(score)

func add_score(amount: int) -> void:
	set_score(score + amount)

func generate_random_2char_code() -> String:
	var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var numbers := "0123456789"
	var rand_letter := letters[randi() % letters.length()]
	var rand_number := numbers[randi() % numbers.length()]
	
	if randf() < 0.5:
		return rand_letter + rand_number
	else:
		return rand_number + rand_letter

func _physics_process(_delta: float) -> void:
	if not is_local_player:
		return

	# Quick hotkey test for score increase during development
	if Input.is_key_pressed(KEY_P):
		add_score(10)
	if Input.is_key_pressed(KEY_O):
		add_score(-10)

	var dir := get_local_mouse_position()

	# Calculate speed modified by CheatManager slider multiplier
	var effective_speed := move_speed * CheatManager.speed_multiplier

	# Offline mode OR Client-Authoritative mode runs movement locally
	if offline_mode or NetworkManager.admin_config.authority == "client":
		if dir.length() > 10.0:
			velocity = dir.normalized() * effective_speed
		else:
			velocity = Vector2.ZERO

		move_and_slide()

		# Transmit position AND current score payload to Node.js backend
		if not offline_mode and NetworkManager.is_server_connected:
			NetworkManager.send_data({
				"type": "update",
				"x": global_position.x,
				"y": global_position.y,
				"score": score
			})

	else:
		# --- BLOCK 1 (SECURED): Send target coordinates to Node.js backend ---
		var target_world_pos := global_position + dir
		NetworkManager.send_data({
			"type": "update",
			"target_x": target_world_pos.x,
			"target_y": target_world_pos.y
		})

func update_from_server(data: Dictionary) -> void:
	if offline_mode:
		return

	if NetworkManager.admin_config.authority == "server" or not is_local_player:
		var target_pos := Vector2(data.x, data.y)

		if NetworkManager.admin_config.interpolation:
			global_position = global_position.lerp(target_pos, 0.3)
		else:
			global_position = target_pos # Hard snap for testing rubberbanding

	# Update score and trigger UI refreshed text if server sends new score
	if data.has("score"):
		set_score(data.score)

func _update_player_scale() -> void:
	var growth_factor := 1.0 + sqrt(float(max(score, 0)) / 25.0)
	var target_player_scale := Vector2(growth_factor, growth_factor)
	
	var base_zoom := 1.0
	var zoom_factor := base_zoom / (1.0 + (growth_factor - 1.0) * 0.4)
	
	# If CheatManager camera zoom is modified (< 1.0), override default score zoom
	if CheatManager.custom_zoom_level < 1.0:
		zoom_factor = CheatManager.custom_zoom_level

	var target_camera_zoom := Vector2(zoom_factor, zoom_factor)
	
	var tween := create_tween().set_parallel(true)
	
	# Scales the CharacterBody2D -> automatically grows Mesh, CollisionShape2D, and NameLabel together!
	tween.tween_property(self, "scale", target_player_scale, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if has_node("Camera2D"):
		var camera := $Camera2D as Camera2D
		tween.tween_property(camera, "zoom", target_camera_zoom, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_cheat_zoom_changed(new_zoom: float) -> void:
	if has_node("Camera2D"):
		var camera := $Camera2D as Camera2D
		create_tween().tween_property(camera, "zoom", Vector2(new_zoom, new_zoom), 0.2).set_trans(Tween.TRANS_SINE)
