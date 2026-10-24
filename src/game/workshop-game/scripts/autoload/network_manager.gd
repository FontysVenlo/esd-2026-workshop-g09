extends Node

signal player_initialized(player_id: String, code: String)

var socket := WebSocketPeer.new()
var server_url := "ws://127.0.0.1:3000"
var is_server_connected := false

var my_player_id: String = ""
var my_code: String = ""

var admin_config := {
	"authority": "client",
	"latency": 0,
	"packetLoss": 0,
	"prediction": true,
	"interpolation": true,
	"botDetector": false
}

var players_state := {}

func _ready() -> void:
	socket.connect_to_url(server_url)

func _process(_delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		# FIXED: Changed is_connected to is_server_connected to avoid naming collision with Object.is_connected()
		if not is_server_connected:
			print("[Network] Connected to Node.js backend!")
			is_server_connected = true
			
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet()
			var message := packet.get_string_from_utf8()
			_parse_message(message)
			
	elif state == WebSocketPeer.STATE_CLOSED and is_server_connected:
		print("[Network] Disconnected from backend.")
		is_server_connected = false

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

			"state":
				if data.has("config"):
					admin_config = data["config"]
				if data.has("players"):
					players_state = data["players"]

			"alert":
				print("[SERVER ALERT] ", data["message"])
