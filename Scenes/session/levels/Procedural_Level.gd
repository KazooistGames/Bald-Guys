extends Node3D

@export var map_size : int = 50 :
	get:
		return map_size
	set(value):
		map_size = value
		room.request_new_size.rpc(value)
		hoverboard_stager.map_size = value
		mesa_grower.map_size = value
		ramparter.map_size = value
		limb_grower.map_size = value
		
@export var autocycle : bool= true

@onready var room : Node3D = $room
@onready var hoverboard_stager : Node3D = $Hoverboard_Stager
@onready var mesa_grower : Node3D = $Mesa_Grower
@onready var item_dropper : Node3D = $Item_Dropper
@onready var ramparter : Node3D = $Ramparter
@onready var limb_grower : Node3D = $Limb_Grower

@onready var session : Node3D = get_parent()

var autocycle_period : float = 120.0
var autocycle_timer : float = -1.0
			
var multiplayer_permissive : bool = false
	
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
		
		
func _ready() -> void:
	
	#hook into session framework

	
	if not multiplayer.has_multiplayer_peer():
		multiplayer_permissive = true
	elif is_multiplayer_authority():
		multiplayer_permissive = true
	else:
		multiplayer_permissive = false
	
	if not multiplayer_permissive:
		return
		
	session.Started_Round.connect(trigger_map_generation_cycle)
	session.Ended_Round.connect(trigger_map_clear_cycle)
	
	map_size = 25
	
	#arena going up
	hoverboard_stager.finished_introducing.connect(stage_mesas)
	mesa_grower.finished_extending.connect(stage_ramps)
	ramparter.finished_lifting.connect(stage_limbs)
	limb_grower.finished_extending.connect(start_reconfigure_timer)
	
	#arena going down
	limb_grower.finished_retracting.connect(unstage_ramps) #unstage the limbs to kick everything off
	ramparter.finished_collapsing.connect(unstage_mesas)
	mesa_grower.finished_retracting.connect(unstage_boards) 
	hoverboard_stager.finished_retreating.connect(resize_to_lobby)
	
	
func _process(_delta) -> void:
	
	session.map_size = map_size
	

func _physics_process(delta) -> void:
	
	if not multiplayer.has_multiplayer_peer():
		multiplayer_permissive = false
	elif is_multiplayer_authority():
		multiplayer_permissive = true
	else:
		multiplayer_permissive = false

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
	
	
func resize_to_lobby() -> void:
	
	hoverboard_stager.clear_boards.rpc()
	mesa_grower.clear_mesas.rpc()
	ramparter.clear_ramps.rpc()
	limb_grower.clear_limbs.rpc()
	map_size = 25
		
		
func trigger_map_generation_cycle() -> void:
	
	map_size = 50
	autocycle_timer = -1
	room.finished_resizing.connect(start_staging)

		
func start_staging() -> void:
	
	map_size = 50
	autocycle_timer = -1
	item_dropper.spawn_field(0, 5, 5, 5, Vector3.UP * map_size / 2.0)
	item_dropper.spawn_field(2, 3, 3, 5, Vector3.UP * map_size / 2.0)
	stage_boards()
	mesa_grower.finished_retracting.connect(stage_mesas) 
	

func trigger_map_clear_cycle() -> void:
	
	item_dropper.clear_all_items()
	limb_grower.retract_limbs()
	hoverboard_stager.stop_boards.rpc()
	mesa_grower.finished_retracting.disconnect(stage_mesas) 
	room.finished_resizing.disconnect(start_staging)
	
	
func stage_boards() -> void:
	
	hoverboard_stager.clear_boards.rpc()
	hoverboard_stager.create_boards.rpc(1, 12, 1, Vector2(18, 25), session.SEED)
	hoverboard_stager.create_boards.rpc(3, 6, 2, Vector2(12, 20))
	hoverboard_stager.create_boards.rpc(5, 3, 3, Vector2(0, 15))
	hoverboard_stager.introduce_boards.rpc()


func stage_mesas() -> void:

	hoverboard_stager.bounce_boards.rpc()
	mesa_grower.clear_mesas.rpc()
	mesa_grower.create_mesas.rpc(session.SEED)	
	mesa_grower.extend_mesas.rpc()


func stage_ramps() -> void:
	
	mesa_grower.stop.rpc()
	ramparter.clear_ramps.rpc()
	ramparter.create_ramps.rpc(session.SEED)
	ramparter.lift.rpc()
	
	
func stage_limbs() -> void:
	
	mesa_grower.stop.rpc()
	ramparter.stop.rpc()	
	limb_grower.clear_limbs.rpc()
	limb_grower.create_limbs.rpc(session.SEED)		
	limb_grower.extend_limbs.rpc()
	hoverboard_stager.synchronize_all_peers()
			
			
func start_reconfigure_timer(preset : float = 0.0) -> void:
	
	item_dropper.disperse_items.rpc(0)
	item_dropper.disperse_items.rpc(2, 6.0)
	limb_grower.stop.rpc()
	autocycle_timer = preset			
	
			
func unstage_limbs() -> void:
	
	limb_grower.retract_limbs.rpc()
		
	
func unstage_ramps() -> void:
	
	limb_grower.stop.rpc()
	limb_grower.clear_limbs.rpc()
	ramparter.collapse.rpc()
	
	
func unstage_mesas() -> void:

	ramparter.stop.rpc()
	ramparter.clear_ramps.rpc()
	mesa_grower.retract_mesas.rpc()
	
	
func unstage_boards() -> void:
	
	mesa_grower.stop.rpc()
	mesa_grower.clear_mesas.rpc()
	hoverboard_stager.retreat_boards.rpc()
	
	
func init_for_new_client(client_id) -> void:
	
	print(multiplayer.get_unique_id(), " initialzed geometry from server.")
	
	if hoverboard_stager.boards.size() > 0:
		hoverboard_stager.clear_boards.rpc_id(client_id)
		hoverboard_stager.create_boards.rpc_id(client_id, 1, 12, 1, Vector2(18, 25), hoverboard_stager.rng.seed)
		hoverboard_stager.create_boards.rpc_id(client_id, 3, 6, 2, Vector2(12, 20))
		hoverboard_stager.create_boards.rpc_id(client_id, 5, 3, 3, Vector2(0, 15))
		hoverboard_stager.bounce_boards.rpc_id(client_id)
		
	if mesa_grower.mesas.size() > 0:
		mesa_grower.clear_mesas.rpc_id(client_id)
		mesa_grower.create_mesas.rpc_id(client_id, session.SEED, false)	
		mesa_grower.stop.rpc_id(client_id)
		
	if ramparter.ramps.size() > 0:
		ramparter.clear_ramps.rpc_id(client_id)
		ramparter.create_ramps.rpc_id(client_id, session.SEED, false)	
		ramparter.stop.rpc_id(client_id)
	
	if limb_grower.limbs.size() > 0:
		limb_grower.clear_limbs.rpc_id(client_id)
		limb_grower.create_limbs.rpc_id(client_id, session.SEED, false)	
		limb_grower.stop.rpc_id(client_id)
	


	

	

