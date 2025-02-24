extends MultiplayerSynchronizer

@export var AUTHORITY_ORIGIN = Vector3.ZERO
@export var AUTHORITY_BASIS = Basis.IDENTITY

var lerp_val = 0.5
var deadbanded = false
var origin_deadband = 0.2

var parent

var logging = false


func _ready():
	
	parent = get_parent()
	
	if not parent_is_valid():
		queue_free()
		
	elif not is_multiplayer_authority():
		delta_synchronized.connect(reset_deadband)	
		request_sync.rpc_id(get_multiplayer_authority())
		

func _physics_process(_delta):
	
	if not parent_is_valid():
		queue_free()
		
	elif not multiplayer.has_multiplayer_peer():
		pass
		
	elif is_multiplayer_authority():
		AUTHORITY_ORIGIN = parent.transform.origin
		AUTHORITY_BASIS = parent.transform.basis
		
	else:
		parent.transform.basis = AUTHORITY_BASIS
		
		if deadbanded:
			pass
			
		elif parent.position.distance_to(AUTHORITY_ORIGIN) > 1.0:
			parent.transform.origin = AUTHORITY_ORIGIN	
			
		elif parent.position.distance_to(AUTHORITY_ORIGIN) <= origin_deadband:
			parent.transform.origin = AUTHORITY_ORIGIN	
			deadbanded = true
			
		elif not deadbanded:
			parent.transform.origin = parent.transform.origin.lerp(AUTHORITY_ORIGIN, lerp_val)


@rpc("authority", "call_remote")
func force_sync(variables : Dictionary):
	
	for key in variables.keys():
		set(str(key), variables[key])
	
	
@rpc("any_peer", "call_remote")
func request_sync():
	
	if is_multiplayer_authority():
		var calling_client = multiplayer.get_remote_sender_id()
		var variables = get_net_vars()
		force_sync.rpc_id(calling_client, variables)
		
		if logging:
			print(calling_client, " requested sync of ", parent.name, " with vars: ", variables)
			

func get_net_vars():
	
	var net_vars = {}
	net_vars["AUTHORITY_ORIGIN"] = AUTHORITY_ORIGIN
	net_vars["AUTHORITY_BASIS"] = AUTHORITY_BASIS
	parent.transform.origin = AUTHORITY_ORIGIN	
	parent.transform.basis = AUTHORITY_BASIS
	return net_vars


func reset_deadband():
	
	deadbanded = false


func parent_is_valid():
	
	if parent != null:
		return true
	elif parent is Node3D:
		return true
	else:
		return false

	
