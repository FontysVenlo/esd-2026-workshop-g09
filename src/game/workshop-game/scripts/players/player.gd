extends CharacterBody2D

@export var move_speed: float = 200.0
@export var is_local_player: bool = false
@export var offline_mode: bool = false # Toggle ON for quick offline tests in Godot editor

@onready var mesh: MeshInstance2D = $MeshInstance2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var name_label: Label = $NameLabel

var player_id: String = ""
var score: int = 10

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

	var dir := get_local_mouse_position()

	# Offline mode OR Client-Authoritative mode runs movement locally
	if offline_mode or NetworkManager.admin_config.authority == "client":
		if dir.length() > 10.0:
			velocity = dir.normalized() * move_speed
		else:
			velocity = Vector2.ZERO

		# move_and_slide() handles wall collisions and velocity application automatically
		move_and_slide()

		# Only transmit packets if live server connection is active
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

	if data.has("score"):
		score = data.score
