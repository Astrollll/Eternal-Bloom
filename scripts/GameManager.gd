extends Node

# Signals for UI and Sound
signal xp_changed(current, goal)
signal level_up(new_level)

var level = 1
var xp = 0
var xp_goal = 50 

func collect_xp(amount):
	xp += amount
	xp_changed.emit(xp, xp_goal)
	if xp >= xp_goal:
		level_up_sequence()

func level_up_sequence():
	level += 1
	xp = 0
	xp_goal = int(xp_goal * 1.5)
	level_up.emit(level)
	get_tree().paused = true # Freezes game for the upgrade menu