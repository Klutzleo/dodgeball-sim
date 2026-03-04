class_name Player
# v2 — training_ceiling is a per-stat Dictionary, not int

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

# 🌱 Progression fields
var age: int = 20                  # Age affects retirement risk and training ceiling
var sweat: int = 0                 # XP earned through matches and training

# Per-stat ceilings — hidden until scouted via Creep Sheet.
# A stat can never be trained above its ceiling (max 7).
var training_ceiling: Dictionary = {
	"accuracy": 7,
	"ferocity": 7,
	"instinct": 7,
	"hustle": 7,
	"hands": 7,
	"backbone": 7
}

# 🎯 Special skill
var special_skill: String = ""     # Skill ID (matches keys in MatchEngine skill handlers)
var skill_charges: int = -1        # Uses remaining. -1 = passive (unlimited)
var skill_stacks: int = 0          # Condition counter (e.g. taunt stacks, rage charges)

# ⚡ Per-match skill tracking (reset each match)
var times_targeted: int = 0        # Used by Leave Me Alone (Emo Kid)

# 🏐 Ball state
var alive: bool = true
var ball_count: int = 0
var max_balls: int = 2
var reaction_timer: float = 0.0
var commentary: Array = []

# 📊 Streak tracking
var hit_streak: int = 0
var dodge_streak: int = 0
var catch_streak: int = 0
var clutch_streak: int = 0
var max_ball_count: int = 0
var times_eliminated: int = 0

func revive():
	alive = true

func eliminate():
	alive = false
	drop_all_balls()
	times_eliminated += 1

func reset():
	alive = true
	drop_all_balls()
	hit_streak = 0
	dodge_streak = 0
	catch_streak = 0
	clutch_streak = 0
	max_ball_count = 0
	times_eliminated = 0
	skill_stacks = 0
	times_targeted = 0
	# skill_charges is restored by MatchEngine.reset_players() from archetype data

func give_ball(count: int = 1):
	ball_count = clamp(ball_count + count, 0, max_balls)
	max_ball_count = max(max_ball_count, ball_count)

func take_ball(count: int = 1):
	ball_count = max(ball_count - count, 0)

func drop_all_balls():
	ball_count = 0

# Spend sweat to raise a stat by 1 toward its ceiling.
# Cost = 5 * current_stat_value (so growing 3→4 costs 15, 6→7 costs 30).
# Returns true if training succeeded, false if blocked (at ceiling or not enough sweat).
func train_stat(stat: String) -> bool:
	if not stats.has(stat):
		return false
	var current: int = stats[stat]
	var ceiling: int = training_ceiling.get(stat, 7)
	if current >= ceiling:
		return false
	var cost: int = 5 * current
	if sweat < cost:
		return false
	sweat -= cost
	stats[stat] += 1
	return true

# How much sweat it costs to train a given stat next (0 if already at ceiling).
func train_cost(stat: String) -> int:
	if not stats.has(stat):
		return 0
	var current: int = stats[stat]
	if current >= training_ceiling.get(stat, 7):
		return 0
	return 5 * current

func to_dict() -> Dictionary:
	return {
		"name": name,
		"team": team,
		"archetype": archetype,
		"alive": alive,
		"ball_count": ball_count,
		"age": age,
		"sweat": sweat,
		"training_ceiling": training_ceiling,
		"special_skill": special_skill,
		"stats": stats,
		"streaks": {
			"hit": hit_streak,
			"dodge": dodge_streak,
			"catch": catch_streak,
			"clutch": clutch_streak
		},
		"times_eliminated": times_eliminated
	}
