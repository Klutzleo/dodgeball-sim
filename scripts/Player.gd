class_name Player

var name: String
var team: String
var archetype: String
var stats = {
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
