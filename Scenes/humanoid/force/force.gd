extends Area3D

@onready var collider = $CollisionShape3D

@export var pivotOffset = Vector3.ZERO
@export var aim = Vector3.ZERO	


var wielder


func _ready():
	wielder = get_parent()


func _physics_process(delta):
	
	aim = wielder.LOOK_VECTOR
		
	var collidingNodes = get_overlapping_bodies()	
		
	if wielder.REACHING:
		
		for node in collidingNodes:
			hold(node)
			
		
func hold(node):
	
	if node == wielder:
			return
			
	elif node is RigidBody3D:

		var disposition = (global_position + pivotOffset) - node.global_position	

		var direction = disposition.normalized()
		var magnitude = 250 * node.mass * pow(disposition.length(), 3.0)

		node.apply_central_force(direction * magnitude)


func throw(node):

	if node == wielder:
			return
			
	elif node is RigidBody3D:
		var disposition = node.global_position - (global_position + pivotOffset)		
		var direction = aim.lerp(disposition, 0.2)
		var magnitude = 1000 * node.mass
		
		node.apply_central_force(magnitude * direction)
			

func push(node):
	
		if node == wielder:
			return
			
		elif node is RigidBody3D:
			var direction = node.global_position - (wielder.global_position + pivotOffset)
			
			var magnitude = 1000 * node.mass
			
			node.apply_central_force(magnitude * direction)
