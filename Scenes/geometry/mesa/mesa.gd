extends Node3D


enum Preference{
	locked = -1,
	shallow = 0,
	deep = 1,
	none = 2,
}

@export var preference = Preference.deep
	
@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D
@onready var raycast = $RayCast3D

@export var top_height : float = 0.0		
@export var bottom_drop  : float = 0.0
@export var size  : float = 0.0

var raycast_target = Vector3.DOWN * 100

var bottom_position = Vector3.ZERO

signal altered

func _ready():
		
	rerender()
	
	$CustomSync.get_net_var_delegate = get_net_vars
	
	if not is_multiplayer_authority():
		$CustomSync.synced.connect(rerender)
		$CustomSync.request_network_sync.rpc_id(1)

	else:
		altered.connect($CustomSync.force_sync)
	
	

func _process(_delta):
	
	raycast.target_position = raycast_target
	
	if preference == Preference.locked:
		return
		
	elif not raycast.is_colliding():
		
		if bottom_position != raycast.target_position:	
			bottom_position = raycast.target_position
		else:
			return
		
	elif raycast.get_collision_point() != bottom_position:
		
		var new_point = raycast.get_collision_point()
		
		if just_deeper(new_point) and preference == Preference.shallow:
			return
		elif just_shallower(new_point) and preference == Preference.deep:
			return
		else:
			bottom_position = new_point - global_position
		
	rerender()


func get_top_position(bot_pos):
	
	return bot_pos.normalized() * top_height * -1.0


func get_mesh_position(bot_pos):
	
	var top_position = get_top_position(bot_pos)
	return bot_pos.lerp(top_position, 0.5)	
	
	
func get_mesh_height(bot_pos):
	
	var top_position = get_top_position(bot_pos)
	return top_position.distance_to(bot_pos) 
	
	
func rerender():
		
	bottom_position += bottom_position.normalized() * bottom_drop
	var mesh_position = get_mesh_position(bottom_position)
	var mesh_height = get_mesh_height(bottom_position)
		
	if size <= 0 or mesh_height <= 0:
		return	
		
	mesh.global_position = mesh_position + global_position
	mesh.mesh.size.x = size
	mesh.mesh.size.y = size
	mesh.mesh.size.z = mesh_height 
	
	collider.global_position = mesh_position + global_position
	collider.shape.size.y = mesh_height
	collider.shape.size.x = size
	collider.shape.size.z = size
	
		
		
func just_deeper(new_point):
	
	var new_trajectory = (new_point - global_position)
	
	if (bottom_position.normalized() - new_trajectory.normalized()).length() >= 0.25:
		return false
	elif new_trajectory.length() > bottom_position.length():
		return true
	else:
		return false
		

func just_shallower(new_point):
	
	var new_trajectory = (new_point - global_position)
	
	if bottom_position.normalized() != new_trajectory.normalized():
		return false
		
	elif new_trajectory.length() < bottom_position.length():
		return true
		
	else:
		return false
		
		
@rpc("authority", "call_remote")
func net_sync(variables : Dictionary):
	
	for key in variables.keys():
		set(str(key), variables[key])
		
	rerender()
	
	#
#@rpc("any_peer", "call_remote")
#func request_network_sync():
	#
	#if is_multiplayer_authority():
		#var calling_client = multiplayer.get_remote_sender_id()
#
		#print(calling_client, " requested sync of ", name)
		#net_sync.rpc_id(calling_client, get_net_vars())
#

func get_net_vars():
	var net_vars = {}
	net_vars["preference"] = preference
	net_vars["bottom_drop"] = bottom_drop
	net_vars["top_height"] = top_height
	net_vars["size"] = size
	net_vars["raycast_target"] = raycast_target
	return net_vars
	
	
	
	
	
	
	
	
