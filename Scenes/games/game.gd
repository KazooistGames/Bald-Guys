class_name Game extends Node

@onready var session : Session = get_parent()

enum GameState {
	reset,
	playing,
	finished
}

var State = GameState.reset
var map_size = 50.0
var Goal := 0.0 #107.34
var Scores := {}
var Players := 2

signal GameOver


@rpc("call_local", "reliable")
func rpc_reset():
	
	pass
	
	
@rpc("call_local", "reliable")
func rpc_play():
	
	pass
	
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	pass


func handle_player_joining(_client_id) -> void:
	
	pass	
	
	
func handle_player_leaving(_client_id) -> void:	
	
	pass

