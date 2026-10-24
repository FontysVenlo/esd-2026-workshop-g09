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
	# Expand internal packet buffer so high-frequency ticks don't drop data
	socket.inbound_buffer_size = 65536 * 4  # 256 KB buffer (default is 64 KB)
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
