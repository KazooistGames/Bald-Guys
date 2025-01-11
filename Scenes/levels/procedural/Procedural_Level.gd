extends Node3D


const map_size = 50

@onready var bouncing_geometry = $Bouncing_Geometry
@onready var mesa_grower = $Mesa_Grower
@onready var brick_fields = $Brick_Fields
@onready var ramparter = $Ramparter

var extend_mesas_speed = 0.5
var retract_mesas_speed = 2.0

var reconfigure_period = 10.0
var reconfigure_timer = 0.0
		
		
func _ready():
	
	if not is_multiplayer_authority():
		return
	
	reconfigure_timer = reconfigure_period - 5
	bouncing_geometry.spawn_hover_boards(10)
	brick_fields.spawn_field(10, 10, 5, Vector3.UP * 25)


func _physics_process(delta):
	reconfigure_period = 20.0
	
	if not is_multiplayer_authority():
		return
	
	if not mesa_grower.in_position:
		pass
		
	elif reconfigure_timer >= reconfigure_period:
		reconfigure_timer -= reconfigure_period
		mesa_grower.retract_mesas()
		ramparter.collapse()
		
	elif mesa_grower.configuration == mesa_grower.Configuration.inert:
		reconfigure_timer += delta		
		
	elif mesa_grower.configuration == mesa_grower.Configuration.retracting:
		
		mesa_grower.clear_mesas()
		mesa_grower.spawn_mesas(25)	
		mesa_grower.extend_mesas()
		
	elif mesa_grower.configuration == mesa_grower.Configuration.extending:
		mesa_grower.stop_mesas()
		ramparter.clear_mesas()
		ramparter.spawn_ramps(5)
		ramparter.lift()
	
	


	

	

