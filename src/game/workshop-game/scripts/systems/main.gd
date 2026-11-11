# Main.gd
extends Node2D

@export var exp_orb_scene: PackedScene 
@export var max_exp_orbs: int = 50
@export var spawn_area_min: Vector2 = Vector2(-2000, -2000)
@export var spawn_area_max: Vector2 = Vector2(2000, 2000)

@onready var score_label: Label = %ScoreLabel
@onready var exp_container: Node2D = %ExpContainer # Node2D child under Main to keep hierarchy clean

func _ready() -> void:
	randomize()
	spawn_initial_exp()

func spawn_initial_exp() -> void:
	if not exp_orb_scene:
		print("[Main] Warning: Exp orb scene not assigned in Inspector!")
		return
		
	for i in range(max_exp_orbs):
		spawn_single_exp()

func spawn_single_exp() -> void:
	var exp_orb = exp_orb_scene.instantiate()
	
	# Pick random coordinates within world bounds
	var random_x = randf_range(spawn_area_min.x, spawn_area_max.x)
	var random_y = randf_range(spawn_area_min.y, spawn_area_max.y)
	
	exp_orb.global_position = Vector2(random_x, random_y)
	
	# Add to container or directly to Main
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
			# For desktop testing & editor previews: closes the app
			get_tree().quit()
