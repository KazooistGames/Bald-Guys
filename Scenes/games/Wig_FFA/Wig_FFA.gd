extends Game

const beas_mote_transition = 54.66
const beas_mote_end = 162.0

#var wig_remotes : Array = []

@onready var whispers = $Whispers
@onready var theme = $Theme
@onready var wig_remote = $RemoteTransform3D

var active_wig : RigidBody3D = null
var active_bearer : RigidBody3D = null


func _ready():

	whispers.stream_paused = false
	theme.stream_paused = true
	Goal = 30
	Players = 2
	
	
func _process(_delta):

	if session.wig_manager.wigs.size() == 0 or State != GameState.playing:
		whispers.stream_paused = true
		theme.stream_paused = true
		
	elif active_wig:
		session.HUD.find_child("Progress").visible = active_bearer_is_local_player()
		session.HUD.update_nameplate("WIG", active_wig.global_position, "WIG")
		whispers.global_position = active_wig.global_position
		whispers.stream_paused = active_bearer_is_local_player()
		theme.stream_paused = not active_bearer_is_local_player()
		
		if active_bearer != null:
			session.HUD.modify_nameplate("WIG", "visible", false)	
		
	if whispers.get_playback_position() >= beas_mote_transition:
		whispers.seek(0)
				
	if theme.get_playback_position() < beas_mote_transition:
		theme.seek(beas_mote_transition)


func _physics_process(delta):
	
	if session.wig_manager.wigs.size() > 0:
		active_wig = session.wig_manager.wigs.back()
		active_bearer = session.wig_manager.bearers.back()
	else:
		active_wig = null
		active_bearer = null
		
	if not multiplayer.has_multiplayer_peer():
		pass
	elif not is_multiplayer_authority():
		return		

	match State: # GAME STATE MACHINE
			
		GameState.reset:		
			pass
	
		GameState.playing:
		
			if session.wig_manager.wigs.size() == 0:
				_init_wig()
				return
				
			elif not active_wig or not active_bearer:				
				return
				
			var bearer_name = session.get_humanoids_screenname(active_bearer)
			
			if not Scores.has(bearer_name):
				Scores[bearer_name] = delta
			
			elif Scores[bearer_name] < Goal:
				Scores[bearer_name] += delta
				
			else:
				GameOver.emit()
			
		GameState.finished:			
			pass
		
		
func active_bearer_is_local_player() -> bool:
	
	if active_bearer:	
		return str(multiplayer.get_unique_id()) == active_bearer.name
	else:
		return false


func handle_player_leaving(client_id):
	
		var humanoid = session.get_node_or_null(str(client_id))
	
		if session.wig_manager.bearers.size() == 0:
			return
		elif session.wig_manager.bearers.back() == null:
			return
			
		if humanoid == null:
			pass
		elif not session.wig_manager.bearers.has(humanoid):
			pass
		elif humanoid == session.wig_manager.bearers.back() and State == GameState.playing: #this is the active wig
			session.wig_manager.drop_wig(humanoid)
		else: #we either arent playing, or this wig is already fused - either way, destroy it
			var bearer_index = session.wig_manager.bearers.find(humanoid)
			var wig = session.wig_manager.wigs[bearer_index]
			session.wig_manager.rpc_destroy_wig.rpc(wig.get_path())


func _init_wig():
	
	var extents : float = map_size / 2.25
	var random_position := Vector3(randi_range(-extents, extents), extents, randi_range(-extents, extents))
	var wig_radius := 0.25
	session.wig_manager.rpc_spawn_new_wig.rpc(wig_radius, wig_radius, random_position)
	

@rpc("call_local", "reliable")
func rpc_reset():
	
	session.HUD.remove_nameplate("WIG")
	session.HUD.find_child("Progress").visible = false		
	theme.seek(beas_mote_transition)

	if is_multiplayer_authority(): 	
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
			
		State = GameState.reset

	for index in session.wig_manager.wigs.size():	
		var bearer = session.wig_manager.bearers[index]
		var wig = session.wig_manager.wigs[index]
		
		if wig == null:
			continue
			
		#elif bearer == null:
			#session.wig_manager.rpc_destroy_wig.rpc(wig.get_path())
			
		else:	
			session.HUD.modify_nameplate(bearer.name, "theme_override_colors/font_color", Color.WHITE)
			session.HUD.modify_nameplate(bearer.name, "theme_override_font_sizes/font_size", 20)
			
		#wig.queue_free()
		

@rpc("call_local", "reliable")
func rpc_play():
	
	
	session.HUD.set_progress_label("Installing Wig...")
	session.HUD.add_nameplate("WIG", "WIG")
	session.HUD.modify_nameplate("WIG", "theme_override_colors/font_color", Color.GREEN_YELLOW)
	session.HUD.modify_nameplate("WIG", "theme_override_font_sizes/font_size", 24)
	theme.seek(beas_mote_transition)		
	session.wig_manager.dawned.connect(handle_mount)
	session.wig_manager.dropped.connect(handle_dismount)
	
	if is_multiplayer_authority(): 	
		session.HUD.set_psa.rpc("Capture the Wig!", 3)
		State = GameState.playing	
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0

	
@rpc("call_local", "reliable")
func rpc_finish():
	
	session.HUD.find_child("Progress").visible = false
	session.HUD.remove_nameplate("WIG")
	
	if active_bearer:			
		session.HUD.modify_nameplate(active_bearer.name, "theme_override_colors/font_color", Color.WHITE)
		session.HUD.modify_nameplate(active_bearer.name, "theme_override_font_sizes/font_size", 20)
		
	if is_multiplayer_authority(): 
		State = GameState.finished	
		
		if active_bearer == null:
			session.wig_manager.rpc_destroy_wig.rpc(active_wig.get_path())
			
		session.wig_manager.fuse_wig(active_bearer)

	session.wig_manager.dawned.disconnect(handle_mount)
	session.wig_manager.dropped.disconnect(handle_dismount)


func handle_player_joining(client_id) -> void:
	
	if State != GameState.playing:
		return
	#for index in range(session.wig_manager.wigs.size()):
		#session.wig_manager.rpc_spawn_new_wig.rpc_id(client_id)
		#var wig_path = session.wig_manager.wigs[index].get_path()
		#var bearer_path = null 
		#
		#if index < session.wig_manager.bearers.size():
			#bearer_path = null if session.wig_manager.bearers[index] == null else session.wig_manager.bearers[index].get_path()
		#
		#session.wig_manager.rpc_put_wig_on_head.rpc_id(client_id, wig_path, bearer_path)
		#
		#if State == GameState.finished:
			#session.wig_manager.rpc_fuse_wig_to_head.rpc_id(client_id, wig_path, bearer_path)		
	pass
	

func handle_mount(_wig, bearer):
	
	session.HUD.modify_nameplate(bearer.name, "theme_override_colors/font_color", Color.ORANGE_RED)
	session.HUD.modify_nameplate(bearer.name, "theme_override_font_sizes/font_size", 24)
	
	
func handle_dismount(_wig, bearer):
	
	session.HUD.modify_nameplate(bearer.name, "theme_override_colors/font_color", Color.WHITE)
	session.HUD.modify_nameplate(bearer.name, "theme_override_font_sizes/font_size", 20)
	

		

