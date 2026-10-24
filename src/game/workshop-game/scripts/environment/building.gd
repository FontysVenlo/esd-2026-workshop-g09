extends Area2D

func _ready() -> void:
	# Connect mouse signals for hover highlights
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func _on_mouse_entered() -> void:
	modulate = Color(1.3, 1.3, 1.3) # Lights up on hover
	print("Mouse hovered building!")

func _on_mouse_exited() -> void:
	modulate = Color(1.0, 1.0, 1.0) # Resets

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Building clicked!")
