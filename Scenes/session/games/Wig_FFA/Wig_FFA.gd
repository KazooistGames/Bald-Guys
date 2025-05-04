extends Node3D

const wig_prefab = preload("res://Scenes/objects/wig/Wig.tscn")
const beas_mote_transition = 54.66
const beas_mote_end = 162.0

enum GameState {
	reset,
	starting,
	playing,
	finished
}

@export var map_size = 50
@export var State = GameState.reset
@export var Goal = 5 #107.34
@export var Scores = {}
@export var Total_Wigs = 2
@export var wig_remotes : Array = []

@onready var whispers = $Whispers
@onready var theme = $Theme
@onready var session = get_parent()
@onready var wig_remote = $RemoteTransform3D

#var Active_Wig : Node3D = null

var wigs : Array[Node] = []
var bearers : Array[Node] = []
var active_index = -1


func _ready():
	
	session.Started_Round.connect(start_game)
	session.Ended_Round.connect(reset_game)
	session.Destroying_Player_Humanoid.connect(
		func (humanoid): 
			if humanoid == bearers[active_index]: 
				drop_active_wig())
	
	whispers.stream_paused = false
	theme.stream_paused = true
	
	
func _process(delta):
	
	session.HUD.find_child("Progress").visible = bearer_is_local_player()

	active_index = wigs.size() - 1
	
	if active_index < 0:
		whispers.stream_paused = true
		theme.stream_paused = true
		
	else:
		whispers.global_position = wigs[active_index].global_position
		whispers.stream_paused = bearer_is_local_player()
		theme.stream_paused = not whispers.stream_paused
		session.HUD.update_nameplate("WIG", wigs[active_index].global_position, "WIG")
		
		if bearers[active_index] != null:
			session.HUD.modify_nameplate("WIG", "visible", false)	
			

	if whispers.get_playback_position() >= beas_mote_transition:
		whispers.seek(0)
				
	if theme.get_playback_position() < beas_mote_transition:
		theme.seek(beas_mote_transition)
	
	if not is_multiplayer_authority():
		return		

	
	match State: # GAME STATE MACHINE
			
		GameState.reset:		
			pass
			
		GameState.starting:				
			pass
	
		GameState.playing:
		
			if wigs.size() == 0:
				rpc_spawn_new_wig.rpc()
				return
				
			var bearer_name = session.get_humanoids_screenname(bearers[active_index])	
				
			if bearers[active_index] == null:
				pass
			
			elif Scores[bearer_name] < Goal:
				Scores[bearer_name] += delta
	
			elif wigs.size() < Total_Wigs:
				rpc_fuse_wig_to_bearer.rpc(active_index)
				rpc_spawn_new_wig.rpc()
				
			else:
				rpc_finish.rpc()
				session.Finished_Round(str(bearer_name))
			
		GameState.finished:			
			pass
		
		
func bearer_is_local_player():
	
	if active_index < 0:
		return false
		
	elif bearers[active_index] == null:
		return false
		
	else:	
		return str(multiplayer.get_unique_id()) == bearers[active_index].name


func start_game():
	
	if is_multiplayer_authority(): 
		rpc_start.rpc()
	
	
func reset_game():
	
	if is_multiplayer_authority(): 
		rpc_reset.rpc()	


func dawn_active_wig(humanoid):
	
	if not is_multiplayer_authority():
		return
	
	if active_index < 0:
		pass
		
	elif not humanoid.is_in_group("humanoids"):
		pass
		
	elif bearers[active_index] != null:
		pass
	
	elif bearers.has(humanoid):
		pass
		
	elif humanoid.RAGDOLLED:
		pass
		
	else:
		wigs[active_index].interactable.gained_interaction.disconnect(dawn_active_wig)
		humanoid.ragdolled.connect(drop_active_wig)
		bearers[active_index] = humanoid
		rpc_put_wig_on_head.rpc(wigs[active_index].get_path(), humanoid.get_path())

		
func drop_active_wig():
	
	if not is_multiplayer_authority():
		return
		
	wigs[active_index].interactable.gained_interaction.connect(dawn_active_wig)

	if bearers[active_index] == null:
		pass
		
	elif bearers[active_index].ragdolled.is_connected(drop_active_wig):
		bearers[active_index].ragdolled.disconnect(drop_active_wig)
		wigs[active_index].linear_velocity = bearers[active_index].linear_velocity * 1.5 + Vector3(0, 3, 0)

	rpc_put_wig_on_head.rpc(wigs[active_index].get_path(), null)
	

@rpc("call_local", "reliable")
func rpc_spawn_new_wig():
		
	for value in session.Client_Screennames.values():
		Scores[value] = 0
		
	var new_wig = wig_prefab.instantiate()
	add_child(new_wig, true)
	new_wig.global_position = Vector3(0, map_size / 2.0 , 0)
	new_wig.toggle_strobing(true)
	new_wig.radius = 0.15
	wigs.append(new_wig)
	bearers.append(null)
	new_wig.interactable.gained_interaction.connect(dawn_active_wig)
	return new_wig


@rpc("call_local", "reliable")
func rpc_put_wig_on_head(path_to_wig, path_to_bearer):
	
	var wig = get_node(path_to_wig)
	
	if path_to_bearer == null:
		
		var bearer = wig_remote.get_parent()
		
		if bearer:
			session.HUD.modify_nameplate(bearers[active_index].name, "theme_override_colors/font_color", Color.WHITE)
			session.HUD.modify_nameplate(bearers[active_index].name, "theme_override_font_sizes/font_size", 16)
			bearer.remove_child(wig_remote)
			bearer = null
			
		add_child(wig_remote)
		session.HUD.find_child("Progress").visible = false
		wig_remote.remote_path = ""
		wig.toggle_strobing(true)
		wig.Drop.play()
		wig.collider.disabled = false
		wig.freeze = false
		
	else:		
		var new_bearer = get_node(path_to_bearer)
		remove_child(wig_remote)
		new_bearer.find_child("*head").add_child(wig_remote)
		wig_remote.remote_path = wigs[active_index].get_path()
		wig_remote.position = Vector3(0, 0.275, -.075)		
		wig.toggle_strobing(false)
		wig.Dawn.play()
		session.HUD.find_child("Progress").visible = bearer_is_local_player()
		session.HUD.modify_nameplate(bearers[active_index].name, "theme_override_colors/font_color", Color.ORANGE_RED)
		session.HUD.modify_nameplate(bearers[active_index].name, "theme_override_font_sizes/font_size", 24)
	
	
@rpc("call_local", "reliable")
func rpc_fuse_wig_to_bearer(index : int):
	
	var bearer = bearers[index]
	
	if bearer == null:
		return
		
	bearer.ragdolled.disconnect(drop_active_wig)
	session.HUD.modify_nameplate(bearers[active_index].name, "theme_override_colors/font_color", Color.WHITE)
	session.HUD.modify_nameplate(bearers[active_index].name, "theme_override_font_sizes/font_size", 16)
			

@rpc("call_local", "reliable")
func rpc_start():
	
	if is_multiplayer_authority(): 
		rpc_reset()
		State = GameState.starting
	

@rpc("call_local", "reliable")
func rpc_reset():
	
	session.HUD.remove_nameplate("WIG")
	theme.seek(beas_mote_transition)
	
	if is_multiplayer_authority(): 	
		session.HUD.find_child("Progress").visible = false
		
		if active_index < 0:
			pass
		elif bearers[active_index]:
			drop_active_wig()
			bearers[active_index] = null

		for wig in wigs:
			wig.queue_free()
		
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
		rpc_spawn_new_wig.rpc()
		State = GameState.playing	
		
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	if is_multiplayer_authority(): 

		if active_index < 0:
			pass
		elif bearers[active_index]:
			bearers[active_index].ragdolled.disconnect(drop_active_wig)
			
		State = GameState.finished	
	
	

	

		

