extends Node3D

const wig_prefab = preload("res://Scenes/objects/wig/Wig.tscn")

var Wig : Node3D

var Wig_Bearer : Node3D

@onready var wig_remote = $RemoteTransform3D


func _ready():
	
	if is_multiplayer_authority():
		Wig = wig_prefab.instantiate()
		add_child(Wig)
		Wig.global_position = Vector3(0, 10, 0)
		Wig.interactable.gained_interaction.connect(dawn_wig)
		
		
func _process(delta):
	
	if not Wig:
		Wig = $Wig
		
	elif not Wig_Bearer:
		pass
		
	print(Wig, Wig_Bearer)
		
		
func dawn_wig(node):
	
	if not Wig:
		pass
		
	elif not node.is_in_group("humanoids"):
		pass
		
	elif not Wig_Bearer:
		Wig.interactable.gained_interaction.disconnect(dawn_wig)
		node.ragdolled.connect(drop_wig)
		
		move_wig_remote_controller.rpc(node.find_child("*head").get_path())
		toggle_wig_mount.rpc(true)
		
		set_wig_bearer.rpc(node.get_path())
		print("dawned ", node)
		
		
func drop_wig():
	Wig.interactable.gained_interaction.connect(dawn_wig)
	Wig_Bearer.ragdolled.disconnect(drop_wig)
	
	var current_position = Wig.global_position
	
	move_wig_remote_controller.rpc(Wig_Bearer.get_parent().get_path())
	toggle_wig_mount.rpc(false)
	
	Wig.global_position = current_position
	Wig.linear_velocity = Wig_Bearer.velocity * 1.5 + Vector3(0, 3, 0)

	set_wig_bearer.rpc(null)
	print("Dropped")
	
	
@rpc("call_local")
func toggle_wig_mount(value):
	
	Wig.collider.disabled = value
	Wig.freeze = value
	
	
@rpc("call_local")
func move_wig_remote_controller(path_to_new_parent):
	
	wig_remote.get_parent().remove_child(wig_remote)
	get_node(path_to_new_parent).add_child(wig_remote)
	
	
@rpc("call_local")
func set_wig_bearer(path_to_new_bearer):
	
	if path_to_new_bearer == null:
		Wig_Bearer = null
		wig_remote.remote_path = ""
		
	else:	
		Wig_Bearer = get_node(path_to_new_bearer)
		wig_remote.remote_path = Wig.get_path()
		wig_remote.position = Vector3(0, 0.275, -.075)
	
	
	

