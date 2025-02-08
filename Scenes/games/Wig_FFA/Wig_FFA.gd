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

@export var State = GameState.reset
@export var Goal_Time = 107.34

@export var Bearer_Times = {}

@onready var wig_remote = $RemoteTransform3D
@onready var wig_ffa_hud = $HUD
@onready var whispers = $Whispers
@onready var theme = $Theme

@onready var session = get_parent()

@onready var local_player_id = str(multiplayer.get_unique_id())

var Wig : Node3D
var Bearer : Node3D

var countDown_timer = 0
var countDown_value = 0


func _ready():
	
	session.Started_Round.connect(start)
	session.Ended_Round.connect(reset)
	session.Destroying_Player_Humanoid.connect(func (node): if node == Bearer: drop_wig())
	session.humanoidSpawner.despawned.connect( func (node): if node == Bearer: 
		move_wig_remote_controller(session.get_path())
		toggle_wig_mount(false))
	
	whispers.stream_paused = false
	theme.stream_paused = true
	
	
func _process(delta):
	
	update_music()
	
	wig_ffa_hud.TableValues = Bearer_Times
	wig_ffa_hud.visible = session.State == session.SessionState.Round 
	
	if not Wig:
		Wig = get_node_or_null("Wig")	
		
	elif Bearer != null:
		session.HUD.modify_nameplate("WIG", "visible", false)
		
	else:
		session.HUD.update_nameplate("WIG", Wig.global_position, "WIG")		
		
	var local_name = session.local_screenname()
	var bearer_name = get_bearers_screenname()
	
	if Bearer_Times.has(local_name):	
		var accumulated_time = Bearer_Times[local_name]
		wig_ffa_hud.ProgressPercent = clampf(accumulated_time/Goal_Time, 0.0, 1.0)
	
	if not is_multiplayer_authority():
		return
			
	match State: # GAME STATE MACHINE
			
		GameState.reset:
			
			pass
			
		GameState.starting:	
				
			if countDown_value <= 0:
				rpc_play.rpc()
			
			elif countDown_timer > 1:
				countDown_timer = 0
				countDown_value -= 1
				session.HUD.set_psa.rpc(str(countDown_value))
			
			else:
				countDown_timer += delta
	
		GameState.playing:
		
			if not Bearer:
				pass
			
			elif not Bearer_Times.has(bearer_name):
				Bearer_Times[bearer_name] = delta
				
			elif Bearer_Times[bearer_name] >= Goal_Time:
				rpc_finish.rpc()
				session.Finished_Round(str(bearer_name))
					
			else:
				Bearer_Times[bearer_name] += delta
			
		GameState.finished:	
			
			pass
	

func update_music():
	
	if Wig == null:
		whispers.stream_paused = true
		theme.stream_paused = true
		
	else:
		whispers.global_position = Wig.global_position
		whispers.stream_paused = bearer_is_local_player()
		theme.stream_paused = not whispers.stream_paused

	if whispers.get_playback_position() >= beas_mote_transition:
		whispers.seek(0)
				
	if theme.get_playback_position() < beas_mote_transition:
		theme.seek(beas_mote_transition)


func get_bearers_screenname():
	
	if Bearer == null:
		return ''	
	elif session.Client_Screennames.has(int(str(Bearer.name))):
		return session.Client_Screennames[int(str(Bearer.name))]
		


func bearer_is_local_player():
	
	if Bearer == null:
		return false
		
	else:	
		return local_player_id == Bearer.name


func start():
	
	if is_multiplayer_authority(): 
		rpc_start.rpc()
	
	
func reset():
	
	if is_multiplayer_authority(): 
		rpc_reset.rpc()	


func dawn_wig(node):
	
	if not Wig:
		pass
		
	elif not node.is_in_group("humanoids"):
		pass
		
	elif Bearer:
		pass
		
	elif node.RAGDOLLED:
		pass
		
	else:
		Wig.interactable.gained_interaction.disconnect(dawn_wig)
		node.ragdolled.connect(drop_wig)
		
		move_wig_remote_controller.rpc(node.find_child("*head").get_path())
		toggle_wig_mount.rpc(true)
		
		set_wig_bearer.rpc(node.get_path())

		
func drop_wig():
	
	if is_multiplayer_authority():
		Wig.interactable.gained_interaction.connect(dawn_wig)
		
	move_wig_remote_controller.rpc(session.get_path())
	toggle_wig_mount.rpc(false)
	var current_position = Wig.global_position	
	Wig.global_position = current_position
	
	if Bearer != null:
		Bearer.ragdolled.disconnect(drop_wig)
		Wig.linear_velocity = Bearer.linear_velocity * 1.5 + Vector3(0, 3, 0)

	set_wig_bearer.rpc(null)
	
	
@rpc("call_local", "reliable")
func toggle_wig_mount(value):
	
	if Wig: 
		Wig.collider.disabled = value
		Wig.freeze = value


@rpc("call_local", "reliable")
func move_wig_remote_controller(path_to_new_parent):
	
	wig_remote.get_parent().remove_child(wig_remote)
	var new_parent = get_node(path_to_new_parent)
	
	if not new_parent: 
		return
		
	new_parent.add_child(wig_remote)


@rpc("call_local", "reliable")
func set_wig_bearer(path_to_new_bearer):
	
	if path_to_new_bearer == null:
		
		if Bearer:
			session.HUD.modify_nameplate(Bearer.name, "theme_override_colors/font_color", Color.WHITE)
			session.HUD.modify_nameplate(Bearer.name, "theme_override_font_sizes/font_size", 16)
			Bearer = null
			
		wig_ffa_hud.find_child("Progress").visible = false
		wig_remote.remote_path = ""
		Wig.toggle_strobing(true)
		Wig.Drop.play()
		
	else:		
		Bearer = get_node(path_to_new_bearer)
		wig_remote.remote_path = Wig.get_path()
		wig_remote.position = Vector3(0, 0.275, -.075)		
		Wig.toggle_strobing(false)
		Wig.Dawn.play()
		wig_ffa_hud.find_child("Progress").visible = local_player_id == Bearer.name
		session.HUD.modify_nameplate(Bearer.name, "theme_override_colors/font_color", Color.ORANGE_RED)
		session.HUD.modify_nameplate(Bearer.name, "theme_override_font_sizes/font_size", 24)
			

@rpc("call_local", "reliable")
func rpc_start():
	
	if is_multiplayer_authority(): 
		rpc_reset()
		countDown_value = 10
		session.HUD.set_psa.rpc(str(countDown_value))
		State = GameState.starting
	

@rpc("call_local", "reliable")
func rpc_reset():
	
	session.HUD.remove_nameplate("WIG")

	if is_multiplayer_authority(): 	
		wig_ffa_hud.find_child("Progress").visible = false
		
		if Bearer:
			drop_wig()
			Bearer = null

		if Wig:
			Wig.queue_free()
			Wig = null
		
		Bearer_Times = {}
		State = GameState.reset

	
@rpc("call_local", "reliable")
func rpc_play():
	
	session.HUD.add_nameplate("WIG", "WIG")
	session.HUD.modify_nameplate("WIG", "theme_override_colors/font_color", Color.GREEN_YELLOW)
	session.HUD.modify_nameplate("WIG", "theme_override_font_sizes/font_size", 24)
	
	if is_multiplayer_authority(): 
		Bearer_Times = {}
		Wig = wig_prefab.instantiate()
		add_child(Wig)
		Wig.global_position = Vector3(0, 20, 0)
		Wig.interactable.gained_interaction.connect(dawn_wig)
		Wig.toggle_strobing(true)
		State = GameState.playing
	
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	if is_multiplayer_authority(): 

		if Bearer:
			Bearer.ragdolled.disconnect(drop_wig)
		
		State = GameState.finished

	
	

