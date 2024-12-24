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

const hold_force = 8000.0	
const throw_force = 600.0
const push_force = 200.0

var charge_period = 0.5
var charge_timer = 0.0

var contained_bodies = []


func _ready():
	
	hum.play()
	monitoring = true
	

func _physics_process(delta):
	
	get_contained_bodies()

	if action == Action.holding:
		collision_mask = 12
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		collider.shape.radius = move_toward(collider.shape.radius, 0.5, 2.0 * delta)
		collider.shape.height = move_toward(collider.shape.height, 1.5, 5.0 * delta)
		
		if is_multiplayer_authority():
					
			for node in contained_bodies:			
				rpc_hold.rpc(node.get_path())
				
		hum.stream_paused = false
		hum.volume_db = -27.0
		hum.pitch_scale = 1.0
			
	elif action == Action.charging:
		collision_mask = 14
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		charge_timer += delta
		var progress = clamp(charge_timer/charge_period, 0.0, 1.0)
		collider.shape.radius = lerp(1.0, 0.75, progress)
		collider.shape.height = lerp(0.75, 3.0, progress)
		
		if not is_multiplayer_authority():
			pass
			
		elif progress >= 1.0:
			rpc_trigger.rpc()
			
		hum.stream_paused = false
		hum.volume_db = lerp(-27.0, -15.0, progress)
		hum.pitch_scale = lerp(0.5, 2.0, progress)
			
	elif action == Action.inert:	
		hum.stream_paused = true
		linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED	
		gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
		charge_timer = 0
		collider.shape.radius = 0.0
		collider.shape.height = 0.0
			
	mesh.mesh.top_radius = collider.shape.radius
	mesh.mesh.bottom_radius = collider.shape.radius
	mesh.mesh.height = collider.shape.height
	position = base_position + Aim.normalized() * collider.shape.height/1.5
		
			
@rpc("call_local")
func rpc_trigger():
	
	if action == Action.holding:
		
		for node in contained_bodies:
			rpc_throw.rpc(node.get_path())
			
	elif action == Action.charging:
	
		if charge_timer < charge_period:
			return
			
		for node in contained_bodies:
			rpc_push.rpc(node.get_path())	
				
	hum.stop()
	hum.play()
	charge_timer = 0	
	action = Action.inert	
		
		
@rpc("call_local")		
func rpc_hold(node_path):
	
	var node = get_node(node_path)
	
	if can_be_held(node):
		var disposition = global_position - node.global_position	
		var direction = disposition.normalized()
		var magnitude = hold_force * pow(disposition.length(), 2.0)
		node.apply_central_force(direction * magnitude)


@rpc("call_local", "reliable")
func rpc_throw(node_path):
	
	var node = get_node(node_path)
	
	if can_be_held(node):

		var direction = get_scattered_aim(node).lerp(Vector3.UP, 0.05)
		var magnitude = throw_force
		node.apply_central_impulse(magnitude * direction)
		
			
@rpc("call_local", "reliable")
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
		var disposition = (node.global_position - get_parent().global_position).normalized()
		var direction = Aim.lerp(disposition.normalized(), 0.5)
		var magnitude = push_force * sqrt(node.mass)
		node.apply_central_impulse(magnitude * direction)
				
			
func get_scattered_aim(node):
	
	var count = contained_bodies.size()
	var lerp_val = (count - 1) * 0.1
	lerp_val = clampf(lerp_val, 0.0, 0.6)
	
	var disposition = node.global_position - get_parent().global_position
	disposition.y /= 10
	
	return Aim.lerp(disposition.normalized(), lerp_val)
		
		
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


func get_contained_bodies():
	
	var raw_bodies = get_overlapping_bodies().filter(can_be_pushed)
	raw_bodies.sort_custom(sort_fat)
	
	contained_bodies = []
	var index = 0
	var total_mass = 0
	
	while index < raw_bodies.size() and (raw_bodies[index].mass + total_mass) <= Max_kg:
		var body = raw_bodies[index]
		contained_bodies.append(body)
		total_mass += body.mass
		index += 1
	
	
func sort_fat(a, b):
	
	if a.mass > b.mass:
		return true
		
	return false	
	
			
