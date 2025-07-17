extends Game

const damage_scalar = 25


var wig_radii : Vector2 = Vector2(0.15, 0.45)
var wig_start_offset = Vector3(0, 0.2, -0.025)
var wig_end_offset = Vector3(0, 0.5, -0.075)


func _ready():
	
	Players = 2
	Goal = 100
	

func _process(_delta):
	
	if State == GameState.playing:
		session.HUD.find_child("Progress").visible = humanoid_is_alive(session.local_humanoid())
	
	
func _physics_process(_delta):
		
	if not multiplayer.has_multiplayer_peer():
		pass
	elif not is_multiplayer_authority():
		return	
	
	match State: # GAME STATE MACHINE
			
		GameState.reset:
			pass	
	
		GameState.playing:	
			
			if session.Humanoids.size() == 0:
				GameOver.emit()
				return
					
			var surviving_players : Array = session.Humanoids.filter(humanoid_is_alive)

			if surviving_players.size() <= 1 and surviving_players.size() != session.Humanoids.size():
				GameOver.emit()
		
		GameState.finished:			
			pass

		
@rpc("call_local", "reliable")
func rpc_reset():	
	
	if is_multiplayer_authority(): 
		Scores = {}
		State = GameState.reset
		
		for value in session.Client_Screennames.values():
			Scores[value] = 100
			
	
@rpc("call_local", "reliable")
func rpc_play():
	
	State = GameState.playing
	session.HUD.set_progress_label("Follicle Integrity:")
	
	if is_multiplayer_authority(): 
		
		session.HUD.set_psa.rpc("Shave your foes!", 3)				
		for humanoid : RigidBody3D in session.Humanoids:

			session.wig_manager.give_wig(humanoid, 0.45)
			humanoid.ragdolled.connect(damage_player)
			var screenname : String = session.get_humanoids_screenname(humanoid)
			Scores[screenname] = 100
			humanoid.recover_disabled = false
				
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	session.HUD.find_child("Progress").visible = false
	
	if is_multiplayer_authority(): 

		State = GameState.finished
		
		for humanoid in session.Humanoids:
			if humanoid != null:
				humanoid.ragdolled.disconnect(damage_player)
				humanoid.recover_disabled = false


func humanoid_is_alive(humanoid):
	
	if humanoid == null:
		return false
		
	return session.wig_manager.get_wig(humanoid) != null


func damage_player(player):
	
	var screenname : String = session.Client_Screennames[int(str(player.name))]
	Scores[screenname] -= damage_scalar
	
	if Scores[screenname] < 0:
		player.recover_disabled = true
	
	Scores[screenname] = clampf(Scores[screenname], 0, 100)
	
	if Scores[screenname] <= 0:
		session.wig_manager.loosen_wig(player)

	
func handle_player_joining(client_id):
	
	if State != GameState.playing:
		return
	
	var new_players_humanoid = session.get_node_or_null(str(client_id))
	print('giving wig to ', new_players_humanoid)
	session.wig_manager.give_wig(new_players_humanoid, 0.45)

	
