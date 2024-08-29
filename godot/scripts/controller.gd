extends AIController2D
class_name Controller


var move_action : Vector2 = Vector2.ZERO


func get_obs() -> Dictionary:
	var obs : Array[float] = []
	obs.append(int(_player.colliding_with_wall))
	obs.append(int(_player.colliding_with_agent))
	for agent in Globals.agents:
		var local_position = to_local(agent.global_position)
		obs.append(local_position.x)
		obs.append(local_position.y)
		obs.append(agent.visual_velocity.x)
		obs.append(agent.visual_velocity.y)
	return {"obs": obs}


func get_reward() -> float:	
	return reward
	

func get_action_space() -> Dictionary:
	return {
			"move" : {
				"size": 2,
				"action_type": "continuous"
			},
		}
	

func set_action(action) -> void:	
	move_action = Vector2(
		action["move"][0],
		action["move"][1],
		).limit_length(1.0)
