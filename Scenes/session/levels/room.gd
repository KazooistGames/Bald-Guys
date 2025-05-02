extends Node3D

@export var Max_Size : float = 100.0
@export var Current_Size : float = 0.0
@export var Next_Size : float = 25.0
@export var Last_Size : float = 25.0
@export var Resizing : bool = false

@onready var floor : Node3D = $floor
@onready var ceiling : Node3D = $ceiling
@onready var wall : Node3D = $wall
@onready var wall2 : Node3D = $wall2
@onready var wall3 : Node3D = $wall3
@onready var wall4 : Node3D = $wall4
@onready var spawns : Array[Node] = $spawns.get_children()
@onready var wall_mesh : PlaneMesh = preload("res://Scenes/geometry_static/Wall/wall_mesh.tres")
@onready var wall_collider : BoxShape3D = preload("res://Scenes/geometry_static/Wall/wall_collider.tres")
@onready var resize_tween : Tween =  create_tween()
@onready var synchronizer : MultiplayerSynchronizer = $MultiplayerSynchronizer

var resize_period : float = 3.0
var resize_timer : float = 0.0

signal finished_resizing


func _ready() -> void:
	
	adjust_room_to_size(Next_Size)	
	wall_collider.size = Vector3(Max_Size, 1.0, Max_Size)
	
	if not is_multiplayer_authority():
		synchronizer.delta_synchronized.connect(func() : adjust_room_to_size(Current_Size))

func _process(delta:float) -> void:
	
	if not is_multiplayer_authority():
		return
		
	if not Resizing:
		pass
	
	elif Current_Size == Next_Size or resize_timer >= resize_period:
		Resizing = false
		Last_Size = Next_Size
		resize_timer = 0.0
		finished_resizing.emit()
		
	else:
		resize_timer += delta
		var tween_range : float = Next_Size - Last_Size
		var desired_size = Tween.interpolate_value(Last_Size, tween_range, resize_timer, resize_period, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
		adjust_room_to_size(desired_size)
	
	
@rpc("call_local", "reliable")
func request_new_size(new_size : float) -> void:
	
	if new_size <= 0:
		return
		
	elif new_size == Next_Size:
		return
		
	elif new_size > Max_Size:
		new_size = Max_Size
	
	Resizing = true
	Next_Size = new_size
	print("resizing room to ", Next_Size)
		
		
func adjust_room_to_size(desired_size : float) -> void:

	ceiling.position.y = desired_size
	wall.position = Vector3(-desired_size/2.0, desired_size/2.0, 0.0)
	wall2.position = Vector3(desired_size/2.0, desired_size/2.0, 0.0)
	wall3.position = Vector3(0.0, desired_size/2.0, -desired_size/2.0)
	wall4.position = Vector3(0.0, desired_size/2.0, desired_size/2.0)
	wall_mesh.size = Vector2.ONE * desired_size
	
	for index in range(spawns.size()):
		var spawn : Node3D = spawns[index]
		var radius : float = desired_size * 0.4
		var phase = (2.0 * PI) / (index + 1.0)
		spawn.position = Vector3(cos(phase), 1.0, sin(phase)) * radius
		
	Current_Size = desired_size
	
