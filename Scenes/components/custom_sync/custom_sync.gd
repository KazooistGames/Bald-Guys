extends Node

@onready var parent = get_parent()

var get_net_var_delegate : Callable

var logging = false

signal synced


func _ready():
	
	if parent == null:
		queue_free()
		
	if not is_multiplayer_authority():
		request_force_sync()
	
	
func force_sync():
	
	if is_multiplayer_authority():
		net_sync.rpc(get_net_vars())
		
func request_force_sync():
	
	if not is_multiplayer_authority():
		request_sync.rpc_id(get_multiplayer_authority())
	
	
@rpc("authority", "call_remote", "reliable")
func net_sync(variables : Dictionary):
	
	for key in variables.keys():
		parent.set(str(key), variables[key])
	
	synced.emit()
	
	
@rpc("any_peer", "call_remote", "reliable")
func request_sync():
	
	if is_multiplayer_authority():
		var calling_client = multiplayer.get_remote_sender_id()
		var variables = get_net_vars()
		net_sync.rpc_id(calling_client, variables)		
		
		if logging:
			print(calling_client, " requested sync of ", parent.name, " with vars: ", variables)


func get_net_vars():

	if get_net_var_delegate.is_null():
		return {}
	else:
		return get_net_var_delegate.call()

