extends Node3D

const damage_scalar = 25

enum GameState {
	reset,
	playing,
	finished
}

@export var State = GameState.reset
@export var map_size : float = 50
@export var Scores : Dictionary = {}
@export var Goal : float = 100

@onready var session = get_parent()

var wig_radii : Vector2 = Vector2(0.15, 0.45)
var wig_start_offset = Vector3(0, 0.2, -0.025)
var wig_end_offset = Vector3(0, 0.5, -0.075)


signal GameOver


func _ready():
	pass

func _process(_delta):
	
	if State == GameState.playing:
		session.HUD.find_child("Progress").visible = player_is_alive(session.local_humanoid())
	
	
func _physics_process(_delta):
		
	if not multiplayer.has_multiplayer_peer():
		pass
	elif not is_multiplayer_authority():
		return	
	
	match State: # GAME STATE MACHINE
			
		GameState.reset:
			pass	
	
		GameState.playing:	
			
			if session.bearers.size() == 0:
				GameOver.emit()
				return
					
			var surviving_players : Array = session.bearers.filter(player_is_alive)

			if surviving_players.size() <= 1:
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
	
	if is_multiplayer_authority(): 
		session.HUD.set_psa.rpc("Shave your foes!", 3)
		State = GameState.playing
		
		for value in session.Client_Screennames.values():
			Scores[value] = -1
			
		for bearer in session.bearers:
			
			if bearer != null: #TODO: add listener to ragdoll to chip away health
				bearer.ragdolled.connect(damage_player)
				var screenname : String = session.Client_Screennames[int(str(bearer.name))]
				Scores[screenname] = 100
	
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	session.HUD.remove_nameplate("HILL")
	
	if is_multiplayer_authority(): 
		session.HUD.find_child("Progress").visible = false
		State = GameState.finished
		session.HUD.remove_nameplate("HILL")
		
		for bearer in session.bearers:
		
			if bearer != null: #TODO: remove listener to ragdoll to chip away health
				bearer.ragdolled.disconnect(damage_player)


func player_is_alive(player):
	
	if player == null:
		return false
		
	var screenname : String = session.Client_Screennames[int(str(player.name))]
	return Scores[screenname] > 0


func damage_player(player):
	
	var screenname : String = session.Client_Screennames[int(str(player.name))]
	Scores[screenname] -= damage_scalar


func handle_player_joining(client_id) -> void:
	
	pass


func handle_player_leaving(client_id) -> void:
	
	pass
	
