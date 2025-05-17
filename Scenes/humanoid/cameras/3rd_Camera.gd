extends Camera3D

const MAX_ANGLE = PI/2.3
const DRAW_STRENGTH = -2.5
const RISE_STRENGTH = 1.0
const PAN_STRENGTH = 1.5
const VERT_STRENGTH = 0.25
const REPO_STRENGTH = 15
const zoom_deadband = 0.1

@export var Locked = false
@export var Zoomed = false :
	get:
		return Zoomed
	set(value):
		if value == Zoomed:
			zoom_debounce = 0.0
		elif zoom_debounce >= zoom_deadband or value:
			Zoomed = value
		else:
			zoom_debounce += get_physics_process_delta_time()
		
@onready var reticle = $reticle
@onready var raycast = $RayCast3D
@onready var shapecast = $ShapeCast3D
@onready var postprocessing = $postprocessing
@onready var humanoid = get_parent()
@onready var force = humanoid.find_child("Force")

var goal_position : Vector3 = Vector3.ZERO
var VERTICAL_SENSATIVITY = 0.005
var HORIZONTAL_SENSITIVITY = 0.005
var is_local_camera = false
var reposition_speed : float 
var draw_offset : Vector3
var base_position : Vector3
var verticality : float 
var rise_offset : Vector3 
var pan_offset : Vector3
var pivot_position : Vector3
var zoom_debounce : float = 0.0

func _ready():

	add_to_group("cameras")
	
	is_local_camera = str(multiplayer.get_unique_id()) == humanoid.name
	current = is_local_camera
	
	
func _physics_process(delta):
	
	if is_local_camera:
		reticle.expand_mode = 1
		reticle.size = Vector2.ONE * 4	
		reticle.position = get_center_of_screen() - reticle.size / 2.0
	
	if force.action == force.Action.holding:
		Zoomed = true
	elif force.action == force.Action.charging:
		Zoomed = true
	else:
		Zoomed = false
	
	Locked = humanoid.LUNGING	
	HORIZONTAL_SENSITIVITY = 0.002 if Zoomed else 0.004	
	reticle.visible = is_local_camera and Zoomed	
	#near = 0.075 if Zoomed else 0.15
	
	if Zoomed:
		var deadbanded = position == goal_position
		base_position = humanoid.bone_position('lowerBody')
		pan_offset = (humanoid.bone_position('chin') - base_position)
		pivot_position = base_position + pan_offset
		draw_offset = humanoid.LOOK_VECTOR.normalized().rotated(Vector3.UP, PI) * 0.15
		goal_position = pivot_position + draw_offset
		reposition_speed = 20
		
		if deadbanded:
			position = goal_position
		else:
			position = position.move_toward(goal_position, reposition_speed * delta)
		
	else:		
		verticality = humanoid.LOOK_VECTOR.normalized().rotated(Vector3.UP, PI).dot(Vector3.UP)
		rise_offset = Vector3.UP.move_toward(Vector3.ZERO, (verticality) * VERT_STRENGTH) * RISE_STRENGTH	
		base_position = humanoid.bone_position('lowerBody')
		pan_offset = (humanoid.bone_position('chin') - base_position) * Vector3(PAN_STRENGTH, 0, PAN_STRENGTH)
		pivot_position = base_position + rise_offset + pan_offset	
		#draw the camera back then adjust for any detected collisions
		draw_offset = corrected_draw(pivot_position)	
		goal_position = pivot_position + draw_offset	
		reposition_speed = position.distance_to(goal_position) * 15
		
		position = position.move_toward(goal_position, reposition_speed * delta)
	

func rotate_by_relative_delta(relative_delta):
	
	if Locked:
		pass
		
	else:
		rotate_y(-relative_delta.x * HORIZONTAL_SENSITIVITY )
		rotate_object_local(Vector3(1,0,0), -relative_delta.y * VERTICAL_SENSATIVITY)
		rotation.x = clamp(rotation.x, -MAX_ANGLE, MAX_ANGLE)
		rotation.y = fmod(rotation.y, 2 * PI)
		rotation.z = 0
		
	return rotation


func get_center_of_screen():
	
	var lookPoint = raycast.get_collision_point()
	var screenCenter = unproject_position(lookPoint)
	screenCenter.x = snapped(screenCenter.x, 1)
	screenCenter.y = snapped(screenCenter.y, 1)
	return screenCenter
	
	
func corrected_draw(pivot_position) -> Vector3:
	
	var movement_scalar = 1
	
	if humanoid.LUNGING:
		movement_scalar = 2.0
	elif not humanoid.RUNNING:
		movement_scalar = 0.5
		
	var standard_draw : Vector3 = humanoid.LOOK_VECTOR.normalized().rotated(Vector3.UP, PI) * DRAW_STRENGTH * movement_scalar
	var obstruction : Dictionary = get_obstruction(pivot_position, pivot_position+standard_draw)
	
	if obstruction.size() > 0:
		var collision_position : Vector3 = humanoid.to_local(obstruction['position'])
		var collision_draw : Vector3 = collision_position - pivot_position		
		return collision_draw
		return standard_draw.move_toward(collision_draw, 1.0)
				
	return standard_draw
	

func get_obstruction(pivot_position, draw_position) -> Dictionary:
	
	var space_state = get_world_3d().direct_space_state
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = humanoid.to_global(pivot_position)
	query.to = humanoid.to_global(draw_position)
	query.collision_mask = 0b0001
	query.exclude = [self, humanoid]
	
	var result = space_state.intersect_ray(query)
	return result
	
