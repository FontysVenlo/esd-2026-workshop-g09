extends Area2D

@export var score_value: int = 1
var orb_id: int = -1

func _ready() -> void:
	add_to_group("exp_orbs")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not visible:
		return

	# Check if the colliding node is the local player
	if body.has_method("add_score") and body.get("is_local_player"):
		body.add_score(score_value, orb_id)

		if not body.get("offline_mode") and NetworkManager.is_server_connected and orb_id >= 0:
			# Hide temporarily until server broadcasts the orb's new synced coordinates
			visible = false
			remove_from_group("exp_orbs")
			set_deferred("monitoring", false)
		else:
			# Offline editor fallback
			global_position = Vector2(randf_range(-2000.0, 2000.0), randf_range(-2000.0, 2000.0))
