# CheatManager.gd
extends Node

# Active Cheat State Variables
var esp_enabled: bool = false
var speed_multiplier: float = 1.0
var custom_zoom_level: float = 1.0  # 1.0 = 100% (Normal), lower values (e.g. 0.3) zoom out to see more map

# Signals to notify other nodes (Player, Main, UI) when settings change
signal esp_toggled(enabled: bool)
signal speed_multiplier_changed(new_speed: float)
signal camera_zoom_changed(new_zoom: float)

func set_esp(enabled: bool) -> void:
	esp_enabled = enabled
	esp_toggled.emit(esp_enabled)

func set_speed_multiplier(multiplier: float) -> void:
	speed_multiplier = multiplier
	speed_multiplier_changed.emit(speed_multiplier)

func set_camera_zoom(zoom_level: float) -> void:
	custom_zoom_level = zoom_level
	camera_zoom_changed.emit(custom_zoom_level)
