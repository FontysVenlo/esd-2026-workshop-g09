# Main.gd
extends Node2D

@export var exp_orb_scene: PackedScene 
@export var player_scene: PackedScene
@export var max_exp_orbs: int = 50
@export var spawn_area_min: Vector2 = Vector2(-2000, -2000)
@export var spawn_area_max: Vector2 = Vector2(2000, 2000)

@onready var score_label: Label = %ScoreLabel
@onready var exp_container: Node2D = %ExpContainer

var remote_players: Dictionary = {}

func _ready() -> void:
	randomize()
	spawn_initial_exp()

func _process(_delta: float) -> void:
	if not NetworkManager.is_server_connected:
		return

	var server_players: Dictionary = NetworkManager.players_state

	# 1. Sync local player from server (handles Prediction OFF & Server Authority / Eaten resets)
	if server_players.has(NetworkManager.my_player_id):
		var local_player: Node = get_node_or_null("Player")
		if local_player and local_player.has_method("update_from_server"):
			local_player.update_from_server(server_players[NetworkManager.my_player_id])

	# 2. Spawn and update remote players
	if not player_scene:
		return

	for id: String in server_players.keys():
		if id == NetworkManager.my_player_id:
			continue

		var p_data: Dictionary = server_players[id]
		if not remote_players.has(id):
			var new_p: Node2D = player_scene.instantiate()
			new_p.set("is_local_player", false)
			new_p.set("offline_mode", false)
			if new_p.has_method("set_player_code"):
				new_p.call("set_player_code", str(p_data.get("code", "??")))
			new_p.global_position = Vector2(float(p_data.get("x", 100)), float(p_data.get("y", 100)))
			add_child(new_p)
			remote_players[id] = new_p
		else:
			var existing_p: Node = remote_players[id]
			if existing_p.has_method("update_from_server"):
				existing_p.call("update_from_server", p_data)

	# 3. Clean up disconnected players
	for id: String in remote_players.keys():
		if not server_players.has(id):
			remote_players[id].queue_free()
			remote_players.erase(id)

func spawn_initial_exp() -> void:
	if not exp_orb_scene:
		print("[Main] Warning: Exp orb scene not assigned in Inspector!")
		return
		
	for i in range(max_exp_orbs):
		spawn_single_exp()

func spawn_single_exp() -> void:
	var exp_orb = exp_orb_scene.instantiate()
	
	var random_x = randf_range(spawn_area_min.x, spawn_area_max.x)
	var random_y = randf_range(spawn_area_min.y, spawn_area_max.y)
	
	exp_orb.global_position = Vector2(random_x, random_y)
	
	if exp_container:
		exp_container.add_child(exp_orb)
	else:
		add_child(exp_orb)

func update_score_hud(new_score: int) -> void:
	if score_label:
		score_label.text = "Score: " + str(new_score)

# TODO REMOVE THIS LATER ON!
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
