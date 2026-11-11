extends CharacterBody2D

@export var move_speed: float = 200.0
@export var is_local_player: bool = false
@export var offline_mode: bool = false # Toggle ON for quick offline tests in Godot editor
@export var dev_mode: bool = false     # Toggle ON to enable O/P hotkeys for testing score

@onready var mesh: MeshInstance2D = $MeshInstance2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var name_label: Label = $NameLabel

var last_js_score: int = 0

var player_id: String = ""
var score: int = 0

func _ready() -> void:
	if is_local_player:
		# Expose window.player to JS runtime automatically (Re-export proof!)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("""
				if (!window.player) {
					window.player = { score: 0, x: 0, y: 0 };
				}
			""")

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
		CheatManager.esp_toggled.connect(_on_esp_toggled)
			
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
	last_js_score = score  # Keep track so normal gains aren't overridden
	_update_player_scale()
	
	if is_local_player:
		if OS.has_feature("web"):
			JavaScriptBridge.eval("if (window.player) window.player.score = %d;" % score)
			
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

	# Redraw ESP canvas lines while active
	if CheatManager.esp_enabled:
		queue_redraw()

	# --- DEVTOOLS CONSOLE EXPLOIT BRIDGE ---
	if OS.has_feature("web"):
		var js_score: int = int(JavaScriptBridge.eval("window.player ? window.player.score : -1"))
		
		if NetworkManager.admin_config.authority == "client":
			# EXPLOIT MODE: Accept student console edits directly
			if js_score >= 0 and js_score != last_js_score:
				print("[DevTools Exploit] Score spoof accepted: ", js_score)
				last_js_score = js_score
				set_score(js_score)
		else:
			# SECURED MODE: Override any local console tampering back to true score
			if js_score != score:
				JavaScriptBridge.eval("if (window.player) window.player.score = %d;" % score)

		# Push live coordinates back to window.player for console inspect
		JavaScriptBridge.eval("if (window.player) { window.player.x = %f; window.player.y = %f; }" % [global_position.x, global_position.y])

	if dev_mode:
		if Input.is_key_pressed(KEY_P):
			add_score(10)
		if Input.is_key_pressed(KEY_O):
			add_score(-10)

	# --- LOCAL MOVEMENT (Runs unconditionally for responsive controls) ---
	var dir := get_local_mouse_position()
	var effective_speed := move_speed * CheatManager.speed_multiplier

	if dir.length() > 10.0:
		velocity = dir.normalized() * effective_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Transmit current position to backend so other players can see movement
	if not offline_mode and NetworkManager.is_server_connected:
		NetworkManager.send_data({
			"type": "update",
			"x": global_position.x,
			"y": global_position.y,
			"score": score
		})

func update_from_server(data: Dictionary) -> void:
	if offline_mode:
		return

	# Only update position from server packets if this is a REMOTE player
	if not is_local_player:
		var target_pos := Vector2(data.x, data.y)

		if NetworkManager.admin_config.interpolation:
			global_position = global_position.lerp(target_pos, 0.3)
		else:
			global_position = target_pos
		return

	# --- LOCAL PLAYER SCORE HANDLING ---
	# In Secured Mode, the server dictates the real score
	if NetworkManager.admin_config.authority == "server" and data.has("score"):
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

# --- ESP DRAWING & SIGNAL HANDLERS ---
func _on_esp_toggled(_enabled: bool) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_local_player or not CheatManager.esp_enabled:
		return

	var main_node = get_tree().root.get_node_or_null("Main")
	if not main_node:
		return

	# Calculate RGB rainbow cycle based on elapsed milliseconds
	var time_offset := Time.get_ticks_msec() * 0.0005
	var hue := fmod(time_offset, 1.0)
	
	# Create glowing RGB line color (Hue, Saturation 1.0, Value 1.0)
	var line_color := Color.from_hsv(hue, 1.0, 1.0, 0.85)

	for child in main_node.get_children():
		# Detect any other player node (e.g. Player2, dummy nodes, or network clients)
		if (child.is_in_group("players") or child.name.begins_with("Player")) and child != self:
			if child is Node2D:
				var local_target_pos := to_local(child.global_position)
				
				# Animated RGB tracer line from local player center to target
				draw_line(Vector2.ZERO, local_target_pos, line_color, 2.5)
