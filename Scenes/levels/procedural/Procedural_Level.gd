extends Node3D

const map_size = 50

@onready var bouncing_geometry = $Bouncing_Geometry
@onready var mesa_grower = $Mesa_Grower
@onready var item_dropper = $Item_Dropper
@onready var ramparter = $Ramparter

var reconfigure_period = 60.0
var reconfigure_timer = 0.0

var mesa_count = 25
var ramp_count = 5	 
		
		
func _ready():
	
	if not is_multiplayer_authority():
		return
	
	reconfigure_timer = reconfigure_period - 5
	bouncing_geometry.spawn_hover_boards(10)
	item_dropper.spawn_field(0, 10, 10, 5, Vector3.UP * 25)
	item_dropper.spawn_field(2, 3, 3, 5, Vector3.UP * 25)


func _physics_process(delta):

	reconfigure_period = 10.0
	var progress = reconfigure_timer / reconfigure_period;
	
	if not is_multiplayer_authority():
		return
	
	if not mesa_grower.in_position:
		pass
		
	elif progress >= 1.0:
		reconfigure_timer -= reconfigure_period
		mesa_grower.retract_mesas()
		ramparter.clear_ramps()
		
	elif mesa_grower.configuration == mesa_grower.Configuration.inert:
		reconfigure_timer += delta	
		
		if progress >= 0.95:
			ramparter.collapse()
		
	elif mesa_grower.configuration == mesa_grower.Configuration.retracting:
		
		mesa_grower.clear_mesas()
		mesa_grower.spawn_mesas(mesa_count)	
		mesa_grower.extend_mesas()
		
	elif mesa_grower.configuration == mesa_grower.Configuration.extending:
		mesa_grower.stop_mesas()
		
		for i in range(ramp_count):

			var index = clamp(i * 2, 0, mesa_count - 1)
			var mesa = mesa_grower.mesas[index]
			ramparter.spawn_ramp(mesa.position, mesa.size, mesa.size)
			
		ramparter.lift()
	
	


	

	

