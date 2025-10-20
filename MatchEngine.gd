extends Node
class_name MatchEngine

# 🧩 Core State
var players: Array = []
var rounds: Array = []
var turn_count: int = 0

# 🧩 Simulate a Turn
func simulate_turn():
	turn_count += 1

	var alive_players = []
	for p in players:
		if p.alive:
			alive_players.append(p)

	if alive_players.size() < 2:
		print("Not enough players to simulate a turn.")
		return

	var thrower = alive_players[randi() % alive_players.size()]
	var target_pool = []
	for p in alive_players:
		if p != thrower:
			target_pool.append(p)

	var target = target_pool[randi() % target_pool.size()]

	var round = MatchRound.new()
	round.turn = turn_count
	round.thrower = thrower
	round.target = target

	round.outcome = resolve_throw(thrower, target)
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

# 🧩 Throw Resolution Logic
func resolve_throw(thrower: Player, target: Player) -> String:
	# Placeholder — we’ll wire in stat-based logic later
	var outcomes = ["Dodged", "Caught", "Hit"]
	return outcomes[randi() % outcomes.size()]

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
