class_name MatchRound
extends Resource

var turn: int
var thrower: Player
var target: Player
var outcome: String
var commentary: String
var revived_player: Player = null
var ball_holder_after: Player = null

# 🪓 New: Stat breakdown
var throw_power: int
var dodge_power: int
var catch_power: int
var roll: int
