extends Node3D

@export var Map_Size : int = 25 

@onready var room : Node3D = $room
@onready var hoverboard_stager : Node3D = $Hoverboard_Stager
@onready var mesa_grower : Node3D = $Mesa_Grower
@onready var item_dropper : Node3D = $Item_Dropper
@onready var ramparter : Node3D = $Ramparter
@onready var limb_grower : Node3D = $Limb_Grower
@onready var session : Node3D = get_parent()
	
var multiplayer_permissive : bool = false
var level_rng : RandomNumberGenerator = RandomNumberGenerator.new()

signal generated
signal demolished

		
func _ready() -> void:
	
	Map_Size = 25
	
	if not multiplayer.has_multiplayer_peer():
		multiplayer_permissive = true
	elif is_multiplayer_authority():
		multiplayer_permissive = true
	else:
		multiplayer_permissive = false
	
	if not multiplayer_permissive:
		return	
	
	item_dropper.spawn_field(0, 5, 5, 5, Vector3.UP * Map_Size / 2.0)
	item_dropper.spawn_field(2, 3, 3, 5, Vector3.UP * Map_Size / 2.0)
	
	
func _process(_delta):

	hoverboard_stager.Map_Size = room.Current_Size
	
	if is_multiplayer_authority():
		
		if room.Current_Size != 50:
			item_dropper.collect_items.rpc(0, Vector3.UP * Map_Size / 2.0)
			item_dropper.collect_items.rpc(2, Vector3.UP * Map_Size / 2.0)
		
		
func generate() -> void:
	
	finish_demolish()
	print('generating level...')
	
	if not room.finished_resizing.is_connected(stage_boards):
		room.finished_resizing.connect(stage_boards)
		
	if not hoverboard_stager.finished_introducing.is_connected(stage_mesas):
		hoverboard_stager.finished_introducing.connect(stage_mesas)
		
	if not mesa_grower.finished_extending.is_connected(stage_ramps):
		mesa_grower.finished_extending.connect(stage_ramps)
		
	if not ramparter.finished_lifting.is_connected(stage_limbs):
		ramparter.finished_lifting.connect(stage_limbs)
		
	if not limb_grower.finished_extending.is_connected(finish_generate):
		limb_grower.finished_extending.connect(finish_generate)
		
	Map_Size = 50
	room.request_size(Map_Size)	


func finish_generate() -> void:
	
	print('finished generating level.')
	
	if room.finished_resizing.is_connected(stage_boards):
		room.finished_resizing.disconnect(stage_boards)
		
	if hoverboard_stager.finished_introducing.is_connected(stage_mesas):
		hoverboard_stager.finished_introducing.disconnect(stage_mesas)
		
	if mesa_grower.finished_extending.is_connected(stage_ramps):
		mesa_grower.finished_extending.disconnect(stage_ramps)
		
	if ramparter.finished_lifting.is_connected(stage_limbs):
		ramparter.finished_lifting.disconnect(stage_limbs)
		
	if limb_grower.finished_extending.is_connected(finish_generate):
		limb_grower.finished_extending.disconnect(finish_generate)


func demolish() -> void:
	
	finish_generate()
	print('demolishing level...')
	
	if not limb_grower.finished_retracting.is_connected(unstage_ramps):
		limb_grower.finished_retracting.connect(unstage_ramps) 
		
	if not ramparter.finished_collapsing.is_connected(unstage_mesas):
		ramparter.finished_collapsing.connect(unstage_mesas)
		
	if not mesa_grower.finished_retracting.is_connected(unstage_boards):
		mesa_grower.finished_retracting.connect(unstage_boards) 
	
	if not hoverboard_stager.finished_retreating.is_connected(reset_map):
		hoverboard_stager.finished_retreating.connect(reset_map)
		
	if not room.finished_resizing.is_connected(finish_demolish):
		room.finished_resizing.connect(finish_demolish)
	
	limb_grower.retract_limbs.rpc()
	#hoverboard_stager.stop_boards.rpc()


func finish_demolish() -> void:
	
	print('finished demolishing level.' )
	
	if limb_grower.finished_retracting.is_connected(unstage_ramps):
		limb_grower.finished_retracting.disconnect(unstage_ramps) 
		
	if ramparter.finished_collapsing.is_connected(unstage_mesas):
		ramparter.finished_collapsing.disconnect(unstage_mesas)
		
	if mesa_grower.finished_retracting.is_connected(unstage_boards):
		mesa_grower.finished_retracting.disconnect(unstage_boards) 
	
	if hoverboard_stager.finished_retreating.is_connected(reset_map):
		hoverboard_stager.finished_retreating.disconnect(reset_map)
		
	if room.finished_resizing.is_connected(finish_demolish):
		room.finished_resizing.disconnect(finish_demolish)
		
	demolished.emit()
	
	
func reset_map() -> void:
	
	hoverboard_stager.clear_boards.rpc()
	mesa_grower.clear_mesas.rpc()
	ramparter.clear_ramps.rpc()
	limb_grower.clear_limbs.rpc()
	Map_Size = 25	
	room.request_size(Map_Size)	
	
	
func stage_boards() -> void:
	
	item_dropper.disperse_items.rpc(0)
	item_dropper.disperse_items.rpc(2, 6.0)
	hoverboard_stager.clear_boards.rpc()
	hoverboard_stager.create_boards.rpc(1, 12, 1, Vector2(18, 25))
	hoverboard_stager.create_boards.rpc(3, 6, 2, Vector2(12, 20))
	hoverboard_stager.create_boards.rpc(5, 3, 3, Vector2(0, 15))
	hoverboard_stager.introduce_boards.rpc()


func stage_mesas() -> void:

	mesa_grower.Map_Size = room.Current_Size
	hoverboard_stager.bounce_boards.rpc()
	mesa_grower.clear_mesas.rpc()
	mesa_grower.create_mesas.rpc()	
	mesa_grower.extend_mesas.rpc()


func stage_ramps() -> void:
	
	ramparter.Map_Size = room.Current_Size
	mesa_grower.stop.rpc()
	ramparter.clear_ramps.rpc()
	ramparter.create_ramps.rpc()
	ramparter.lift.rpc()
	
	
func stage_limbs() -> void:
	
	limb_grower.Map_Size = room.Current_Size
	mesa_grower.stop.rpc()
	ramparter.stop.rpc()	
	limb_grower.clear_limbs.rpc()
	limb_grower.create_limbs.rpc()		
	limb_grower.extend_limbs.rpc()
	hoverboard_stager.synchronize_all_peers()		
	
			
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
	
	if hoverboard_stager.boards.size() > 0:
		hoverboard_stager.rpc_set_rng.rpc_id(client_id, null, hoverboard_stager.previous_rng_state)
		hoverboard_stager.clear_boards.rpc_id(client_id)
		hoverboard_stager.create_boards.rpc_id(client_id, 1, 12, 1, Vector2(18, 25))
		hoverboard_stager.create_boards.rpc_id(client_id, 3, 6, 2, Vector2(12, 20))
		hoverboard_stager.create_boards.rpc_id(client_id, 5, 3, 3, Vector2(0, 15))
		hoverboard_stager.bounce_boards.rpc_id(client_id)
		
	if mesa_grower.mesas.size() > 0:
		mesa_grower.rpc_set_rng.rpc_id(client_id, null, mesa_grower.previous_rng_state)
		mesa_grower.clear_mesas.rpc_id(client_id)
		mesa_grower.create_mesas.rpc_id(client_id, false)	
		mesa_grower.stop.rpc_id(client_id)
		
	if ramparter.ramps.size() > 0:
		ramparter.rpc_set_rng.rpc_id(client_id, null, ramparter.previous_rng_state)
		ramparter.clear_ramps.rpc_id(client_id)
		ramparter.create_ramps.rpc_id(client_id, false)	
		ramparter.stop.rpc_id(client_id)
	
	if limb_grower.limbs.size() > 0:
		limb_grower.rpc_set_rng.rpc_id(client_id, null, limb_grower.previous_rng_state)
		limb_grower.clear_limbs.rpc_id(client_id)
		limb_grower.create_limbs.rpc_id(client_id, false)	
		limb_grower.stop.rpc_id(client_id)
	

func seed_procedural_generators(new_seed):
	
	level_rng.seed = new_seed
	print(multiplayer.get_unique_id(), " level seed: ", level_rng.seed)	
	hoverboard_stager.rpc_set_rng(hash(level_rng.randi()), null)
	mesa_grower.rpc_set_rng(hash(level_rng.randi()), null)
	ramparter.rpc_set_rng(hash(level_rng.randi()), null)
	limb_grower.rpc_set_rng(hash(level_rng.randi()), null)
	

	

