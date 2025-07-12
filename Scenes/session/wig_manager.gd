class_name WigManager extends Node

const wig_prefab = preload("res://Scenes/objects/wig/Wig.tscn")

@onready var wig_remote = $RemoteTransform3D

var wig_remotes : Array = []
var map_size := 50.0
var wigs : Array[Node] = []
var bearers : Array = []

signal spawned(Node3D)
signal destroying(Node3D)

@rpc("call_local", "reliable")
func rpc_spawn_new_wig():
		
		
	var new_wig = wig_prefab.instantiate()
	add_child(new_wig, true)
	var extents = map_size / 2.25
	var random_position = Vector3(randi_range(-extents, extents), extents, randi_range(-extents, extents))
	new_wig.global_position = random_position
	new_wig.toggle_strobing(true)
	new_wig.radius = 0.15
	wigs.append(new_wig)
	bearers.append(null)

	spawned.emit(new_wig)


@rpc("call_local", "reliable")
func rpc_destroy_wig(path_to_wig : NodePath):
	
	var wig = get_node(path_to_wig)
	
	if wig != null:
		wig.queue_free()


@rpc("call_local", "reliable")
func rpc_put_wig_on_head(path_to_wig, path_to_bearer):
	
	var wig = get_node(path_to_wig)
	
	if path_to_bearer == null:
		
		var bearer = wig_remote.get_parent()
		
		if bearer:
			bearer.remove_child(wig_remote)
			
		add_child(wig_remote)
		wig_remote.remote_path = ""
		wig.toggle_strobing(true)
		wig.Drop.play()
		wig.collider.disabled = false
		wig.freeze = false
		
	else:		
		var new_bearer = get_node(path_to_bearer)
		remove_child(wig_remote)
		new_bearer.find_child("*head").add_child(wig_remote)
		wig_remote.remote_path = path_to_wig
		wig_remote.position = Vector3(0, 0.2, -.025)		
		wig.toggle_strobing(false)
		wig.Dawn.play()
		wig.collider.disabled = true
		wig.freeze = true
		var wig_index = wigs.find(wig)
		bearers[wig_index] = new_bearer
		print(wigs, bearers)
	
	
@rpc("call_local", "reliable")
func rpc_fuse_wig_to_head(path_to_wig, path_to_bearer):
			
	if path_to_wig == null or path_to_bearer == null:
		return
	
	var wig = get_node(path_to_wig)
	var bearer = get_node(path_to_bearer)
	var wig_index = wigs.find(wig)
	bearers[wig_index] = bearer
	
	if wig == null or bearer == null:
		return
		
	wig_remote = RemoteTransform3D.new()
	add_child(wig_remote)
	
