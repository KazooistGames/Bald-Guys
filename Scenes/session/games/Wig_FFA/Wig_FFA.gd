extends Node3D

const wig_prefab = preload("res://Scenes/objects/wig/Wig.tscn")
const beas_mote_transition = 54.66
const beas_mote_end = 162.0

enum GameState {
	reset,
	playing,
	finished
}

@export var map_size = 50
@export var State = GameState.reset
@export var Goal = 30 #107.34
@export var Scores = {}
@export var wig_remotes : Array = []

@onready var whispers = $Whispers
@onready var theme = $Theme
@onready var session = get_parent()
@onready var wig_remote = $RemoteTransform3D

signal GameOver

var wigs : Array[Node] = []
var bearers : Array = []
#var active_index = -1


func _ready():

	whispers.stream_paused = false
	theme.stream_paused = true
	
	
func _process(_delta):

	#active_index = wigs.size() - 1
	wigs = get_tree().get_nodes_in_group("wigs")
	
	if wigs.size() == 0 or State != GameState.playing:
		whispers.stream_paused = true
		theme.stream_paused = true
		
	else:
		session.HUD.find_child("Progress").visible = active_bearer_is_local_player()
		session.HUD.update_nameplate("WIG", wigs.back().global_position, "WIG")
		whispers.global_position = wigs.back().global_position
		whispers.stream_paused = active_bearer_is_local_player()
		theme.stream_paused = not whispers.stream_paused
		
		if bearers.back() != null:
			session.HUD.modify_nameplate("WIG", "visible", false)	
		
	if whispers.get_playback_position() >= beas_mote_transition:
		whispers.seek(0)
				
	if theme.get_playback_position() < beas_mote_transition:
		theme.seek(beas_mote_transition)


func _physics_process(delta):
		
	if not multiplayer.has_multiplayer_peer():
		pass
	elif not is_multiplayer_authority():
		return		

	match State: # GAME STATE MACHINE
			
		GameState.reset:		
			pass
	
		GameState.playing:
		
			if wigs.size() == 0:
				rpc_spawn_new_wig.rpc()
				return
				
			if bearers.back() == null:
				return
				
			var bearer_name = session.get_humanoids_screenname(bearers.back())
			
			if not Scores.has(bearer_name):
				Scores[bearer_name] = delta
			
			elif Scores[bearer_name] < Goal:
				Scores[bearer_name] += delta
	
			elif wigs.size() < ceil(session.Client_Screennames.size() / 2.0):	
				bearers.back().ragdolled.disconnect(drop_wig)
				rpc_fuse_wig_to_head.rpc(wigs.back().get_path(), bearers.back().get_path())
				rpc_spawn_new_wig.rpc()
				
			else:
				bearers.back().ragdolled.disconnect(drop_wig)
				GameOver.emit()
			
		GameState.finished:			
			pass
		
		
func active_bearer_is_local_player():
	
	if bearers.back() == null:
		return false
		
	else:	
		return str(multiplayer.get_unique_id()) == bearers.back().name


func dawn_active_wig(humanoid):
	
	if not is_multiplayer_authority():
		return
		
	if not humanoid.is_in_group("humanoids"): #this node is not a humanoid
		pass
		
	elif bearers.back() != null: #this wig already has a bearer
		pass
	
	elif bearers.has(humanoid): #this guy already has a wig
		pass
		
	elif humanoid.RAGDOLLED: #this humanoid is unable to dawn the wig
		pass
		
	else:
		#bearers[active_index] = humanoid
		wigs.back().interactable.gained_interaction.disconnect(dawn_active_wig)
		humanoid.ragdolled.connect(drop_wig)
		rpc_put_wig_on_head.rpc(wigs.back().get_path(), humanoid.get_path())

		
func drop_wig(humanoid):
	
	if not is_multiplayer_authority():
		return
	elif humanoid == null:
		return
		
	if humanoid.ragdolled.is_connected(drop_wig):
		humanoid.ragdolled.disconnect(drop_wig)	
			
	var wig_index = bearers.find(humanoid)
	var bearer_velocity = bearers[wig_index].linear_velocity * 1.5
	var offset_velocity = Vector3(randi_range(-1, 1), 3, randi_range(-1, 1))
	wigs[wig_index].linear_velocity =  bearer_velocity + offset_velocity
		
	wigs[wig_index].interactable.gained_interaction.connect(dawn_active_wig)
	rpc_put_wig_on_head.rpc(wigs[wig_index].get_path(), null)


func handle_player_leaving(client_id):
	
		var humanoid = session.get_node_or_null(str(client_id))
	
		if bearers.size() == 0:
			return
		elif bearers.back() == null:
			return
			
		if humanoid == null:
			pass
		elif not bearers.has(humanoid):
			pass
		elif humanoid == bearers.back() and State == GameState.playing: #this is the active wig
			drop_wig(humanoid)
		else: #we either arent playing, or this wig is already fused - either way, destroy it
			var wig = wigs[bearers.find(humanoid)]
			rpc_destroy_wig.rpc(wig.get_path())


@rpc("call_local", "reliable")
func rpc_spawn_new_wig():
		
	for value in session.Client_Screennames.values():
		Scores[value] = 0
		
	var new_wig = wig_prefab.instantiate()
	add_child(new_wig, true)
	var random_boundaries = map_size / 2.25
	var random_position = Vector3(randi_range(-random_boundaries, random_boundaries), random_boundaries, randi_range(-random_boundaries, random_boundaries))
	new_wig.global_position = random_position
	new_wig.toggle_strobing(true)
	new_wig.radius = 0.15
	wigs.append(new_wig)
	bearers.append(null)
	new_wig.interactable.gained_interaction.connect(dawn_active_wig)
	return new_wig


@rpc("call_local", "reliable")
func rpc_destroy_wig(path_to_wig : NodePath):
	
	var wig = get_node(path_to_wig)
	
	if wig != null:
		wig.queue_free()


@rpc("call_local", "reliable")
func rpc_put_wig_on_head(path_to_wig, path_to_bearer):
	
	var wig = get_node(path_to_wig)
	
	if path_to_bearer == null:
		
		var bearer = wig_remote.get_parent()
		
		if bearer:
			session.HUD.modify_nameplate(bearer.name, "theme_override_colors/font_color", Color.WHITE)
			session.HUD.modify_nameplate(bearer.name, "theme_override_font_sizes/font_size", 16)
			bearer.remove_child(wig_remote)
			bearers[wigs.find(wig)] = null
			
		add_child(wig_remote)
		wig_remote.remote_path = ""
		wig.toggle_strobing(true)
		wig.Drop.play()
		wig.collider.disabled = false
		wig.freeze = false
		
	else:		
		var new_bearer = get_node(path_to_bearer)
		remove_child(wig_remote)
		new_bearer.find_child("*head").add_child(wig_remote)
		wig_remote.remote_path = path_to_wig
		wig_remote.position = Vector3(0, 0.2, -.025)		
		wig.toggle_strobing(false)
		wig.Dawn.play()
		wig.collider.disabled = true
		wig.freeze = true
		session.HUD.modify_nameplate(new_bearer.name, "theme_override_colors/font_color", Color.ORANGE_RED)
		session.HUD.modify_nameplate(new_bearer.name, "theme_override_font_sizes/font_size", 24)
		var wig_index = wigs.find(wig)
		bearers[wig_index] = new_bearer
		print(wigs, bearers)
	
	
@rpc("call_local", "reliable")
func rpc_fuse_wig_to_head(path_to_wig, path_to_bearer):
			
	if path_to_wig == null or path_to_bearer == null:
		return
	
	var wig = get_node(path_to_wig)
	var bearer = get_node(path_to_bearer)
	var wig_index = wigs.find(wig)
	bearers[wig_index] = bearer
	
	if wig == null or bearer == null:
		return
		
	wig_remote = RemoteTransform3D.new()
	add_child(wig_remote)
	session.HUD.modify_nameplate(bearer.name, "theme_override_colors/font_color", Color.WHITE)
	session.HUD.modify_nameplate(bearer.name, "theme_override_font_sizes/font_size", 16)
	

@rpc("call_local", "reliable")
func rpc_reset():
	
	session.HUD.remove_nameplate("WIG")
	session.HUD.find_child("Progress").visible = false		
	theme.seek(beas_mote_transition)
	
	for wig in wigs:
		wig.queue_free()
	
	wigs = []
	bearers = []
	
	if is_multiplayer_authority(): 	
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
			
		State = GameState.reset

	
@rpc("call_local", "reliable")
func rpc_play():
	
	session.HUD.set_progress_label("Installing Wig...")
	session.HUD.add_nameplate("WIG", "WIG")
	session.HUD.modify_nameplate("WIG", "theme_override_colors/font_color", Color.GREEN_YELLOW)
	session.HUD.modify_nameplate("WIG", "theme_override_font_sizes/font_size", 24)
	
	if is_multiplayer_authority(): 	
		session.HUD.set_psa.rpc("Capture the Wig!")
		rpc_spawn_new_wig.rpc()
		State = GameState.playing	
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
	
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	session.HUD.find_child("Progress").visible = false
	session.HUD.remove_nameplate("WIG")
	
	if is_multiplayer_authority(): 
		State = GameState.finished	
		
		for index in wigs.size():
			
			var bearer = bearers[index]
			var wig = wigs[index]
			
			if wig == null:
				pass
			elif bearer == null:
				rpc_destroy_wig.rpc(wig.get_path())
			else:
				rpc_fuse_wig_to_head.rpc(wig.get_path(), bearer.get_path())


func handle_player_joining(client_id) -> void:
	
	for index in range(wigs.size()):
		rpc_spawn_new_wig.rpc_id(client_id)
		var wig_path = wigs[index].get_path()
		var bearer_path = null 
		
		if index < bearers.size():
			bearer_path = null if bearers[index] == null else bearers[index].get_path()
		
		rpc_put_wig_on_head.rpc_id(client_id, wig_path, bearer_path)
		
		if State == GameState.finished or index < wigs.size()-1: #fuse wig if not active or game is finished
			rpc_fuse_wig_to_head.rpc_id(client_id, wig_path, bearer_path)		
	
	
	

		

