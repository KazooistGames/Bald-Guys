@tool

extends StaticBody3D

@export var height = 1.0
@export var length = 2.0
@export var thickness = 1.0

@onready var mesh = $MeshInstance3D

var collider

var cached_height = 1.0
var cached_length = 2.0
var cached_thickness = 1.0

const debounce_period = 0.2
var debounce_timer = 0.0

var need_new_collider = false


func _ready():
	pass # Replace with function body.


func _process(delta):
	
	collider = find_child("CollisionShape3D*")
	debounce_timer += delta
	
	if not need_new_collider:
		pass
		
	elif debounce_timer >= debounce_period:
		debounce_timer -= debounce_period
		collider.queue_free()
		mesh.create_convex_collision(true, false)
		need_new_collider = false
		
	if mesh_has_changed():
		#collider.queue_free()
		need_new_collider = true
		mesh.mesh.size.x = length
		mesh.mesh.size.y = height
		mesh.mesh.size.z = thickness
		mesh.position = Vector3.UP * height / 2.0
		cache_mesh_size()


func mesh_has_changed():
	return height != cached_height or length != cached_length or thickness != cached_thickness


func cache_mesh_size():
	cached_length = length
	cached_height = height
	cached_thickness = thickness
