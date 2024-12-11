extends Area3D

enum Action {
	inert = 0,
	hold = 1,	
}

@export var action = Action.inert

@onready var collider = $CollisionShape3D

@export var Holding = false

@export var Wielder : Node3D = null

@export var Aim = Vector3.ZERO


var contained_bodies = []

const hold_force = 5000.0	
const throw_force = 25000.0


func _ready():

	body_entered.connect(add_body)
	body_exited.connect(remove_body)


func _physics_process(_delta):
	
	if action == Action.hold:
		monitoring = true
		Holding = true
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		collider.shape.radius = 0.5
		collider.shape.height = 1.0
	
		for node in contained_bodies:			
			rpc_hold(node.get_path())
			
	elif Holding:
		Holding = false
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		collider.shape.radius = 0.0
		collider.shape.height = 0.0

		for node in contained_bodies:
			rpc_throw(node.get_path())
			
		monitoring = false
		
		
@rpc("call_local")		
func rpc_hold(node_path):
	
	var node = get_node(node_path)
	
	if can_be_held(node):
		var disposition = global_position - node.global_position	
		var direction = disposition.normalized()
		var magnitude = hold_force * pow(disposition.length(), 2.0)
		node.apply_central_force(direction * magnitude)


@rpc("call_local")
func rpc_throw(node_path):
	
	var node = get_node(node_path)
	
	if can_be_held(node):

		var direction = get_scattered_aim(node)
		var magnitude = throw_force
		node.apply_central_force(magnitude * direction)
		var lift = Vector3.UP * magnitude / 20.0
		node.apply_central_force(lift)
		
			
@rpc("call_local")
func rpc_push(node_path):
	
	var node = get_node(node_path)
	
	if can_be_pushed(node):
		var direction = node.global_position - Wielder.global_position	
		var magnitude = throw_force / 2.0	
		node.apply_central_force(magnitude * direction)
			
			
func get_scattered_aim(node):
	
	var count = contained_bodies.size()
	var lerp_val = (count - 1) * 0.1
	lerp_val = clampf(lerp_val, 0.0, 0.6)
	
	var disposition = node.global_position - get_parent().global_position
	disposition.y /= 10
	
	return Aim.lerp(disposition.normalized(), lerp_val)
	
func add_body(node):
	
	if can_be_pushed(node):
		contained_bodies.append(node)
	
	
func remove_body(node):
	
	if contained_bodies.has(node):
		contained_bodies.erase(node)
		
		
func can_be_pushed(node):
	
	if node == null:
		return false
		
	elif not node is RigidBody3D:
		return false
		
	elif node == Wielder:
		return false
		
	elif node.linear_velocity.length() >= 20:
		return false
		
	else:
		return true
			
			
func can_be_held(node):
	
	if not can_be_pushed(node):
		return false
		
	elif node.is_in_group("humanoids"):
		return false
		
	else:
		return true

			
