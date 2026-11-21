extends Node

signal player_initialized(player_id: String, code: String)
signal cheat_access_changed(has_access: bool)
signal bot_detector_changed(enabled: bool)
signal orbs_synced(orbs_list: Array)
signal orb_moved(orb_data: Dictionary)

var has_bot_detector: bool = false

var socket := WebSocketPeer.new()
var server_url := "ws://127.0.0.1:3000"
var is_server_connected := false

var reconnect_timer: float = 0.0

var my_player_id: String = ""
var my_code: String = ""

# Tracks whether the admin web dashboard has granted cheat menu permissions
var has_cheat_access: bool = false

var admin_config := {
	"authority": "client",
	"latency": 0,
	"packetLoss": 0,
	"prediction": true,
	"interpolation": true,
	"botDetector": false,
	"cheat_access": false
}

var players_state := {}
var initial_orbs: Array = []

func _ready() -> void:
	# Automatically match browser protocol (ws vs wss) and host on Web exports
	if OS.has_feature("web"):
		var protocol: String = str(JavaScriptBridge.eval("window.location.protocol === 'https:' ? 'wss://' : 'ws://'"))
		var host: String = str(JavaScriptBridge.eval("window.location.host"))
		if not host.is_empty():
			server_url = protocol + host

	socket.inbound_buffer_size = 65536 * 4
	socket.outbound_buffer_size = 65536 * 4
	socket.connect_to_url(server_url)

func _process(_delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_server_connected:
			print("[Network] Connected to Node.js backend!")
			is_server_connected = true

		# Drain packet queue completely to prevent overflow
		var count := socket.get_available_packet_count()
		while count > 0:
			var packet := socket.get_packet()
			if socket.get_packet_error() == OK:
				var message := packet.get_string_from_utf8()
				_parse_message(message)
			count -= 1

	elif state == WebSocketPeer.STATE_CLOSED:
		if is_server_connected:
			print("[Network] Disconnected from backend. Reconnecting...")
			is_server_connected = false

		reconnect_timer += _delta
		if reconnect_timer >= 2.0:
			reconnect_timer = 0.0
			socket.connect_to_url(server_url)

func send_data(payload: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(payload))

func _parse_message(raw_json: String) -> void:
	var json := JSON.new()
	if json.parse(raw_json) == OK:
		var data = json.data
		if not data is Dictionary or not data.has("type"):
			return

		match data["type"]:
			"init":
				# Store server-assigned identifiers
				my_player_id = data["playerId"]
				my_code = data["code"]
				print("[Network] Initialized as Player ID: ", my_player_id, " | Code: ", my_code)
				
				# Emit signal so Main.gd or Player.gd can set the local player code label
				player_initialized.emit(my_player_id, my_code)

				if data.has("orbs"):
					initial_orbs = data["orbs"]
					orbs_synced.emit(initial_orbs)

			"state":
				if data.has("config"):
					admin_config = data["config"]
					
					# Update cheat access state and notify listeners if flag changes
					var new_cheat_access: bool = admin_config.get("cheat_access", false)
					if new_cheat_access != has_cheat_access:
						has_cheat_access = new_cheat_access
						cheat_access_changed.emit(has_cheat_access)
						
						# Reset active cheats if admin revokes permission mid-game
						if not has_cheat_access:
							CheatManager.set_esp(false)
							CheatManager.set_speed_multiplier(1.0)
							CheatManager.set_camera_zoom(1.0)
							CheatManager.set_auto_collect(false)

					# Block 4: Update Bot Detector state and toggle Auto Collector visibility
					var new_bot_detector: bool = admin_config.get("botDetector", false)
					if new_bot_detector != has_bot_detector:
						has_bot_detector = new_bot_detector
						bot_detector_changed.emit(has_bot_detector)
						if not has_bot_detector:
							CheatManager.set_auto_collect(false)

				if data.has("players"):
					players_state = data["players"]

			"orb_moved":
				if data.has("orb"):
					orb_moved.emit(data["orb"])

			"eaten":
				print("[Network] You were eaten! Respawning...")
				var local_p := get_tree().root.get_node_or_null("Main/Player")
				if local_p and local_p.has_method("respawn"):
					local_p.call("respawn")

			"ate_player":
				var local_p := get_tree().root.get_node_or_null("Main/Player")
				if local_p and local_p.has_method("set_score"):
					local_p.set_score(local_p.score + int(data.get("gained", 1)))

			"alert":
				print("[SERVER ALERT] ", data["message"])
