extends Node

static var SERVER_PING : float = 0.0 :
	get:
		return SERVER_PING
	set(value):
		SERVER_PING = lerpf(SERVER_PING, value, 0.5)
		
static var CLIENT_PINGS = { 1 : 0}
	
	
func _physics_process(delta) -> void:
		
	var local_server_time = Time.get_ticks_msec()
		
	if is_multiplayer_authority():
		send_timestamp.rpc(local_server_time)
	else:
		#print("sending ", local_server_time)
		send_timestamp.rpc_id(1, local_server_time)
				
	
@rpc("any_peer", "call_remote")
func send_timestamp(passthrough_time : float):  

	var sender_id = multiplayer.get_remote_sender_id()
	return_timestamp.rpc_id(sender_id, passthrough_time) #return fire to original send_timestamper
	
	if not is_multiplayer_authority():
		var local_client_time = Time.get_ticks_msec()
		send_timestamp.rpc_id(get_multiplayer_authority(), local_client_time)
		
		
@rpc("any_peer", "call_remote")
func return_timestamp(original_timestamp : float): #responding RPC call that passes back initial timestamp to original send_timestamper
	
	var local_timestamp = Time.get_ticks_msec()
	var RTT = (local_timestamp - original_timestamp) * 1000.0
	
	if is_multiplayer_authority():
		CLIENT_PINGS[multiplayer.get_remote_sender_id()] = RTT / 2.0	
	else:
		#print("receiving ", send_timestamp_timestamp)
		SERVER_PING = RTT / 2.0
