extends Node
class_name MatchEngine

# 🧩 Core State
var players: Array = []
var rounds: Array = []
var turn_count: int = 0
var rng := RandomNumberGenerator.new()

# 🧩 Simulate a Turn
func simulate_turn() -> MatchRound:
	turn_count += 1

	var alive_players = []
	for p in players:
		if p.alive:
			alive_players.append(p)

	if alive_players.size() < 2:
		print("Not enough players to simulate a turn.")
		return null

	var thrower = alive_players[rng.randi_range(0, alive_players.size() - 1)]
	var target_pool = []
	for p in alive_players:
		if p != thrower:
			target_pool.append(p)

	var target = target_pool[rng.randi_range(0, target_pool.size() - 1)]

	var round = MatchRound.new()
	round.turn = turn_count
	round.thrower = thrower
	round.target = target

	var result = resolve_throw(thrower, target, rng)
	round.outcome = result["outcome"]
	round.throw_power = result["throw_power"]
	round.dodge_power = result["dodge_power"]
	round.catch_power = result["catch_power"]
	round.roll = result["roll"]

	round.commentary = generate_commentary(round)

	if round.outcome == "Caught":
		var revived = revive_teammate(thrower)
		round.revived_player = revived
		round.ball_holder_after = revived if revived else target
	else:
		round.ball_holder_after = target

	for p in players:
		p.ball_held = p == round.ball_holder_after

	rounds.append(round)
	return round

# 🧩 Throw Resolution Logic
func resolve_throw(thrower: Player, target: Player, rng: RandomNumberGenerator) -> Dictionary:
	var accuracy = thrower.stats["accuracy"]
	var ferocity = thrower.stats["ferocity"]
	var throw_power = accuracy + ferocity

	var dodge_power = target.stats["instinct"] + target.stats["hustle"]
	var catch_power = target.stats["hands"] + target.stats["backbone"]

	var total = throw_power + dodge_power + catch_power
	var roll = rng.randi_range(0, total - 1)

	var outcome := ""
	if roll < dodge_power:
		outcome = "Dodged"
	elif roll < dodge_power + catch_power:
		outcome = "Caught"
	else:
		target.eliminate()
		outcome = "Hit"

	return {
		"outcome": outcome,
		"throw_power": throw_power,
		"dodge_power": dodge_power,
		"catch_power": catch_power,
		"roll": roll
	}

# 🧩 Revival Logic
func revive_teammate(thrower: Player) -> Player:
	var team = thrower.team
	var eliminated = []
	for p in players:
		if not p.alive and p.team == team:
			eliminated.append(p)

	if eliminated.size() > 0:
		var revived = eliminated[0]
		revived.revive()
		return revived

	return null

# 🧩 Commentary Engine
func generate_commentary(round: MatchRound) -> String:
	var key = "%s_%s" % [round.outcome, round.target.archetype]
	var templates = {
		"Dodged_Default": "%s saw it coming and moved fast.",
		"Caught_Default": "%s snatched it mid-air—%s is out.",
		"Hit_Default": "%s landed the hit—%s is out.",
		"Dodged_Ghost": "%s melted away like a whisper.",
		"Caught_Hothead": "%s lunged and grabbed it—classic hothead reflex.",
		"Hit_Strategist": "%s calculated the angle and scored.",
		"Revived_Default": "%s caught it! %s returns to the fray!"
	}

	if templates.has(key):
		return templates[key].format(round.target.name, round.thrower.name)
	else:
		var fallback = "%s_Default" % round.outcome
		return templates.get(fallback, "A moment passes.").format(round.target.name, round.thrower.name)

# 🧩 Player Setup
func setup_players():
	var Player = preload("res://scripts/Player.gd")

	var p1 = Player.new()
	p1.name = "Hothead"
	p1.team = "Red"
	p1.archetype = "Hothead"
	p1.stats = {
		"accuracy": 7,
		"ferocity": 8,
		"instinct": 3,
		"hustle": 4,
		"hands": 4,
		"backbone": 2
	}

	var p2 = Player.new()
	p2.name = "Ghost"
	p2.team = "Blue"
	p2.archetype = "Ghost"
	p2.stats = {
		"accuracy": 4,
		"ferocity": 3,
		"instinct": 8,
		"hustle": 7,
		"hands": 5,
		"backbone": 6
	}

	var p3 = Player.new()
	p3.name = "Strategist"
	p3.team = "Red"
	p3.archetype = "Strategist"
	p3.stats = {
		"accuracy": 6,
		"ferocity": 5,
		"instinct": 6,
		"hustle": 5,
		"hands": 6,
		"backbone": 5
	}

	var p4 = Player.new()
	p4.name = "Wildcard"
	p4.team = "Blue"
	p4.archetype = "Wildcard"
	p4.stats = {
		"accuracy": 5,
		"ferocity": 6,
		"instinct": 2,
		"hustle": 6,
		"hands": 3,
		"backbone": 4
	}

	players = [p1, p2, p3, p4]

# 🧩 Entry Point
func _ready():
	rng.seed = 123456
	setup_players()
	simulate_match()

# 🧩 Full Match Simulation
func simulate_match():
	while true:
		var alive_teams := {}
		for p in players:
			if p.alive:
				alive_teams[p.team] = true

		if alive_teams.size() < 2:
			print("Match over! Winning team: %s" % alive_teams.keys()[0])
			break

		var round = simulate_turn()
		if round != null:
			print("Turn %d: %s throws at %s → %s" % [round.turn, round.thrower.name, round.target.name, round.outcome])
			print("Commentary: %s" % round.commentary)
			print("Stats — Throw: %d | Dodge: %d | Catch: %d | Roll: %d" %
				[round.throw_power, round.dodge_power, round.catch_power, round.roll])
			print("-----")
