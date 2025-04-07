extends Node3D

@export var Next_Size : float = 25.0
@export var Last_Size : float = 25.0
@export var Current_Size : float = 25.0
@export var Resizing : bool = false

@onready var floor : Node3D = $floor
@onready var ceiling : Node3D = $ceiling
@onready var wall : Node3D = $wall
@onready var wall2 : Node3D = $wall2
@onready var wall3 : Node3D = $wall3
@onready var wall4 : Node3D = $wall4

@onready var spawns : Array[Node] = $spawns.get_children()

@onready var wall_mesh = preload("res://Scenes/geometry_static/Wall/wall_mesh.tres")
@onready var wall_collider = preload("res://Scenes/geometry_static/Wall/wall_collider.tres")

var resize_tween : Tween
var resize_period : float = 3.0
var resize_timer : float = 0.0


func _ready() -> void:
	
	resize_tween = create_tween()
	adjust_room_to_size(Next_Size)
	

func _process(delta:float) -> void:
	
	if Current_Size == Next_Size or resize_timer >= resize_period:
		Resizing = false
		Last_Size = Next_Size
		resize_timer = 0.0
		
	else:
		resize_timer += delta
		var range : float = Next_Size - Last_Size
		var desired_size = resize_tween.interpolate_value(Last_Size, range, resize_timer, resize_period, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
		adjust_room_to_size(desired_size)
	
	
func request_new_size(new_size : float) -> void:
	
	if new_size > 0 and new_size != Next_Size:
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
	wall_collider.size = Vector3(desired_size, 1.0, desired_size)
	
	for index in range(spawns.size()):
		var spawn : Node3D = spawns[index]
		var radius : float = desired_size * 0.4
		var phase = (2.0 * PI) / (index + 1.0)
		spawn.position = Vector3(cos(phase), 1.0, sin(phase)) * radius
		
	Current_Size = desired_size
	
