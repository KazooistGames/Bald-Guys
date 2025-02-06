extends StaticBody3D

@export var height = 0.0
@export var length = 0.0
@export var thickness = 0.0

@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D

var cached_height = 0.0
var cached_length = 0.0
var cached_thickness = 0.0

const debounce_period = 0.2 #limit rate that we re-generate a convex mesh
var debounce_timer = 0.0

var need_new_collider = false


func _process(delta):
	
	debounce_timer += delta
			
	if mesh_has_changed():
		need_new_collider = true
		mesh.mesh.size.x = length
		mesh.mesh.size.y = height
		mesh.mesh.size.z = thickness
		mesh.position = Vector3.UP * height / 2.0
		cache_mesh_size()

	elif not need_new_collider:
		pass
		
	elif debounce_timer >= debounce_period:
		debounce_timer = 0.0
		collider.make_convex_from_siblings()
		need_new_collider = false


func mesh_has_changed():
	return height != cached_height or length != cached_length or thickness != cached_thickness


func cache_mesh_size():
	cached_length = length
	cached_height = height
	cached_thickness = thickness
