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
var ball_count: int = 0
var max_balls: int = 2
var reaction_timer: float = 0.0
var commentary: Array = []

func revive():
	alive = true
	give_ball(1)

func eliminate():
	alive = false
	drop_all_balls()
	
# Streaks
var hit_streak: int = 0
var dodge_streak: int = 0
var catch_streak: int = 0
var clutch_streak: int = 0
var max_ball_count: int = 0

func reset():
	alive = true
	drop_all_balls()
	hit_streak = 0
	dodge_streak = 0
	catch_streak = 0
	clutch_streak = 0
	max_ball_count = 0

func give_ball(count: int = 1):
	ball_count = clamp(ball_count + count, 0, max_balls)
	ball_held = ball_count > 0
	max_ball_count = max(max_ball_count, ball_count)

func take_ball(count: int = 1):
	ball_count = max(ball_count - count, 0)
	ball_held = ball_count > 0

func drop_all_balls():
	ball_count = 0
	ball_held = false
	
func to_dict() -> Dictionary:
	return {
		"name": name,
		"team": team,
		"archetype": archetype,
		"alive": alive,
		"ball_held": ball_held,
		"ball_count": ball_count,
		"stats": stats,
		"streaks": {
			"hit": hit_streak,
			"dodge": dodge_streak,
			"catch": catch_streak,
			"clutch": clutch_streak
		}
	}
