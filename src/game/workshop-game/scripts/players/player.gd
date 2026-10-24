extends CharacterBody2D

@export var move_speed: float = 200.0
@export var is_local_player: bool = false
@export var offline_mode: bool = false # Toggle ON for quick offline tests in Godot editor

@onready var mesh: MeshInstance2D = $MeshInstance2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D

var player_id: String = ""
var score: int = 10

func _process(delta: float) -> void:
	if not is_local_player:
		return

	# If NOT in offline mode, ensure server connection exists before running net code
	if not offline_mode and not NetworkManager.is_server_connected:
		return

	var mouse_pos := get_global_mouse_position()
	
	# Offline mode OR Client-Authoritative mode runs movement locally
	if offline_mode or NetworkManager.admin_config.authority == "client":
		var dir := (mouse_pos - global_position)
		if dir.length() > 10.0:
			global_position += dir.normalized() * move_speed * delta
			
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
		NetworkManager.send_data({
			"type": "update",
			"target_x": mouse_pos.x,
			"target_y": mouse_pos.y
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
