extends Node2D
class_name Agent


@export_category("AIController")
@onready var controller : Controller = $AIController2D
@export var control_mode: Controller.ControlModes

@export_category("Config")
@export var can_move : bool = true
@export var can_vibrate : bool = false
@export var color : Color = Color.BLUE
@export var radius : float = 50
@export var movement_speed : float = 100.0
@export var linear_damping : float = 10.0

@export_category("Rewards")
@export var enable_sync_reward : bool = false
@export var enable_mirroring_reward : bool = false
@export var enable_cloning_reward : bool = false
@export var enable_total_dist_reward : bool = false
@export var enable_average_jerk_reward : bool = false
@export var enable_jerk_reward : bool = false
@export var no_collision_reward : float = 0.0
@export var agent_collision_reward : float = 0.0
@export var wall_collision_reward : float = 0.0

var velocity : Vector2 = Vector2.ZERO
## The agents perceived velocity.
var visual_velocity : Vector2 = Vector2.ZERO
var max_velocity : Vector2 = Vector2(15, 15) ## !!! MAGIC NUMBERS.
var colliding_with_wall : bool = false
var colliding_with_agent : bool = false
var positions : Array[Vector2] = []
@onready var last_position : Vector2 = self.global_position
@onready var last_visual_velocity : Vector2 = Vector2.ZERO
var velocities : Array[Vector2] = []
var dt : float = 0.0
var pulse_speed : float = 30.0
var collision_loss : float = 1.005
var walls : Dictionary = {}


func _ready():
	controller.init(self)
	controller.control_mode = control_mode
	controller.policy_name = self.name

