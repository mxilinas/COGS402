extends Node2D


## Type for wall collisions.
enum Wall { LEFT, RIGHT, TOP, BOTTOM }

## Elapsed steps for the current episode.
var episode_steps : int = 0

## Elapsed time since experiment start.
var dt : float = 0.0

## The number of iterations performed for physics constraints.
@export var collision_accuracy : int = 10

## The number of steps in a single episode.
@export var episode_length : int = 32

## Whether to visualize individual phase angles and motion paths.
@export var debug : bool = false

## A ColorRect that defines the interaction area.
@onready var arena : ColorRect = $ColorRect
@onready var info_label : Label = $ScrollContainer/Info

@onready var arena_bounds : Rect2 = arena.get_rect()
@onready var max_possible_position : Vector2 = Vector2(
	abs(arena_bounds.position.x + arena_bounds.size.x),
	abs(arena_bounds.position.y + arena_bounds.size.y),
)


func _ready():
	var args = parse_args()
	var config = load_config(args)
	if config != null:
		config_arena(config)
	Globals.agents = get_agents()
	for a in Globals.agents:
		if config != null:
			config_agent(a, config, args)
		a.walls = get_walls(a)
		reset_trajectories(a)


func _draw():
	for a in Globals.agents:
		draw_agent(a)
		if debug:
			draw_theta(a)
			draw_tradjectories(a)


func _physics_process(delta):
	if debug:
		update_info()

	dt += delta

	for a in Globals.agents:
		apply_input_velocity(a)
		damp_velocity(a)
		update_position(a, delta)

	for a in Globals.agents:
		update_collision_info(a)
	
	for a in Globals.agents:
		apply_collision_rewards(a)
		vibrate(a)

	for a in Globals.agents:
		constrain(a)

	for a in Globals.agents:
		update_visual_velocity(a)
		apply_mirroring_reward(a)
		apply_jerk_reward(a)
		update_trajectories(a)

	episode_steps += 1
	queue_redraw()

	if episode_steps == episode_length:

		for a in Globals.agents:
			apply_sync_reward(a)
			apply_average_jerk_reward(a)
			apply_total_dist_reward(a)

		for a in Globals.agents:
			reset(a)
			reset_trajectories(a)

		episode_steps = 0


## Return a list of all the agents in the environment.
func get_agents() -> Array[Agent]:
	var agents : Array[Agent] = []
	var children = get_children()
	for child in children:
		if child is Agent:
			agents.append(child)
	return agents


## Update an agent's velocity according to user input.
func apply_input_velocity(a : Agent) -> void:
	var input_velocity : Vector2 = Vector2.ZERO

	if a.controller.heuristic == "human" && a.can_move:
		var x_input = Input.get_axis("left", "right")
		var y_input = Input.get_axis("up", "down")
		input_velocity = Vector2(x_input, y_input)
	else:
		input_velocity = a.controller.move_action

	a.velocity += input_velocity * a.movement_speed


## Apply linear damping to an agent's velocity.
func damp_velocity(a : Agent) -> void:
	a.velocity -= a.velocity / a.linear_damping


## Update an agent's position by its velocity.
func update_position(a : Agent, delta : float) -> void:
	a.last_position = a.global_position
	a.position += a.velocity * delta


## Collide with another agent.
func collide_with_agent(a0 : Agent, a1 : Agent) -> void:
	var dir = a0.position.direction_to(a1.position)
	var dist : float = a0.position.distance_to(a1.position)
	var threshold = a0.radius + a1.radius
	if dist < threshold:
		var overlap = threshold - dist
		a0.position -= dir * (overlap / 2.0)
		a1.position += dir * (overlap / 2.0)


## Collide with the walls of the arena.
func collide_with_walls(a : Agent) -> void:
	var collisions = get_wall_collisions(a)
	for collision in collisions:
		if collision == Wall.LEFT:
			a.position.x = a.walls["left"]
		if collision == Wall.RIGHT:
			a.position.x = a.walls["right"]
		if collision == Wall.TOP:
			a.position.y = a.walls["top"]
		if collision == Wall.BOTTOM:
			a.position.y = a.walls["bottom"]


## Draw an agent on the screen.
func draw_agent(a : Agent) -> void:
	draw_circle(a.position, a.radius, a.color)


## Collide with all other agents in the scene.
func collide_with_agents(a0 : Agent) -> void:
	for a1 in Globals.agents:
		if a1 == a0:
			continue
		collide_with_agent(a0, a1)


## Compute the synchronicity between two agents.
func synchronicity(a0 : Agent, a1 : Agent) -> float:
	var a0_thetas = compute_thetas(a0)
	var a1_thetas = compute_thetas(a1)

	var relatives = []
	for i in range(len(a0_thetas)):
		relatives.append(a1_thetas[i] - a0_thetas[i])

	var complex_sum : Vector2 = Vector2.ZERO
	for relative in relatives:
		complex_sum += Vector2(
			cos(relative),
			sin(relative)
			)

	complex_sum /= len(relatives)
	var reward = complex_sum.length()
	return reward


## Compute the individual phase angle of an agent.
func theta(p : Vector2, v : Vector2) -> float:
	var qoutient = v / -p
	var t = atan2(qoutient.y, qoutient.x)
	return 0.0 if is_nan(t) else t


## Normalize an array by a largest observed value.
func normalize_array(arr : Array, max_obs: float) -> Array:
	if max_obs == 0: return arr
	for i in range(len(arr)):
		arr[i] /= max_obs
	return arr


func compute_thetas(a : Agent) -> Array[float]:
	var thetas : Array[float] = []
	var max_vel = longest_length(a.velocities)
	var max_pos = longest_length(a.positions)
	var norm_positions = normalize_array(a.positions, max_vel) 
	var norm_velocities = normalize_array(a.velocities, max_pos) 
	for i in range(len(norm_positions)):
		thetas.append(theta(norm_positions[i], norm_velocities[i]))
	return thetas


## Draw an agent's individual phase in the center of the arena.
func draw_theta(a : Agent):
	var t = theta(
		a.global_position / max_possible_position.length(),
		a.visual_velocity / a.max_velocity.length()
	)
	var dir = Vector2(-cos(t), -sin(t))
	var center = Vector2(
		arena.position.x + arena.size.x / 2,
		arena.position.y + arena.size.y / 2,
		)
	draw_line(center, center + dir * 100, a.color, 5)


## Apply a reward to an agent based on its synchronicity with other agents.
func apply_sync_reward(a : Agent) -> void:
	for a1 in Globals.agents:
		if a == a1:
			continue
		if a.enable_sync_reward:
			var reward = synchronicity(a, a1)
			a.controller.reward += reward


## Return the gradient of an array.
## Interior points are calculated using central differences while edges are
## calculated using forward and backward difference respectively.
func gradient(arr : Array[Vector2]) -> Array[Vector2]:
	if len(arr) <= 1:
		return arr
	var grad : Array[Vector2] = []
	grad.append(arr[1] - arr[0])
	for i in range(1, len(arr) - 1):
		grad.append((arr[i + 1] - arr[i - 1]) / 2.0)
	grad.append(arr[-1] - arr[-2])
	return grad


## Returns the length of the longest vector in an array.
func longest_length(vectors : Array[Vector2]) -> float:
	var longest : float = 0.0
	for v in vectors:
		var length = v.length()
		if length > longest:
			longest = length
	return longest


## Update an agent's position and velocity tradjectories.
func update_trajectories(a : Agent) -> void:
	a.positions[episode_steps] = a.global_position
	a.velocities[episode_steps] = a.visual_velocity


## Reset an agent's position and velocity trajectories.
func reset_trajectories(a : Agent) -> void:
	a.positions.resize(episode_length)
	a.positions.fill(Vector2.ZERO)
	a.velocities.resize(episode_length)
	a.velocities.fill(Vector2.ZERO)


## Reset an agent's AIController and reset trajectories.
func reset(a : Agent) -> void:
	a.controller.reset()
	a.controller.done = true


## Apply a reward to an agent based on its degree of mirror with other agents.
func apply_mirroring_reward(a : Agent) -> void:
	if a.enable_mirroring_reward or a.enable_cloning_reward:
		var t0 = theta(
			a.global_position / max_possible_position,
			a.visual_velocity / a.max_velocity.length()
			)
		for a1 in Globals.agents:
			if a == a1:
				continue
			var t1 = theta(
				a1.global_position / max_possible_position,
				a1.visual_velocity / a.max_velocity.length(),
				)
			var dist = Vector2(-cos(t0), -sin(t0)).dot(
				Vector2(-cos(t1), -sin(t1)))
			var reward = clamp(dist, -1, 1)
			if a.enable_cloning_reward:
				reward *= -1
			a.controller.reward += reward


func draw_tradjectories(a : Agent):
	for i in range(len(a.positions)):
		draw_line(a.positions[i], a.positions[i] + a.velocities[i], Color.RED)


## Return an array of an agent's wall collisions.
func get_wall_collisions(a : Agent) -> Array[Wall]:
	var collisions : Array[Wall] = []
	if a.position.x < a.walls["left"]:
		collisions.append(Wall.LEFT)
	if a.position.x > a.walls["right"]:
		collisions.append(Wall.RIGHT)
	if a.position.y < a.walls["top"]:
		collisions.append(Wall.TOP)
	if a.position.y > a.walls["bottom"]:
		collisions.append(Wall.BOTTOM)
	return collisions


## Return a dictionary of the bounds for a given agent based on its radius.
func get_walls(a : Agent) -> Dictionary:
	return {
		"left" : arena_bounds.position.x + a.radius,
		"right" : arena_bounds.position.x + arena_bounds.size.x - a.radius,
		"top" : arena_bounds.position.y + a.radius,
		"bottom" : arena_bounds.position.y + arena_bounds.size.y - a.radius,
		}


## Return true if an agent is colliding with another agent.
func update_collision_info(a : Agent):
	update_wall_collisions(a)
	check_for_agent_collisions(a)


func vibrate(a : Agent) -> void:
	if a.can_vibrate:
		var speed = a.visual_velocity.length() / a.max_velocity.length()
		if a.colliding_with_agent:
			var strength = sin(dt * a.pulse_speed)
			strength = (strength + 1.0) / 2.0
			strength = 0.0 if strength > 0.5 else 1.0
			Input.start_joy_vibration(0, 0.0, strength, 0.1)
		elif a.colliding_with_wall:
			Input.start_joy_vibration(0, 0.0, speed, 0.1)
		else:
			Input.start_joy_vibration(0, speed, 0.0, 0.1)


## Constrain an agent's position.
func constrain(a : Agent):
	for i in range(collision_accuracy):
		collide_with_agents(a)
		collide_with_walls(a)


## Update the agent's colliding_with_wall flag.
func update_wall_collisions(a : Agent) -> void:
	if get_wall_collisions(a).is_empty():
		a.colliding_with_wall = false
	else:
		a.colliding_with_wall = true


## Update an agent's agent collision flag.
func check_for_agent_collisions(a0 : Agent) -> void:
	for a1 in Globals.agents:
		if a1 == a0:
			continue
		var dist = a0.position.distance_to(a1.position)
		var threshold = a0.radius + a1.radius
		if dist <= threshold:
			a0.colliding_with_agent = true
			a1.colliding_with_agent = true
			return
	a0.colliding_with_agent = false


## Add enabled rewards to agent's AIController.
func apply_collision_rewards(a : Agent) -> void:
	if a.colliding_with_wall:
		a.controller.reward += a.wall_collision_reward
	if a.colliding_with_agent:
		a.controller.reward += a.agent_collision_reward
	else:
		a.controller.reward += a.no_collision_reward


## Apply a reward based on this agent's movement jerkiness.
## Not normalized!
## Ensure to use normalize rewards in algo config.
func apply_jerk_reward(a : Agent) -> void:
	if not a.enable_jerk_reward:
		return
	var reward = (a.last_visual_velocity - a.visual_velocity).length()
	a.controller.reward += reward


## Apply a reward based on this agent's movement jerkiness throughout an ep.
## Not normalized!
## Ensure to use normalize rewards in algo config.
func apply_average_jerk_reward(a : Agent) -> void:
	if not a.enable_average_jerk_reward:
		return
	var total = 0.0
	var vel = gradient(a.positions)
	var accel = gradient(vel)
	var jerks = gradient(accel)
	for jerk in jerks:
		total += jerk.length()
	var reward = total / episode_length
	a.controller.reward += reward


## Apply a reward based on this agent's total distance travelled in the episode.
## 0 - 1 based on min - max distance travelled.
func apply_total_dist_reward(a : Agent) -> void:
	if not a.enable_total_dist_reward:
		return
	var total_dist = 0.0
	var grad = gradient(a.positions)
	for p in grad:
		total_dist += p.length()
	var average = total_dist / a.positions.size()
	var reward = average / a.max_velocity.length()
	a.controller.reward += reward


## Generate a dictionary with a node's properties.
func generate_info(node : Node) -> Dictionary:
	var node_info = {}
	var script = node.get_script()
	if script == null:
		print("Failed to generate info. No script attached to this node!")
		return {}
	var properties = script.get_script_property_list()
	for dict in properties:
		node_info[dict.name] = node.get(dict.name)
	return node_info


## Set the agent's values based on a config file.
func config_agent(a : Agent, cfg : ConfigFile, args : Dictionary):
	var properties = a.get_script().get_script_property_list()
	var exclude = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY

	for prop in properties:
		if prop.usage & exclude:
			continue
		a.set(prop.name, cfg.get_value(a.name, prop.name, a.get(prop.name)))

	var active_agent = args["active_agent"]
	if a.name == "A" + str(active_agent): 
		a.control_mode = Controller.ControlModes.HUMAN
		a.controller.control_mode = Controller.ControlModes.HUMAN
		a.can_vibrate = true


## Return a dictionary of cmdline args passed to the executable.
func parse_args() -> Dictionary:
	var args = {}
	for arg in OS.get_cmdline_args():
		if arg.find("=") > -1:
			var key_value = arg.split("=")
			args[key_value[0].lstrip("--")] = key_value[1]
		else:
			args[arg.lstrip("--")] = ""
	return args


## Return a config file loaded from cmdline args.
func load_config(args : Dictionary) -> ConfigFile:
	if not args.has("reward_config"):
		print("Reward config not found.")
		return null
	var config = ConfigFile.new()
	var error = config.load(args["reward_config"])
	if error:
		print("Failed to load config.", error_string(error), args["reward_config"])
		return null
	return config


## Initialize member variables with values from user config.
func config_arena(cfg : ConfigFile) -> void:
	episode_length = cfg.get_value("Arena", "episode_length", episode_length)
	debug = cfg.get_value("Arena", "debug", debug)


## Update an agent's visual velocity. Must be called after constrain.
func update_visual_velocity(a : Agent) -> void:
	a.last_visual_velocity = a.visual_velocity
	var vel : Vector2 = a.last_position - a.global_position
	a.visual_velocity = vel 


## Parse a ConfigFile to a string.
func dict_to_string(inf : Dictionary, depth : int = 0) -> String:
	var s : String = ""
	var spaces = ""
	for i in range(depth):
		spaces += "     "
	for key in inf.keys():
		var val = inf[key]
		if not val is Dictionary:
			s += spaces + key + ": " + str(val) + "\n"
		else:
			s += spaces + key + "\n" + dict_to_string(val, depth + 1)
	return s


## Update this arena's info text.
func update_info() -> void:
	var info = {}
	info["Arena"] = generate_info(self)
	for a in Globals.agents:
		info[a.name] = generate_info(a)
	info_label.text = dict_to_string(info)
