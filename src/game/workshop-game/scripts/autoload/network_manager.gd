extends Node

var socket := WebSocketPeer.new()
var server_url := "ws://localhost:3000"
var is_server_connected := false

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
		if not is_connected:
			print("[Network] Connected to Node.js backend!")
			is_server_connected = true
			
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet()
			var message := packet.get_string_from_utf8()
			_parse_message(message)
			
	elif state == WebSocketPeer.STATE_CLOSED and is_connected:
		print("[Network] Disconnected from backend.")
		is_server_connected = false

func send_data(payload: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(payload))

func _parse_message(raw_json: String) -> void:
	var json := JSON.new()
	if json.parse(raw_json) == OK:
		var data = json.data
		if data.has("type") and data["type"] == "state":
			admin_config = data["config"]
			players_state = data["players"]
		elif data.has("type") and data["type"] == "alert":
			print("[SERVER ALERT] ", data["message"])
