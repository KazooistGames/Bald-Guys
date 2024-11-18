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
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		collider.shape.radius = 0.5
		collider.shape.height = 1.5
		
		for node in contained_bodies:			
			hold.rpc(node.get_path())
			
	elif Holding:
		Holding = false
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		collider.shape.radius = 0.0
		collider.shape.height = 0.0
		
		for node in contained_bodies:
			throw.rpc(node.get_path())
		
		
@rpc("call_local")		
func hold(node_path):
	
	var node = get_node(node_path)
	
	if can_be_forced(node):
		var disposition = global_position - node.global_position	
		var direction = disposition.normalized()
		var magnitude = 250 * node.mass * pow(disposition.length(), 2.0)
		node.apply_central_force(direction * magnitude)


@rpc("call_local")
func throw(node_path):
	
	var node = get_node(node_path)
	
	if can_be_forced(node):

		#var aim = global_position - get_parent().global_position
		var aim = Wielder.LOOK_VECTOR.normalized() * Vector3(-1, 1, -1)
		var scatter = node.global_position - get_parent().global_position
		var direction = aim.lerp(scatter, 0.2)
		var magnitude = 2000.0 * node.mass
		node.apply_central_force(magnitude * direction)
		
		var lift = Vector3.UP * magnitude / 10.0
		node.apply_central_force(lift)
			
@rpc("call_local")
func push(node_path):
	
	var node = get_node(node_path)
	
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
			

			
