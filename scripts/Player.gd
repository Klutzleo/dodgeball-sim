class_name Player

var name: String
var team: String
var archetype: String
var stats: Dictionary = {
	"accuracy": 0,
	"ferocity": 0,
	"instinct": 0,
	"hustle": 0,
	"hands": 0,
	"backbone": 0
}
var alive: bool = true
var ball_held: bool = false

func revive():
	alive = true
	ball_held = true

func eliminate():
	alive = false
	ball_held = false
	
# Streaks
var hit_streak: int = 0
var dodge_streak: int = 0
var catch_streak: int = 0
var clutch_streak: int = 0

func reset():
	alive = true
	ball_held = false
	hit_streak = 0
	dodge_streak = 0
	catch_streak = 0
	clutch_streak = 0
	
func to_dict() -> Dictionary:
	return {
		"name": name,
		"team": team,
		"archetype": archetype,
		"alive": alive,
		"ball_held": ball_held,
		"stats": stats,
		"streaks": {
			"hit": hit_streak,
			"dodge": dodge_streak,
			"catch": catch_streak,
			"clutch": clutch_streak
		}
	}
