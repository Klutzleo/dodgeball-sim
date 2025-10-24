class_name MatchRound
extends Resource

var turn: int = 0
var thrower: Player
var target: Player
var outcome: String
var commentary: String
var revived_player: Player = null
var ball_holder_after: Player = null

# 🪓 Stat breakdown
var throw_power: int = 0
var dodge_power: int = 0
var catch_power: int = 0
var roll: int = 0

# Clutch detection
var was_clutch: bool = false

# Streaks
var thrower_hit_streak: int = 0
var target_dodge_streak: int = 0
var target_catch_streak: int = 0
var target_clutch_streak: int = 0
