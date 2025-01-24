extends Area3D

enum Action {
	inert = 0,
	holding = 1,
	charging = 2,	
	cooldown = -1,
}

@export var action = Action.inert

@export var base_position = Vector3.ZERO

@export var Aim = Vector3.ZERO

@export var Max_kg = 100

@export var wielder : Node3D = null

@export var external_velocity = Vector3.ZERO

@onready var collider = $CollisionShape3D

@onready var mesh = $MeshInstance3D

@onready var hum = $hum

@onready var raycast = $RayCast3D

const hold_force = 8000.0	
const throw_force = 750.0
const push_force = 200.0
const ragdoll_radius = 1.5

var charge_period = 0.25
var charge_timer = 0.0

var contained_bodies = []

var cooldown_period = 0.75
var cooldown_timer = 0.0

var offset = 1.25

var material;

var target_position

func _ready():
	
	rpc_reset()
	monitoring = true


func _physics_process(delta):

	material = mesh.get_surface_override_material(0)
	
	capture_bodies()


	if action == Action.holding:
		collider.shape.radius = move_toward(collider.shape.radius, 1.0, 2.0 * delta)
		collider.shape.height = move_toward(collider.shape.height, 2.0, 5.0 * delta)
		
		if is_multiplayer_authority():
							
			for node in contained_bodies:			
				rpc_hold_object.rpc(node.get_path())
			
	elif action == Action.charging:
		charge_timer += delta
		var progress = pow(clamp(charge_timer/charge_period, 0.0, 1.0), 3.0)
		collider.shape.radius = lerp(0.0, 1.0, progress)
		collider.shape.height = lerp(0.0, 2.0, progress)
		hum.volume_db = lerp(-27.0, -21.0, progress)
		hum.pitch_scale = lerp(0.5, 1.5, progress)

		if not is_multiplayer_authority():
			pass
			
		elif progress >= 1.0:
			rpc_trigger.rpc()
		
	elif action == Action.inert:	
		collider.shape.radius = move_toward(collider.shape.radius, 0, 3.0 * delta)
		collider.shape.height = move_toward(collider.shape.height, 0, 5.0 * delta)
		
	elif action == Action.cooldown:
		collider.shape.radius = move_toward(collider.shape.radius, 0, 8.0 * delta)
		collider.shape.height = move_toward(collider.shape.height, 0, 8.0 * delta)
		
		if collider.shape.radius == 0:
			mesh.visible = false	
			
		cooldown_timer += delta
		var progress = clamp(cooldown_timer/cooldown_period, 0.0, 1.0)
		hum.pitch_scale = lerp(1.5, 0.5, progress)
		if cooldown_timer >= cooldown_period:
			rpc_reset.rpc()
		
	mesh.mesh.radius = collider.shape.radius * 0.8
	mesh.mesh.height = collider.shape.height* 0.8
	mesh.rotate(Vector3.UP, delta * 0.9)
	mesh.rotate(Vector3.FORWARD, delta)
	mesh.rotate(Vector3.RIGHT, delta * 1.1)
	mesh.set_surface_override_material(0, material)
	target_position = base_position + Aim.normalized() * offset * (1 + held_mass() / Max_kg / 2.0)
	position = position.move_toward(target_position, delta * 5.0)
	
	
@rpc("call_local", "reliable")
func rpc_primary():
	
	if action != Action.inert:
		return
				
	mesh.visible = true	
	collision_mask = 14
	linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	hum.play()
	charge_timer = 0	
	material.set_shader_parameter("glow_freq", 0.0)
	material.set_shader_parameter("base_freq", 0.0)
	material.set_shader_parameter("transparency", 0.05)
	material.set_shader_parameter("color", Vector3(1., 0., 1.))
	action = Action.charging


@rpc("call_local", "reliable")
func rpc_secondary():
	
	if action != Action.inert:
		return	
		
	mesh.visible = true
	collision_mask = 12
	linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	angular_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	hum.play()
	hum.volume_db = -27.0
	hum.pitch_scale = 1.0
	material.set_shader_parameter("glow_freq", PI)
	material.set_shader_parameter("base_freq", 1.0 + 1.0/PI)
	material.set_shader_parameter("transparency", 0.025)
	material.set_shader_parameter("color", Vector3(0.0, 1.0, 0.0))
	action = Action.holding
	
	
@rpc("call_local", "reliable")
func rpc_reset():
	
	if action == Action.cooldown && cooldown_timer <= cooldown_period:
		return	
		
	mesh.visible = false	
	collision_mask = 0
	linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED	
	gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	hum.bus = "phaser"
	hum.stop()
	charge_timer = 0	
	cooldown_timer = 0.0
	action = Action.inert
	
			
@rpc("call_local", "reliable")
func rpc_trigger():
	
	collision_mask = 0
	linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED	
	gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	
	if not is_multiplayer_authority():
		pass
	
	elif action == Action.holding:
		
		for node in contained_bodies:
			rpc_throw_object.rpc(node.get_path())
			
	elif action == Action.charging:

		if charge_timer < charge_period:
			return
		
		for node in contained_bodies:
			rpc_push_object.rpc(node.get_path())
			
	hum.bus = "beef"		
	hum.play()
	hum.volume_db = -27
	cooldown_timer = 0.0
	action = Action.cooldown
		
		
@rpc("call_local")		
func rpc_hold_object(node_path):
	
	var node = get_node(node_path)
	
	if can_be_held(node):
		var disposition = global_position - node.global_position	
		var direction = disposition.normalized()
		var magnitude = hold_force * pow(disposition.length(), 2.0)
		node.apply_central_force(direction * magnitude)
		node.apply_central_force(external_velocity * node.mass)


@rpc("call_local", "reliable")
func rpc_throw_object(node_path):
	
	var node = get_node(node_path)
	
	if can_be_held(node):
		var direction = get_scattered_aim(node).lerp(Vector3.UP, 0.075)
		var magnitude = throw_force
		node.apply_central_impulse(magnitude * direction)
		
			
@rpc("call_local", "reliable")
func rpc_push_object(node_path):
	
	var node = get_node(node_path)
	
	if !can_be_pushed(node):
		pass
		
	elif node.is_in_group("humanoids"):
		
		if multiplayer.get_unique_id() != node.get_multiplayer_authority():
			return
	
		var disposition = node.global_position - get_parent().global_position
		var direction = disposition.normalized().lerp(Vector3.UP, 0.15)
		var magnitude = push_force / 8.0 / max(0.75, disposition.length())
		var impulse = direction * magnitude
		if disposition.length() <= ragdoll_radius:
			node.ragdoll.rpc(impulse)
		else:
			node.bump.rpc(impulse / 2.0)
		
	else:
		var disposition = (node.global_position - get_parent().global_position).normalized()
		var direction = launch_trajectory().lerp(disposition.normalized(), 0.5)
		var magnitude = push_force * sqrt(node.mass)
		node.apply_central_impulse(magnitude * direction)
				
			
func get_scattered_aim(node):
	
	var count = contained_bodies.size()
	var lerp_val = (count - 1) * 0.075
	lerp_val = clampf(lerp_val, 0.0, 0.5)
	var disposition = node.global_position - get_parent().global_position
	disposition.y =0
	return launch_trajectory().lerp(disposition.normalized(), lerp_val)
		
		
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


func held_mass():
	
	if action != Action.holding:
		return 0
		
	else:
		var total_mass = 0
		
		for body in contained_bodies:
			total_mass += body.mass
			
		return total_mass


func capture_bodies():
	
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
	
	return a.mass > b.mass
	

func launch_trajectory():
	
	if raycast.is_colliding():
		return (raycast.get_collision_point() - global_position).normalized()
	else:
		return Aim.normalized()
	
	
			
