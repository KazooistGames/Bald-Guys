extends Node3D

const map_size = 50

@onready var board_hoverer = $Board_Hoverer
@onready var mesa_grower = $Mesa_Grower
@onready var item_dropper = $Item_Dropper
@onready var ramparter = $Ramparter
@onready var limb_grower = $Limb_Grower

@onready var session = get_parent()

@onready var raycast = $RayCast3D

var reconfigure_period = 90.0
var reconfigure_timer = -1.0

var mesa_count = 25
var ramp_freq = 0.5
var limb_freq = 1.0/3.0
		
		
func _ready():
	
	if not is_multiplayer_authority():
		return
	
	#going up
	mesa_grower.finished_extending.connect(stage_ramps)
	ramparter.finished_lifting.connect(stage_limbs)
	limb_grower.finished_extending.connect(start_reconfigure_timer)
		
	#going down
	limb_grower.finished_retracting.connect(unstage_ramps) #unstage the limbs to kick everything off
	ramparter.finished_collapsing.connect(unstage_mesas)
	
	#loops here!
	mesa_grower.finished_retracting.connect(stage_mesas) 
	
	#hook into session framework
	session.Started_Round.connect(start_map)
	session.Ended_Round.connect(stop_map)
	

func _physics_process(delta):

	if not is_multiplayer_authority():
		return

	if reconfigure_timer < 0:
		item_dropper.collect_items(0, Vector3.UP * 35)
		item_dropper.collect_items(2, Vector3.UP * 35, 0.75)
		
	elif reconfigure_timer >= reconfigure_period:
		reconfigure_timer = -1
		unstage_limbs()
		print("reconfiguring map...")
		
	else:
		reconfigure_timer += delta
	
	
func node_is_in_bounds(node):
	
	raycast.global_position = node.global_position #move raycast to node position
	raycast.target_position = Vector3.UP * map_size * 1.1 #shoot it up to the ceiling
	raycast.force_raycast_update()	
	var hit_the_ceiling = raycast.is_colliding()	
	
	raycast.target_position = Vector3.DOWN * map_size * 2.0 #shoot it to the floor
	raycast.force_raycast_update()	
	var hit_the_floor = raycast.is_colliding()

	return hit_the_ceiling or hit_the_floor #node is considered inside level if it hits one
	

func stage_mesas():
	
	mesa_grower.clear_mesas()
	mesa_grower.extend_mesas()
	mesa_grower.spawn_mesas(mesa_count)	


func stage_ramps():
	
	mesa_grower.stop_mesas()
	
	for mesa in mesa_grower.mesas:
			
		if randf() <= ramp_freq: #roof
			var y_offset = Vector3.DOWN * randi_range(0, 1) * 0.75
			ramparter.spawn_ramp(mesa.position + y_offset, mesa.size, mesa.size, mesa.size/2.0, false, randi_range(0, 3) * PI/2)
			
		if randf() <= ramp_freq: #floor
			var y_rotation = randi_range(0, 3) * PI/2
			var base_offset = Vector3(-cos(y_rotation), 0, sin(y_rotation)).normalized() * mesa.size
			var ramp_position = mesa.position + base_offset
			ramp_position.y = 0
			var ramp_height
			
			if mesa.position.y >= mesa.size * 2.0:
				ramp_height = mesa.size * 2.0
			elif mesa.position.y >= mesa.size:
				ramp_height = mesa.size
			else:		
				ramp_height = minf(mesa.position.y, mesa.size / 2.0)
				
			ramparter.spawn_ramp(ramp_position, mesa.size, mesa.size, ramp_height, false, y_rotation)
			
	ramparter.lift()
	
	
func stage_limbs():
	
	mesa_grower.stop_mesas()
	ramparter.stop()

	var orientation_to_use = 0
	for mesa in mesa_grower.mesas:
		
		var limbs_on_mesa = 0

		while randf() <= limb_freq and limbs_on_mesa < 4:
			limb_grower.spawn_limb(orientation_to_use, mesa.global_position - Vector3.UP * 0.375)
			orientation_to_use += PI / 2.0
			orientation_to_use = fmod(orientation_to_use, 2.0 * PI)
			
	limb_grower.extend_limbs()
			
			
func start_reconfigure_timer(preset = 0):
	item_dropper.disperse_items(0)
	item_dropper.disperse_items(2, 6.0)
	limb_grower.stop_limbs()
	reconfigure_timer = preset			
	
			
func unstage_limbs():
	
	limb_grower.retract_limbs()
		
	
func unstage_ramps():
	
	limb_grower.stop_limbs()
	limb_grower.clear_limbs()
	ramparter.collapse()
	
	
func unstage_mesas():
	
	ramparter.stop()
	ramparter.clear_ramps()
	mesa_grower.retract_mesas()
	
	
func start_map():
	reconfigure_timer = -1
	board_hoverer.spawn_boards(5, 3, 4, Vector2(0, 15))
	board_hoverer.spawn_boards(3, 6, 2, Vector2(15, 20))
	board_hoverer.spawn_boards(1, 12, 1, Vector2(20, 25))
	item_dropper.spawn_field(0, 5, 5, 10, Vector3.UP * 25)
	item_dropper.spawn_field(2, 3, 3, 10, Vector3.UP * 25)
	stage_mesas()
	

func stop_map():
	
	item_dropper.clear_all_items()
	limb_grower.clear_limbs()
	ramparter.clear_ramps()
	mesa_grower.clear_mesas()
	board_hoverer.clear_boards()
	

	


	

	

