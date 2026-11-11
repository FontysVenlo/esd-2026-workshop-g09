extends Area2D

@export var score_value: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Check if the colliding node is a player
	if body.has_method("add_score"):
		# Only the local player handles pickup logic in Client-Authoritative mode
		if body.is_local_player:
			body.add_score(score_value)
			
			# 1. Ask Main.gd to spawn 1 replacement orb somewhere else on the map
			var main_node = get_tree().root.get_node_or_null("Main")
			if main_node and main_node.has_method("spawn_single_exp"):
				main_node.call_deferred("spawn_single_exp")
				
			# 2. Delete this eaten orb instance from the tree
			queue_free()
