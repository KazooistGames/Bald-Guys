extends Node3D

const map_size = 50

@onready var board_hoverer = $Board_Hoverer
@onready var mesa_grower = $Mesa_Grower
@onready var item_dropper = $Item_Dropper
@onready var ramparter = $Ramparter
@onready var limb_grower = $Limb_Grower

@onready var session = get_parent()

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
	
	#stage_mesas()
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
	

func stage_mesas():
	
	mesa_grower.clear_mesas()
	mesa_grower.extend_mesas()
	mesa_grower.spawn_mesas(mesa_count)	


func stage_ramps():
	
	mesa_grower.stop_mesas()
	
	for mesa in mesa_grower.mesas:
			
		if randf() <= ramp_freq: #roof
			ramparter.spawn_ramp(mesa.position, mesa.size, mesa.size, false, randi_range(0, 3) * PI/2)
			
		if randf() <= ramp_freq: #floor
			var y_rotation = randi_range(0, 3) * PI/2
			var base_offset = Vector3(-cos(y_rotation), 0, sin(y_rotation)).normalized() * mesa.size
			var ramp_position = mesa.position + base_offset
			ramp_position.y = 0
			ramparter.spawn_ramp(ramp_position, mesa.size, mesa.size, false, y_rotation)
			
	ramparter.lift()
	
	
func stage_limbs():
	
	mesa_grower.stop_mesas()
	ramparter.stop()

	var orientation_to_use = 0
	for mesa in mesa_grower.mesas:
		
		var limbs_on_mesa = 0

		while randf() <= limb_freq and limbs_on_mesa < 4:
			limb_grower.spawn_limb(orientation_to_use, mesa.global_position)
			orientation_to_use += PI / 2.0
			orientation_to_use = fmod(orientation_to_use, 2.0 * PI)
			
	limb_grower.extend_limbs()
			
			
func start_reconfigure_timer():
	item_dropper.disperse_items(0)
	item_dropper.disperse_items(2, 6.0)
	limb_grower.stop_limbs()
	reconfigure_timer = 0			
	
			
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
	board_hoverer.spawn_boards(5, 3, 5, Vector2(0, 15))
	board_hoverer.spawn_boards(3, 5, 3, Vector2(15, 20))
	board_hoverer.spawn_boards(1, 8, 1, Vector2(20, 25))
	item_dropper.spawn_field(0, 5, 5, 10, Vector3.UP * 25)
	item_dropper.spawn_field(2, 3, 3, 10, Vector3.UP * 25)
	stage_mesas()
	

func stop_map():
	
	item_dropper.clear_all_items()
	limb_grower.clear_limbs()
	ramparter.clear_ramps()
	mesa_grower.clear_mesas()
	board_hoverer.clear_boards()
	

	


	

	

