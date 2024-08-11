extends Node3D

const Ball_Prefab = preload("res://Scenes/objects/ball/Ball.tscn")

@export var PlayerTeamAssignments = {1:-1}

@export var Countdown = 5
var countdownTimer = 0

var Players = []
var TeamStages = []

var TeamScores = []

const GameState = {
	Setup = 0,
	Playing = 1,
}
@export var State = GameState.Setup

@export var BALL : Node3D

func _ready():
	TeamStages = get_tree().get_nodes_in_group("stages")
	for teamStage in TeamStages:
		var index = TeamStages.find(teamStage)
		TeamScores.append(0)
		match index:
			0:
				teamStage.set_color(Color.PALE_VIOLET_RED)
			1:
				teamStage.set_color(Color.SKY_BLUE)

func _process(delta):
	if not is_multiplayer_authority(): return
	Players = get_tree().get_nodes_in_group("humanoids")
	match State:
		GameState.Setup:
			process_setup_state(delta)
		GameState.Playing:
			process_playing_state(delta)

func process_setup_state(delta):
	attempt_team_assignments()
	if !all_humanoids_have_team():
		Countdown = 5
	elif Countdown <= 0:
		State = GameState.Playing
	elif countdownTimer >= 1:
		countdownTimer = 0
		Countdown -= 1
	else:
		countdownTimer += delta

func process_playing_state(delta):
	if not all_humanoids_have_team():
		State = GameState.Setup
	else:
		if not BALL:
			BALL = Ball_Prefab.instantiate()
			get_parent().add_child(BALL)
			set_spawn_position(BALL)
			BALL.body_entered.connect(handle_ball_impact)

func all_humanoids_have_team():
	if len(Players) == 0: return false
	for player in Players:
		if not player_has_team(player):
			return false
	return true

func player_has_team(player):
	var peer = player.get_multiplayer_authority()
	if PlayerTeamAssignments.get(peer) == null:
		return false 
	elif PlayerTeamAssignments[peer] < 0:
		return false
	else:
		return true

func attempt_team_assignments():
	var invalid_player_keys = []
	for assignment in PlayerTeamAssignments:
		PlayerTeamAssignments[assignment] = -1
		if !peer_is_valid(assignment):
			invalid_player_keys.append(assignment)
	for stage in TeamStages:
		assign_stage_players(stage)
	for key in invalid_player_keys:
		PlayerTeamAssignments.erase(key)

func peer_is_valid(peerID):
	for player in Players:
		if player.get_multiplayer_authority() == peerID:
			return true
	return false

func assign_stage_players(stage):
	var stageIndex = TeamStages.find(stage)
	for onboard_player in stage.humanoids_onboard:
		var peer = onboard_player.get_multiplayer_authority()
		if PlayerTeamAssignments.get(peer) == null:
			assign_player_to_team.rpc(peer, stageIndex)
		elif PlayerTeamAssignments[peer] != stageIndex:
			assign_player_to_team.rpc(peer, stageIndex)

func set_spawn_position(object):
	if not object: return
	elif not object.is_multiplayer_authority(): return
	var available_spawns = get_tree().get_nodes_in_group("spawns")
	if not available_spawns.is_empty():
		object.position = available_spawns.pick_random().transform.origin

func handle_ball_impact(newCollidingObject):
	var collidingNodes = BALL.get_colliding_bodies()
	for node in collidingNodes:
		if node_is_team_stage(node):
			handle_scoring_event(node)
		elif node_is_player(node):
			BALL.LastTeamTouch = PlayerTeamAssignments[node.get_multiplayer_authority()]
	
func node_is_player(node):
	var player = Players.find(node)
	return player >= 0	

func node_is_team_stage(node):
	var stage = TeamStages.find(node)
	return stage >= 0

func handle_scoring_event(stageNode):
	print(stageNode)
	var teamIndex = TeamStages.find(stageNode)
	if BALL.LastTeamTouch < 0:
		return
	elif BALL.LastTeamTouch == teamIndex:	
		TeamScores[teamIndex] -= 1
		BALL.queue_free()
	else:
		TeamScores[teamIndex] += 1
		BALL.queue_free()
	print("Ball hit team " + str(teamIndex) + " by team " + str(BALL.LastTeamTouch))

@rpc("authority", "call_local")
func set_score(playerName, score):
	pass

@rpc("authority", "call_local")
func assign_player_to_team(peer, team):
	PlayerTeamAssignments[peer] = team
