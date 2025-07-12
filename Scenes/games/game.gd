class_name Game extends Node


enum GameState {
	reset,
	playing,
	finished
}

@export var State = GameState.reset

var map_size = 50
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


func handle_player_joining(client_id) -> void:
	
	pass	
	
	
func handle_player_leaving(client_id) -> void:	
	
	pass
