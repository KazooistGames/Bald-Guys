extends Node3D

const map_size = 50

@onready var bouncing_geometry = $Bouncing_Geometry
@onready var mesa_grower = $Mesa_Grower
@onready var item_dropper = $Item_Dropper
@onready var ramparter = $Ramparter
@onready var limb_grower = $Limb_Grower

var reconfigure_period = 15.0
var reconfigure_timer = 0.0

var mesa_count = 25
var ramp_freq = 0.5
var limb_freq = 0.5
		
		
func _ready():
	
	if not is_multiplayer_authority():
		return
	
	reconfigure_timer = reconfigure_period - 10.0
	bouncing_geometry.spawn_hover_boards(10)
	item_dropper.spawn_field(0, 10, 10, 5, Vector3.UP * 25)
	item_dropper.spawn_field(2, 3, 3, 5, Vector3.UP * 25)


func _physics_process(delta):
	
	if not is_multiplayer_authority():
		return
		
	reconfigure_period = 15
	
	var progress = reconfigure_timer / reconfigure_period;
	
	if not mesa_grower.in_position:
		pass
		
	elif progress >= 1.0:
		reconfigure_timer -= reconfigure_period
		mesa_grower.retract_mesas()
		ramparter.clear_ramps()
		limb_grower.clear_limbs()
		
	elif mesa_grower.configuration == mesa_grower.Configuration.inert:
		reconfigure_timer += delta	
		
		if progress >= 0.90:
			ramparter.collapse()
			limb_grower.retract_limbs()
		
	elif mesa_grower.configuration == mesa_grower.Configuration.retracting:
		
		mesa_grower.clear_mesas()
		mesa_grower.spawn_mesas(mesa_count)	
		mesa_grower.extend_mesas()
		
	elif mesa_grower.configuration == mesa_grower.Configuration.extending:
		mesa_grower.stop_mesas()
		var orientation_to_use = 0
		for mesa in mesa_grower.mesas:
			
			if randf() <= ramp_freq:
				ramparter.spawn_ramp(mesa.position, mesa.size, mesa.size)
			
			var limbs_on_mesa = 0
	
			#while randf() <= limb_freq and limbs_on_mesa < 4:
			if randf() <= limb_freq:
				limb_grower.spawn_limb(orientation_to_use, mesa.global_position)
				orientation_to_use += PI / 2.0
				orientation_to_use = fmod(orientation_to_use, 2.0 * PI)
				
		ramparter.lift()
		limb_grower.extend_limbs()
	


	

	

