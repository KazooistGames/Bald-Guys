extends Node3D


const map_size = 50


const mesa_prefab = preload("res://Scenes/objects/mesa/mesa.tscn")

var height_step = 0.5
var extend_mesas_speed = 0.5
var retract_mesas_speed = 2.0
var reconfigure_period = 60.0
var reconfigure_timer = 0.0

var floor_mesa_count = 25
var floor_mesas = []

var hover_mesa_count = 10
var hover_mesas = []
#var hover_vectors = []

enum MesaConfiguration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}

var mesa_config = MesaConfiguration.inert
		
		
func _ready():
	
	reconfigure_timer = reconfigure_period - 5

	for index in range(hover_mesa_count): #create hovering platforms
		var new_mesa = mesa_prefab.instantiate()
		$Mesas.add_child(new_mesa)		
		var mesa_size = 3
		var boundary = map_size/2.0 - mesa_size/2.0
		new_mesa.size = mesa_size
		new_mesa.position.x = randi_range(-boundary, boundary)
		new_mesa.position.z = randi_range(-boundary, boundary)
		new_mesa.position.y = 1
		new_mesa.bottom_drop = height_step
		new_mesa.preference = new_mesa.Preference.deep
		new_mesa.raycast.target_position = Vector3.DOWN * height_step / 2.5
		hover_mesas.append(new_mesa)

	randomize_hover_trajectories()


func _physics_process(delta):
	
	reposition_hover_mesas(delta)	
	
	if reconfigure_timer >= reconfigure_period:
		reconfigure_timer -= reconfigure_period
		retract_mesas()
		
	elif mesa_config == MesaConfiguration.inert:
		reconfigure_timer += delta				
		
	else:
		reposition_floor_mesas(delta)
	
	
func randomize_hover_trajectories():
	
	for index in range(hover_mesa_count):
		var mesa = hover_mesas[index]
		var new_vector = Vector3(randf(), randf() / 4.0, randf()).normalized()
		var speed = index/5.0 + 3
		mesa.constant_linear_velocity = new_vector * speed
	
		
func reconfigure_mesas():
	
	randomize_hover_trajectories()
	
	for mesa in floor_mesas:
		mesa.queue_free()
		
	floor_mesas.clear()

	for index in range(floor_mesa_count):
		var new_mesa = mesa_prefab.instantiate()
		$Mesas.add_child(new_mesa)		
		var mesa_size = randi_range(2, 5)
		var boundary = map_size/2.0 - mesa_size/2.0
		new_mesa.size = mesa_size
		new_mesa.position.x = randi_range(-boundary, boundary)
		new_mesa.position.z = randi_range(-boundary, boundary)
		new_mesa.position.y = -1
		new_mesa.bottom_drop = height_step
		new_mesa.preference = new_mesa.Preference.deep

		floor_mesas.append(new_mesa)
		
	extend_mesas()
	
	
func reposition_floor_mesas(delta):
	
	var mesas_in_position = 0
	
	for index in range(floor_mesas.size()): #move floor mesas
		var mesa = floor_mesas[index]
		var target = -1
		
		if mesa_config == MesaConfiguration.extending:
			target = (1+index) * height_step
			var step = extend_mesas_speed * delta * (1+index)
			mesa.position.y = move_toward(mesa.position.y, target, step)
		
		elif mesa_config == MesaConfiguration.retracting:
			var step = retract_mesas_speed * delta
			mesa.position.y = move_toward(mesa.position.y, target, step)
			
		if mesa.position.y == target:
			mesas_in_position += 1
		
	if mesas_in_position != floor_mesas.size():
		pass	
	elif mesa_config == MesaConfiguration.extending:
		stop_mesas()	
	elif mesa_config == MesaConfiguration.retracting:
		reconfigure_mesas()
	
	
func sweep_hover_collider(mesa):
	var physics_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = mesa.collider.shape
	query.transform = mesa.collider.global_transform
	query.motion = mesa.constant_linear_velocity
	query.exclude = [mesa.get_rid(), self.get_parent_node_3d()]
	query.collision_mask = 0b0001
	var result = physics_state.collide_shape(query)
	
	if result.size() > 0:
		var offset = result[0] - mesa.collider.global_transform.origin
		return offset 
	
func reposition_hover_mesas(delta):
	
	for index in range(hover_mesas.size()): #move hover mesas	
		var mesa = hover_mesas[index]
		var intersection = sweep_hover_collider(mesa)
		var height = 15
		var xz_bounds = mesa.size / 2.05
		var y_bounds = mesa.raycast.target_position.length() / 2.05
		var trajectory = mesa.constant_linear_velocity
		
		if intersection == null:
			pass
			
		elif abs(intersection.x) >= xz_bounds:
				var x_pen = (xz_bounds - abs(intersection.x)) * sign(intersection.x)
				mesa.position.x += x_pen
				trajectory.x = -trajectory.x 
	
		elif abs(intersection.z) >= xz_bounds:
			var z_pen = (xz_bounds - abs(intersection.z)) * sign(intersection.z)
			mesa.position.z += z_pen
			trajectory.z = -trajectory.z 
			
		elif abs(intersection.y) >= y_bounds:
			var y_pen = (y_bounds - abs(intersection.y) / 2.0) * sign(intersection.y)
			mesa.position.y += y_pen
			trajectory.y = -trajectory.y

		if mesa.position.y > height:
			trajectory.y = -trajectory.y
			mesa.position.y = height
			
		elif mesa.position.y < height_step:
			trajectory.y = -trajectory.y
			mesa.position.y = height_step

		mesa.position += trajectory * delta
		mesa.constant_linear_velocity = trajectory
	
		
func extend_mesas():
	
	if mesa_config == MesaConfiguration.extending:
		return
	else:
		mesa_config = MesaConfiguration.extending
		
		
func retract_mesas():
	
	if mesa_config == MesaConfiguration.retracting:
		return
	else:
		mesa_config = MesaConfiguration.retracting
		
		
func stop_mesas():
	
	if mesa_config == MesaConfiguration.inert:
		return
	else:
		mesa_config = MesaConfiguration.inert

