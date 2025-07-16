class_name WigManager extends Node

const wig_prefab = preload("res://Scenes/objects/wig/Wig.tscn")
const wig_start_offset = Vector3(0, 0.2, -0.025)
const wig_end_offset = Vector3(0, 0.5, -0.075)
const wig_radii : Vector2 = Vector2(0.15, 0.45)

@onready var session = get_parent()

var map_size := 50.0
var wigs : Array[Node] = []
var wig_remotes : Array = []
var bearers : Array = []
var interactivity : Array[bool] = []

signal spawned(wig : RigidBody3D)
signal destroying(wig : RigidBody3D)
signal dawned(wig : RigidBody3D, humanoid : RigidBody3D)
signal dropped(wig : RigidBody3D, humanoid : RigidBody3D)
signal fused(wig : RigidBody3D, humanoid : RigidBody3D)


func _process(delta : float) -> void:
	
	for index in range(wigs.size()):
	
		var wig = wigs[index]
		
		if not wig:
			continue
			
		if bearers[index]:
			var ratio = (wigs[index].actual_radius - wig_radii.x) / (wig_radii.y - wig_radii.x)
			wig_remotes[index].position = lerp(wig_start_offset, wig_end_offset, ratio)
		
		if wig.actual_radius < 0.0:
			rpc_destroy_wig.rpc(wig.get_path())
	

func handle_player_leaving(client_id):
	
	pass
	
	#var humanoid = session.get_node_or_null(str(client_id))

	#if bearers.has(humanoid) and humanoid != null:
		#var bearer_index = bearers.find(humanoid)
		#var wig = wigs[bearer_index]
		#rpc_destroy_wig.rpc(wig.get_path())


@rpc("call_local", "reliable")
func rpc_clear_wigs():
		
	for index in range(wigs.size()):
		var wig = wigs[index]
		var remote = wig_remotes[index]
		var bearer = bearers[index]
		
		if wig != null:
			destroying.emit(wig)
			wig.queue_free()
			
		if remote != null:
			remote.queue_free()
					
		if not bearer:
			pass
		elif bearer.ragdolled.is_connected(drop_wig):
			bearer.ragdolled.disconnect(drop_wig)		

	wigs.clear()
	bearers.clear()
	wig_remotes.clear()


@rpc("call_local", "reliable")
func rpc_spawn_new_wig(start_radius : float, target_radius : float, spawn_position : Vector3 = Vector3.ZERO, starting_bearer : RigidBody3D = null):
				
	var new_wig = wig_prefab.instantiate()
	add_child(new_wig, true)
	new_wig.global_position = spawn_position
	new_wig.toggle_strobing(true)
	new_wig.radius = target_radius
	new_wig.mesh.mesh.radius = start_radius
	new_wig.mesh.mesh.height = start_radius * 2
	new_wig.collider.shape.radius = start_radius
	wigs.append(new_wig)
	bearers.append(null)
	var new_remote : RemoteTransform3D = RemoteTransform3D.new()
	add_child(new_remote)
	wig_remotes.append(new_remote)
	spawned.emit(new_wig)
	
	if starting_bearer == null:
		new_wig.interactable.gained_interaction.connect(dawn_wig)
	else:
		rpc_put_wig_on_head(new_wig.get_path(), starting_bearer.get_path())
	

@rpc("call_local", "reliable")
func rpc_destroy_wig(path_to_wig : NodePath):
	
	var wig = get_node(path_to_wig)
	
	if wig != null:
		var index = wigs.find(wig)
		var bearer : RigidBody3D = bearers[index]
		
		if not bearer:
			pass
		elif bearer.ragdolled.is_connected(drop_wig):
			bearer.ragdolled.disconnect(drop_wig)
			
		bearers[index] = null
		wig_remotes[index].queue_free()
		destroying.emit(wig)
		wig.queue_free()
		
		wigs.remove_at(index)
		bearers.remove_at(index)
		wig_remotes.remove_at(index)


@rpc("call_local", "reliable")
func rpc_put_wig_on_head(path_to_wig, path_to_bearer):
	
	var wig = get_node(path_to_wig)
	
	if wig == null:
		return
		
	var wig_index = wigs.find(wig)
	var wig_remote : RemoteTransform3D = wig_remotes[wig_index]	
	
	if path_to_bearer == null:	
		wig_remote.get_parent().remove_child(wig_remote)	
		add_child(wig_remote)
		wig_remote.remote_path = ""
		wig.toggle_strobing(true)
		wig.Drop.play()
		wig.collider.disabled = false
		wig.freeze = false

		return	
	
	var current_bearer = bearers[wig_index]
	var new_bearer = get_node(path_to_bearer)
	
	if current_bearer != new_bearer:		
		remove_child(wig_remote)
		new_bearer.find_child("*head").add_child(wig_remote)
		wig_remote.remote_path = path_to_wig
		wig_remote.position = Vector3(0, 0.2, -.025)		
		wig.toggle_strobing(false)
		wig.Dawn.play()
		wig.collider.disabled = true
		wig.freeze = true
		bearers[wig_index] = new_bearer
		return
	
	
#@rpc("call_local", "reliable")
#func rpc_fuse_wig_to_head(path_to_wig, path_to_bearer):
			#
	#if path_to_wig == null or path_to_bearer == null:
		#return
	#
	#var wig = get_node(path_to_wig)
	#var bearer = get_node(path_to_bearer)
#
	#if wig == null or bearer == null:
		#return
		#
	#var wig_index = wigs.find(wig)
	#bearers[wig_index] = bearer
	#
	#if bearer.ragdolled.is_connected(drop_wig):
		#bearer.ragdolled.disconnect(drop_wig)	
	
	
func dawn_wig(wig, humanoid):
	
	if not is_multiplayer_authority():
		return
		
	if not humanoid.is_in_group("humanoids"): #this node is not a humanoid
		pass
		
	elif humanoid.RAGDOLLED: #this humanoid is unable to dawn the wig
		pass
		
	elif bearers.has(humanoid): #this guy already has a wig
		pass
			
	else:
		#session.wig_manager.bearers[active_index] = humanoid
		wig.interactable.gained_interaction.disconnect(dawn_wig)
		humanoid.ragdolled.connect(drop_wig)
		rpc_put_wig_on_head.rpc(wig.get_path(), humanoid.get_path())
		dawned.emit(wig, humanoid)


func drop_wig(humanoid):
	
	if not is_multiplayer_authority():
		return
	elif humanoid == null:
		return
		
	if humanoid.ragdolled.is_connected(drop_wig):
		humanoid.ragdolled.disconnect(drop_wig)	
			
	var index = bearers.find(humanoid)
	var wig = wigs[index]
	bearers[index] = null
	var bearer_velocity = humanoid.linear_velocity * 1.5
	var offset_velocity = Vector3(randi_range(-1, 1), 3, randi_range(-1, 1))
	wig.linear_velocity = bearer_velocity + offset_velocity
		
	wig.interactable.gained_interaction.connect(dawn_wig)
	var wig_path = wig.get_path()
	rpc_put_wig_on_head.rpc(wig_path, null)
	dropped.emit(wig, humanoid)
	
	
func fuse_wig(humanoid):
	
	if not is_multiplayer_authority():
		return
	
	if humanoid.ragdolled.is_connected(drop_wig):
		humanoid.ragdolled.disconnect(drop_wig)	
		
		
func loosen_wig(humanoid):
	
	if not is_multiplayer_authority():
		return
	
	if not humanoid.ragdolled.is_connected(drop_wig):
		humanoid.ragdolled.connect(drop_wig)	


func clear_wigs():
	
	if not is_multiplayer_authority():
		return
	
	for wig in wigs:
		wig.radius = -1
	
	
func get_bearer(wig : RigidBody3D) -> RigidBody3D:
	
	if wig == null:
		return null
	else:
		var index = wigs.find(wig)
		return bearers[index]
		
		
func get_wig(bearer : RigidBody3D) -> RigidBody3D:
	
	if bearer == null:
		return null
	elif not bearers.has(bearer):
		return null
	else:
		var index = bearers.find(bearer)
		return wigs[index]
	
		
func give_wig(bearer : RigidBody3D):
	
	if not is_multiplayer_authority():
		return
	elif bearer == null:
		return
		
	rpc_spawn_new_wig.rpc(0.01, 0.15, Vector3.ZERO, bearer)
		
		
		
	
