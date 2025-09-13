extends Node

static var SERVER_PING = 0.0 :
	get:
		return SERVER_PING
	set(value):
		SERVER_PING = lerpf(SERVER_PING, value, 0.5)
		
static var CLIENT_PINGS = { 1 : 0}


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta) -> void:
		
	if is_multiplayer_authority():
		var local_server_time = Time.get_ticks_msec()
		ping.rpc(local_server_time)
				

	
@rpc("any_peer", "call_remote")
func ping(passthrough_time : float):  

	var sender_id = multiplayer.get_remote_sender_id()
	pong.rpc_id(sender_id, passthrough_time) #return fire to original pinger
	
	if not is_multiplayer_authority():
		var local_client_time = Time.get_ticks_msec()
		ping.rpc_id(get_multiplayer_authority(), local_client_time)
		
		
@rpc("any_peer", "call_remote")
func pong(ping_timestamp : float): #responding RPC call that passes back initial timestamp to original pinger
	
	var local_timestamp = Time.get_ticks_msec()
	var ping_ms = (local_timestamp - ping_timestamp) * 1000.0 / 2.0
	
	if is_multiplayer_authority():
		CLIENT_PINGS[multiplayer.get_remote_sender_id()] = ping_ms	
	else:
		SERVER_PING = ping_ms
