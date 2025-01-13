extends Node3D

const map_size = 50

@onready var bouncing_geometry = $Bouncing_Geometry
@onready var mesa_grower = $Mesa_Grower
@onready var item_dropper = $Item_Dropper
@onready var ramparter = $Ramparter
@onready var limb_grower = $Limb_Grower

var reconfigure_period = 90.0
var reconfigure_timer = 0.0

var mesa_count = 25
var ramp_freq = 0.5
var limb_freq = 1./3.
		
		
func _ready():
	
	if not is_multiplayer_authority():
		return
	
	reconfigure_timer = reconfigure_period - 10.0
	bouncing_geometry.spawn_hover_boards(10)
	item_dropper.spawn_field(0, 10, 10, 5, Vector3.UP * 25)
	item_dropper.spawn_field(2, 3, 3, 5, Vector3.UP * 25)
	
	#going up
	mesa_grower.finished_extending.connect(stage_ramps)
	ramparter.finished_lifting.connect(stage_limbs)
	limb_grower.finished_extending.connect(start_reconfigure_timer)
		
	#going down
	limb_grower.finished_retracting.connect(unstage_ramps) #unstage the limbs to kick everything off
	ramparter.finished_collapsing.connect(unstage_mesas)
	
	#loops here!
	mesa_grower.finished_retracting.connect(stage_mesas) 
	
	stage_mesas()
	

func _physics_process(delta):
	
	if not is_multiplayer_authority():
		return
	
	if reconfigure_timer < 0:
		pass
		
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
			
		if randf() <= ramp_freq:
			ramparter.spawn_ramp(mesa.position, mesa.size, mesa.size)
			
	ramparter.lift()
	
	
func stage_limbs():
	
	mesa_grower.stop_mesas()
	ramparter.stop()

	var orientation_to_use = 0
	for mesa in mesa_grower.mesas:
		
		var limbs_on_mesa = 0

		while randf() <= limb_freq and limbs_on_mesa < 4:
		#if randf() <= limb_freq:
			limb_grower.spawn_limb(orientation_to_use, mesa.global_position)
			orientation_to_use += PI / 2.0
			orientation_to_use = fmod(orientation_to_use, 2.0 * PI)
			
	limb_grower.extend_limbs()
			
			
func start_reconfigure_timer():
	
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
	

	


	

	

