extends AnimatableBody3D


@export var Size = Vector3(45, 0.5, 17.5)
var cached_Size = Vector3(45, 0.5, 17.5)


@export var humanoids_onboard = []
@onready var area = $Area3D


func _enter_tree():
	
	add_to_group("stages")


func _ready():
	
	area.body_entered.connect(add_humanoid_to_onboard)
	area.body_exited.connect(remove_humanoid_from_onboard)
	
	
func _process(_delta):
	
	if Size != cached_Size:
		process_size_change()
		cached_Size = Size


func process_size_change():
	
	for child in get_children():
		
		if child is CollisionShape3D:
			
			if child.name.contains("rail"):
				transform_rail(child)
				
			else:
				child.shape.size = Size
				
		elif child is MeshInstance3D:
			
			if child.name.contains("rail"):
				transform_rail(child)
				
			else:
				child.mesh.size = Size
				
		elif child is Area3D:
			child.get_child(0).shape.size = Vector3(Size.x, Size.y * 2, Size.z)
			child.position = Vector3.UP * Size.y * 3
		
			
func transform_rail(child):
	var signage = -1.0 if child.name.contains('2') else 1.0
	var thickness = Size.y*2
	var newSize = Size
	var newPosition
	var newRotation
	
	if child.name.ends_with('x'):
		newSize = Vector3(Size.z, thickness, thickness)
		newPosition = Vector3(signage*Size.x/2.0, 0, 0)
		newRotation = Vector3(PI/4, PI/2, 0)
		
	elif child.name.ends_with('z'):
		newSize = Vector3(Size.x, thickness, thickness)
		newPosition = Vector3(0, 0, signage*Size.z/2.0)
		newRotation = Vector3(PI/4, 0, 0)
		
	child.position = newPosition
	child.rotation = newRotation
	
	if child is MeshInstance3D:
		child.mesh.size = newSize
		
	elif child is CollisionShape3D:
		child.shape.size = newSize
		
		
func add_humanoid_to_onboard(object):
	
	if false if not multiplayer.has_multiplayer_peer() else is_multiplayer_authority(): return
	
	if object.is_in_group("humanoids"):
		humanoids_onboard.append(object)


func remove_humanoid_from_onboard(object):
	
	if false if not multiplayer.has_multiplayer_peer() else not is_multiplayer_authority(): return
	
	var index = humanoids_onboard.find(object)
	
	if object.is_in_group("humanoids") and index >= 0:
		humanoids_onboard.remove_at(index)
		
		
func set_color(color):
	var model = $floor
	var material = model.get_surface_override_material(0)
	material.albedo_color = color
	model.set_surface_override_material(0, material)
	

