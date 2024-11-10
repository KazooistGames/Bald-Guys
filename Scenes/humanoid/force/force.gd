extends Area3D

@onready var collider = $CollisionShape3D

@export var Holding = false

@export var Wielder : Node3D = null

var contained_bodies = []


func _ready():
	
	
	if not Wielder:
		queue_free()
		
	elif not Wielder.is_in_group("humanoids"):
		queue_free()
	
	else:
		body_entered.connect(add_body)
		body_exited.connect(remove_body)


func _physics_process(_delta):
		
	if Wielder.REACHING:
		Holding = true
		
		for node in contained_bodies:
			hold(node)
			
	elif Holding:
		Holding = false
				
		for node in contained_bodies:
			throw(node)
		
		
func hold(node):
	
	if can_be_forced(node):

		var disposition = global_position - node.global_position	

		var direction = disposition.normalized()
		var magnitude = 150 * node.mass * pow(disposition.length(), 3.0)

		node.apply_central_force(direction * magnitude)


func throw(node):

	if can_be_forced(node):

		var disposition = global_position - get_parent().global_position
		var scatter = node.global_position - get_parent().global_position
		var direction = disposition.lerp(scatter, 0.25)
		var magnitude = 1000 * node.mass
		
		node.apply_central_force(magnitude * direction)
			

func push(node):
	
	if can_be_forced(node):

		var direction = node.global_position - Wielder.global_position
		
		var magnitude = 1000 * node.mass
		
		node.apply_central_force(magnitude * direction)
			
			
func add_body(node):
	
	if can_be_forced(node):
		contained_bodies.append(node)
	
	
func remove_body(node):
	
	if can_be_forced(node):
		contained_bodies.erase(node)
		
		
func can_be_forced(node):
	
	if node == null:
		return false
		
	elif not node is RigidBody3D:
		return false
		
	elif node == Wielder:
		return false
	
	elif node.is_in_group("humanoids"):
		return false
		
	else:
		return true
			

			
