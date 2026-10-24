extends CharacterBody2D

@export var move_speed: float = 200.0
@export var is_local_player: bool = false
@export var offline_mode: bool = false # Toggle ON for quick offline tests in Godot editor

@onready var mesh: MeshInstance2D = $MeshInstance2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var player_id: String = ""
var score: int = 10

func _process(delta: float) -> void:
	if not is_local_player:
		return

	var dir := get_local_mouse_position()

	if offline_mode or NetworkManager.admin_config.authority == "client":
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
