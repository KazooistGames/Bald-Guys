class_name Game extends Node

enum Classification{
	Common,
	Uncommon,
	Rare,
	Epic,
	Legendary
}
enum GameState {
	reset,
	playing,
	finished
}


const RarityColors : Dictionary = {
	Classification.Common : Color.GHOST_WHITE,
	Classification.Uncommon : Color.LIME_GREEN,
	Classification.Rare : Color.MEDIUM_BLUE,
	Classification.Epic : Color.WEB_PURPLE,
	Classification.Legendary : Color.GOLD
}

const RarityParts : Dictionary = {
	Classification.Common : 500,
	Classification.Uncommon : 250,
	Classification.Rare : 125,
	Classification.Epic : 50,
	Classification.Legendary : 10
}


@onready var session : Session = get_parent()

@export var classification : Classification = Classification.Common
@export var Players := 2
@export var Title : String = ''
@export var Goal := 0.0

var Scores := {}
var State = GameState.reset
var map_size = 50.0


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


func rarity_color() -> Color:
	
	var return_color : Color = RarityColors[classification]
	return_color.a = 0.75
	
	return return_color
	
func rarity_parts() -> int:
	
	return RarityParts[classification]
