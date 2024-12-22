extends Area3D

enum Action {
	inert = 0,
	holding = 1,
	charging = 2,	
}

@export var action = Action.inert

@export var base_position = Vector3.ZERO

@export var Aim = Vector3.ZERO

@export var Max_kg = 500

@export var wielder : Node3D = null

@onready var collider = $CollisionShape3D

@onready var mesh = $MeshInstance3D

@onready var hum = $hum

var contained_mass = 0

var contained_bodies = []

const hold_force = 5000.0	
const throw_force = 750.0
const push_force = 200.0

var charge_period = 1.0
var charge_timer = 0.0
var early_discharge = false

var position_projection = 1.25


func _ready():

	body_entered.connect(add_body)
	body_exited.connect(remove_body)
	hum.play()


func _physics_process(delta):

	if action == Action.holding:
		monitoring = true
		collision_mask = 12
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		
		hum.stream_paused = false
		hum.volume_db = -27.0
		hum.pitch_scale = 1.0
		collider.shape.radius = move_toward(collider.shape.radius, 0.5, 3.0 * delta)
		collider.shape.height = move_toward(collider.shape.height, 1.5, 5.0 * delta)
		
		if is_multiplayer_authority():
			
			for node in contained_bodies:			
				rpc_hold.rpc(node.get_path())
			
			
	elif action == Action.charging:
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		monitoring = true
		collision_mask = 14
		
		var progress = charge_timer/charge_period
		
		collider.shape.radius = lerp(1.0, 0.75, progress)
		collider.shape.height = lerp(0.75, 3.0, progress)
		charge_timer += delta
		
		hum.stream_paused = false
		hum.volume_db = lerp(-27.0, -18.0, progress)
		hum.pitch_scale = lerp(0.75, 1.5, progress)

		if not is_multiplayer_authority():
			pass
		elif progress >= 1.0:
			rpc_trigger.rpc()
		elif early_discharge and progress >= 0.25:
			rpc_trigger.rpc()
			
	elif action == Action.inert:	
		hum.stream_paused = true
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED	
		gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		monitoring = false
		charge_timer = 0
		collider.shape.radius = 0.0
		collider.shape.height = 0.0
		
		for node in contained_bodies:
			remove_body(node)
			
	mesh.mesh.top_radius = collider.shape.radius
	mesh.mesh.bottom_radius = collider.shape.radius
	mesh.mesh.height = collider.shape.height
	position = base_position + Aim.normalized() * collider.shape.height/2.0
		
			
@rpc("call_local")
func rpc_trigger():
	
	if action == Action.holding:
		
		for node in contained_bodies:
			rpc_throw(node.get_path())
			
	elif action == Action.charging:
	
		if charge_timer < charge_period and not early_discharge:
			early_discharge = true
			return
			
		for node in contained_bodies:
			rpc_push(node.get_path())	
				
	charge_timer = 0	
	early_discharge = false
	action = Action.inert	
		
		
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
		node.apply_central_impulse(magnitude * direction)
		var lift = Vector3.UP * magnitude / 10.0
		node.apply_central_force(lift)
		
			
@rpc("call_local")
func rpc_push(node_path):
	
	var node = get_node(node_path)

	if !can_be_pushed(node):
		pass
		
	elif node.is_in_group("humanoids"):
		
		if multiplayer.get_unique_id() != node.get_multiplayer_authority():
			return
			
		var disposition = (node.global_position - get_parent().global_position).normalized()
		var direction = disposition.lerp(Vector3.UP, 0.25)
		var magnitude = push_force / 8.0
		node.ragdoll.rpc(direction * magnitude)
		
	else:
		var disposition = node.global_position - get_parent().global_position
		disposition.y /= 10 	
		var direction = Aim.lerp(disposition.normalized(), 1.0)
		var magnitude = push_force * sqrt(node.mass)
		node.apply_central_impulse(magnitude * direction)
		var lift = Vector3.UP * magnitude / 10.0
		node.apply_central_force(lift)
				
			
func get_scattered_aim(node):
	
	var count = contained_bodies.size()
	var lerp_val = (count - 1) * 0.1
	lerp_val = clampf(lerp_val, 0.0, 0.6)
	
	var disposition = node.global_position - get_parent().global_position
	disposition.y /= 10
	
	return Aim.lerp(disposition.normalized(), lerp_val)
	
	
func add_body(node):
	
	if not can_be_pushed(node):
		pass
		
	elif node.mass + contained_mass > Max_kg:
		pass
	
	else:
		contained_bodies.append(node)
		contained_mass += node.mass
	
	
func remove_body(node):
	
	if contained_bodies.has(node):
		contained_bodies.erase(node)
		contained_mass -= node.mass
		
		
func can_be_pushed(node):

	if node == null:
		return false
		
	elif node == wielder:
		return false
		
	elif not node is RigidBody3D:
		return false
		
	else:
		return true
			
			
func can_be_held(node):
	
	if not can_be_pushed(node):
		return false
			
	elif node.linear_velocity.length() >= 20:
		return false
		
	elif node.is_in_group("humanoids"):
		return false
		
	else:
		return true

			
