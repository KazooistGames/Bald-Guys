
extends StaticBody3D

const debounce_period = 0.2 #limit rate that we re-generate a convex mesh

@export var dimensions = Vector3(1.0, 1.0, 1.0)

@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D

var cached_dimensions = Vector3.ZERO

var debounce_timer = 0.0

var need_new_collider = false

var slope = 0.0


func _process(_delta):

	collider.position = Vector3.ZERO
			
	if mesh_has_changed():
		need_new_collider = true
		mesh.mesh.size.x = dimensions.x
		mesh.mesh.size.y = dimensions.y
		mesh.mesh.size.z = dimensions.z
		slope = dimensions.y / dimensions.x
		mesh.position = Vector3.UP * dimensions.y / 2.0
		cache_mesh_size()
		

func _physics_process(delta):
	
	if not need_new_collider:
		pass
		
	elif debounce_timer <= debounce_period:
		debounce_timer += delta
		
	elif need_new_collider:
		debounce_timer = 0.0
		mesh_manipulation()
		need_new_collider = false
		#altered.emit()
		
	
func mesh_manipulation():
	
	for index in range(collider.shape.points.size()):
		var point = collider.shape.points[index]
		point.x = signf(point.x) * dimensions.x / 2.0
		point.y = signf(point.y) * dimensions.y
		point.z = signf(point.z) * dimensions.z / 2.0
		collider.shape.points[index] = point
		

func mesh_has_changed():
	
	return cached_dimensions != dimensions


func cache_mesh_size():
	
	cached_dimensions = dimensions
	
	
	
