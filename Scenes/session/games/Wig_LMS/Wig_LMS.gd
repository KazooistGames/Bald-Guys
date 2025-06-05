extends Node3D

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
@onready var synchronizer = $MultiplayerSynchronizer

var wig_radii : Vector2 = Vector2(0.15, 0.45)
var wig_start_offset = Vector3(0, 0.2, -0.025)
var wig_end_offset = Vector3(0, 0.5, -0.075)


signal GameOver


func _ready():
	pass

func _process(delta):
	pass
	
	
func _physics_process(delta):
		
	if not multiplayer.has_multiplayer_peer():
		pass
	elif not is_multiplayer_authority():
		return	
	
	match State: # GAME STATE MACHINE
			
		GameState.reset:
			pass	
	
		GameState.playing:
			
			var surviving_players : Array = session.bearers.filter(player_is_alive)
			
			if surviving_players.size() == 1:
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
		session.HUD.set_psa.rpc("Grow your Hair!")
		State = GameState.playing
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
			
		for bearer in session.bearers:
			
			if bearer != null: #TODO: add listener to ragdoll to chip away health
				pass
				
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	session.HUD.remove_nameplate("HILL")
	
	if is_multiplayer_authority(): 
		session.HUD.find_child("Progress").visible = false
		State = GameState.finished
		session.HUD.remove_nameplate("HILL")
		
		for bearer in session.bearers:
		
			if bearer != null: #TODO: remove listener to ragdoll to chip away health
				pass


func player_is_alive(player):
	
	var screenname : String = session.Client_Screennames[int(player.name)]
	return Scores[screenname] > 0


func handle_player_joining(client_id) -> void:

	pass
	

func handle_player_leaving(client_id) -> void:
	
	pass
