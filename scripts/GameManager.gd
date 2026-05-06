extends Node

# Signals for UI and Sound
signal xp_changed(current, goal)
signal level_up(new_level)

var level = 1
var xp = 0
var xp_goal = 50

func collect_xp(amount):
	# Add XP from pickups or kills, then notify the UI of the new progress state.
	xp += amount
	xp_changed.emit(xp, xp_goal)
	if xp >= xp_goal:
		level_up_sequence()

func level_up_sequence():
	# Reset XP, raise the goal for the next level, and pause so the upgrade menu can take over.
	level += 1
	xp = 0
	xp_goal = int(xp_goal * 1.5)
	level_up.emit(level)
	get_tree().paused = true # Freezes game for the upgrade menu