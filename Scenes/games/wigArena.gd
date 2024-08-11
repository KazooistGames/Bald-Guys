extends Node3D


const Ball_Prefab = preload("res://Scenes/objects/ball/Ball.tscn")


@export var Commissioned = false

@export var CountdownTimer = 5


var countdownTimer = 0

var Players = []


const GameState = {
	Setup = 0,
	Countdown = 1,
	Playing = 2,
}


@export var State = GameState.Setup


func _ready():
	pass


func _process(delta):
	
	if not Commissioned:
		Commissioned = true
		
	elif not is_multiplayer_authority(): 
		return
		
	Players = get_tree().get_nodes_in_group("humanoids")
	
	match State:
		
		GameState.Setup:
			pass
				
		GameState.Countdown:
			if CountdownTimer <= 0:
				State = GameState.Playing
				
			elif countdownTimer >= 1:
				countdownTimer = 0
				CountdownTimer -= 1

			else:
				countdownTimer += delta
				
		GameState.Playing:
			pass


func peer_is_valid(peerID):
	
	for player in Players:
		
		if player.get_multiplayer_authority() == peerID:
			return true
			
	return false


func set_spawn_position(object):
	
	if not object: 
		return
	
	elif not object.is_multiplayer_authority(): 
		return
	
	var available_spawns = get_tree().get_nodes_in_group("spawns")
	
	if not available_spawns.is_empty():
		object.position = available_spawns.pick_random().transform.origin


func node_is_player(node):
	
	var player = Players.find(node)
	return player >= 0	


@rpc("authority", "call_local")
func set_score(playerName, score):
	
	pass

