extends Node3D

const map_size = 50

@export var autocycle = true

@onready var board_hoverer = $Board_Hoverer
@onready var mesa_grower = $Mesa_Grower
@onready var item_dropper = $Item_Dropper
@onready var ramparter = $Ramparter
@onready var limb_grower = $Limb_Grower

@onready var session = get_parent()

var autocycle_period = 120.0
var autocycle_timer = -1.0
			
var multiplayer_permissive = false
	
var rng = RandomNumberGenerator.new()
		
		
func _ready():
	
	if not multiplayer.has_multiplayer_peer():
		multiplayer_permissive = true
	elif is_multiplayer_authority():
		multiplayer_permissive = true
	
	if not multiplayer_permissive:
		return
	
	#going up
	board_hoverer.finished_introducing.connect(stage_mesas)
	mesa_grower.finished_extending.connect(stage_ramps)
	ramparter.finished_lifting.connect(stage_limbs)
	limb_grower.finished_extending.connect(start_reconfigure_timer)
	
	#going down
	limb_grower.finished_retracting.connect(unstage_ramps) #unstage the limbs to kick everything off
	ramparter.finished_collapsing.connect(unstage_mesas)
	mesa_grower.finished_retracting.connect(unstage_boards) 
	
	#loops here!
	board_hoverer.finished_retreating.connect(stage_boards)

	#hook into session framework
	session.Started_Round.connect(start_map)
	session.Ended_Round.connect(stop_map)
	

func _physics_process(delta):

	if not multiplayer_permissive:
		pass

	elif not autocycle:
		pass
		
	elif autocycle_timer < 0:
		item_dropper.collect_items.rpc(0, Vector3.UP * 35.0)
		item_dropper.collect_items.rpc(2, Vector3.UP * 35.0, 0.75)
		
	elif autocycle_timer >= autocycle_period or Input.is_action_just_pressed("Toggle2"):
		autocycle_timer = -1
		unstage_limbs()
		print("reconfiguring map...")
		
	else:
		autocycle_timer += delta

	
func stage_boards():
	
	board_hoverer.clear_boards.rpc()
	board_hoverer.introduce_boards.rpc()
	board_hoverer.create_boards.rpc(5, 3, 4, Vector2(0, 15), hash(randi()))
	board_hoverer.create_boards.rpc(3, 6, 2, Vector2(15, 20), hash(randi()))
	board_hoverer.create_boards.rpc(1, 12, 1, Vector2(20, 25), hash(randi()))


func stage_mesas():

	board_hoverer.bounce_boards.rpc()
	mesa_grower.clear_mesas.rpc()
	mesa_grower.create_mesas.rpc(hash(randi()))	
	mesa_grower.extend_mesas.rpc()

func stage_ramps():
	mesa_grower.stop.rpc()
	ramparter.create_ramps.rpc(hash(randi()))
	ramparter.lift.rpc()
	
	
func stage_limbs():
	mesa_grower.stop.rpc()
	ramparter.stop.rpc()	
	limb_grower.create_limbs.rpc(hash(randi()))		
	limb_grower.extend_limbs.rpc()
	board_hoverer.synchronize_all_peers()
			
			
func start_reconfigure_timer(preset = 0):
	
	item_dropper.disperse_items.rpc(0)
	item_dropper.disperse_items.rpc(2, 6.0)
	limb_grower.stop.rpc()
	autocycle_timer = preset			
	
			
func unstage_limbs():
	limb_grower.retract_limbs.rpc()
		
	
func unstage_ramps():
	limb_grower.stop.rpc()
	limb_grower.clear_limbs.rpc()
	ramparter.collapse.rpc()
	
	
func unstage_mesas():

	ramparter.stop.rpc()
	ramparter.clear_ramps.rpc()
	mesa_grower.retract_mesas.rpc()
	
	
func unstage_boards():
	
	mesa_grower.stop.rpc()
	mesa_grower.clear_mesas.rpc()
	board_hoverer.retreat_boards.rpc()
	
	
func start_map():
	
	autocycle_timer = -1
	board_hoverer.create_boards.rpc(5, 3, 4, Vector2(0, 15), hash(randi()))
	board_hoverer.create_boards.rpc(3, 6, 2, Vector2(15, 20), hash(randi()))
	board_hoverer.create_boards.rpc(1, 12, 1, Vector2(20, 25), hash(randi()))
	item_dropper.spawn_field(0, 5, 5, 10, Vector3.UP * 25)
	item_dropper.spawn_field(2, 3, 3, 10, Vector3.UP * 25)
	stage_boards()
	#loops here!
	mesa_grower.finished_retracting.connect(stage_mesas) 
	

func stop_map():
	
	item_dropper.clear_all_items()
	limb_grower.retract_limbs()
	mesa_grower.finished_retracting.disconnect(stage_mesas) 

	


	

	

