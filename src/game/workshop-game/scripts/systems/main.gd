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
var synced_orbs: Dictionary = {}

func _ready() -> void:
	randomize()
	NetworkManager.orbs_synced.connect(_on_orbs_synced)
	NetworkManager.orb_moved.connect(_on_orb_moved)

	var local_player := get_node_or_null("Player")
	if local_player and local_player.get("offline_mode"):
		spawn_initial_exp()
	elif not NetworkManager.initial_orbs.is_empty():
		_on_orbs_synced(NetworkManager.initial_orbs)

func _on_orbs_synced(orbs_list: Array) -> void:
	print("[Main] _on_orbs_synced called with ", orbs_list.size(), " orbs | scene=", exp_orb_scene)
	if not exp_orb_scene:
		print("[Main] Warning: Exp orb scene not assigned in Inspector!")
		return

	# Clear any existing orbs (prevents duplicates on reconnect)
	for child in exp_container.get_children():
		child.queue_free()
	synced_orbs.clear()

	for o in orbs_list:
		var orb := exp_orb_scene.instantiate()
		var id := int(o.get("id", -1))
		orb.set("orb_id", id)
		orb.set("score_value", int(o.get("val", 1)))
		orb.global_position = Vector2(float(o.get("x", 0)), float(o.get("y", 0)))
		exp_container.add_child(orb)
		synced_orbs[id] = orb

func _on_orb_moved(orb_data: Dictionary) -> void:
	var id := int(orb_data.get("id", -1))
	if synced_orbs.has(id) and is_instance_valid(synced_orbs[id]):
		var orb: Area2D = synced_orbs[id]
		orb.global_position = Vector2(float(orb_data.get("x", 0)), float(orb_data.get("y", 0)))
		orb.visible = true
		orb.add_to_group("exp_orbs")
		orb.set_deferred("monitoring", true)

func _process(_delta: float) -> void:
	if not NetworkManager.is_server_connected:
		return
	if synced_orbs.is_empty() and not NetworkManager.initial_orbs.is_empty():
		_on_orbs_synced(NetworkManager.initial_orbs)
		
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
			new_p.add_to_group("players")
			new_p.global_position = Vector2(float(p_data.get("x", 100)), float(p_data.get("y", 100)))
			add_child(new_p)

			if new_p.has_node("Camera2D"):
				new_p.get_node("Camera2D").enabled = false
			if new_p.has_method("set_player_code"):
				new_p.call("set_player_code", str(p_data.get("code", "??")))

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
