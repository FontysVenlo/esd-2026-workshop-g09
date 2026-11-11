# CheatPanel.gd
extends PanelContainer

@export var access_to_cheat_menu: bool = false # Local override for testing in editor

@onready var esp_check: CheckButton = %ESPCheck
@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_value_label: Label = %SpeedValueLabel
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var zoom_value_label: Label = %ZoomValueLabel

var _tween: Tween

func _ready() -> void:
	pivot_offset = Vector2.ZERO
	visible = false
	scale = Vector2.ZERO
	modulate.a = 0.0

	zoom_slider.min_value = 0.2
	zoom_slider.max_value = 1.0
	zoom_slider.step = 0.05
	zoom_slider.value = CheatManager.custom_zoom_level

	esp_check.toggled.connect(_on_esp_toggled)
	speed_slider.value_changed.connect(_on_speed_changed)
	zoom_slider.value_changed.connect(_on_zoom_changed)

	# Listen for live permission updates from the web dashboard via NetworkManager
	if NetworkManager.has_signal("cheat_access_changed"):
		NetworkManager.cheat_access_changed.connect(_on_cheat_access_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F1 or event.keycode == KEY_QUOTELEFT:
			# Check export flag OR server-granted permission
			if access_to_cheat_menu or NetworkManager.has_cheat_access:
				toggle_menu()
			else:
				print("[CheatPanel] Access Denied: Admin has not unlocked client cheats.")

func _on_cheat_access_changed(has_access: bool) -> void:
	# Auto-close the menu if the admin disables cheat access while it's open
	if not has_access and not access_to_cheat_menu and visible:
		toggle_menu()

func toggle_menu() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween().set_parallel(true)

	if not visible:
		visible = true
		_tween.tween_property(self, "scale", Vector2.ONE, 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, 0.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(self, "scale", Vector2.ZERO, 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "modulate:a", 0.0, 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween.chain().tween_callback(func(): visible = false)

func _on_esp_toggled(button_pressed: bool) -> void:
	CheatManager.set_esp(button_pressed)

func _on_speed_changed(value: float) -> void:
	speed_value_label.text = str(snapped(value, 0.1)) + "x"
	CheatManager.set_speed_multiplier(value)

func _on_zoom_changed(value: float) -> void:
	var percentage := int(value * 100.0)
	zoom_value_label.text = str(percentage) + "%"
	CheatManager.set_camera_zoom(value)
