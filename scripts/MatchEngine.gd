extends Node
class_name MatchEngine

# 🧩 Core State
var players: Array = []              # All players in the match
var rounds: Array = []               # History of MatchRound objects
var turn_count: int = 0              # Tracks current turn number
var rng := RandomNumberGenerator.new()  # Seeded RNG for reproducibility

# 🧩 Simulate a Turn
func simulate_turn() -> MatchRound:
	turn_count += 1

	# Filter alive players
	var alive_players = []
	for p in players:
		if p.alive:
			alive_players.append(p)

	if alive_players.size() < 2:
		print("Not enough players to simulate a turn.")
		return null

	# Randomly select thrower and target
	var thrower = alive_players[rng.randi_range(0, alive_players.size() - 1)]
	var target_pool = []
	for p in alive_players:
		if p != thrower:
			target_pool.append(p)
	var target = target_pool[rng.randi_range(0, target_pool.size() - 1)]

	# Create and populate MatchRound
	var round = MatchRound.new()
	round.turn = turn_count
	round.thrower = thrower
	round.target = target

func simulate_opening_rush(players: Array) -> void:
	var ball_grab_scores := []
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Step 1: Calculate ball grab scores
	for p in players:
		var score = p.stats["hustle"] + p.stats["ferocity"] + rng.randi_range(0, 5)
		ball_grab_scores.append({ "player": p, "score": score })

	# Step 2: Sort by score descending
	ball_grab_scores.sort_custom(self, "_sort_by_score")

	# Step 3: Assign balls to top 6
	for i in range(6):
		var p = ball_grab_scores[i]["player"]
		p.ball_held = true
		p.commentary.append("🏃‍♂️ Grabbed a ball in the opening rush!")

		# Step 4: Set reaction delay based on instinct
		var base_time = 6.0
		var modifier = 0.5
		var reaction_time = base_time - (p.stats["instinct"] * modifier) + rng.randf_range(0.0, 1.0)
		p.reaction_timer = reaction_time

	# Optional: Commentary for others
	for i in range(6, ball_grab_scores.size()):
		var p = ball_grab_scores[i]["player"]
		p.commentary.append("😬 Missed the ball scramble.")

func _sort_by_score(a, b):
	return b["score"] - a["score"]

	var result = resolve_throw(thrower, target, rng)
	round.outcome = result["outcome"]
	round.throw_power = result["throw_power"]
	round.dodge_power = result["dodge_power"]
	round.catch_power = result["catch_power"]
	round.roll = result["roll"]

	round.commentary = generate_commentary(round)

	# Handle revival if caught
	if round.outcome == "Caught":
		var revived = revive_teammate(thrower)
		round.revived_player = revived
		round.ball_holder_after = revived if revived else target
	else:
		round.ball_holder_after = target

	# Update ball possession
	for p in players:
		p.ball_held = p == round.ball_holder_after

	rounds.append(round)
	return round

# 🧩 Throw Resolution Logic
func resolve_throw(thrower: Player, target: Player, rng: RandomNumberGenerator) -> Dictionary:
	var throw_power = thrower.stats["accuracy"] + thrower.stats["ferocity"]
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

# 🧩 Clutch Detection
func detect_clutch(round: MatchRound) -> bool:
	var dodge_cutoff = round.dodge_power
	var catch_cutoff = round.dodge_power + round.catch_power
	var total = round.throw_power + round.dodge_power + round.catch_power
	var roll = round.roll

	if abs(roll - dodge_cutoff) <= 2:
		return true
	elif abs(roll - catch_cutoff) <= 2:
		return true
	elif abs(roll - total) <= 2:
		return true

	return false

# 🧩 Full Match Simulation
func simulate_match() -> String:
	while true:
		# Check which teams still have alive players
		var alive_teams := {}
		for p in players:
			if p.alive:
				alive_teams[p.team] = true

		if alive_teams.size() < 2:
			var winner = alive_teams.keys()[0]
			print("Match over! Winning team: %s" % winner)
			return winner

		# Simulate a turn
		var round = simulate_turn()
		if round == null:
			print("Simulation failed — no valid turn.")
			break

		# Print round summary
		print("Turn %d: %s throws at %s → %s" % [round.turn, round.thrower.name, round.target.name, round.outcome])
		print("Commentary: %s" % round.commentary)
		print("Stats — Throw: %d | Dodge: %d | Catch: %d | Roll: %d" %
			[round.throw_power, round.dodge_power, round.catch_power, round.roll])
		print("-----")

		# Detect clutch play
		if detect_clutch(round):
			print("🔥 Clutch play detected!")
			round.target.clutch_streak += 1
		else:
			round.target.clutch_streak = 0

		# Reset streaks for uninvolved players
		for p in players:
			if p != round.target and p != round.thrower:
				p.hit_streak = 0
				p.dodge_streak = 0
				p.catch_streak = 0
				p.clutch_streak = 0

		# Apply streak logic
		match round.outcome:
			"Hit":
				round.thrower.hit_streak += 1
				round.target.hit_streak = 0
				round.target.dodge_streak = 0
				round.target.catch_streak = 0
			"Dodged":
				round.target.dodge_streak += 1
				round.thrower.hit_streak = 0
			"Caught":
				round.target.catch_streak += 1
				round.thrower.hit_streak = 0

		# Snapshot streaks for logging
		round.thrower_hit_streak = round.thrower.hit_streak
		round.target_dodge_streak = round.target.dodge_streak
		round.target_catch_streak = round.target.catch_streak
		round.target_clutch_streak = round.target.clutch_streak

		# Trigger streak commentary
		if round.thrower.hit_streak >= 3:
			print("🔥 %s is on a hit streak!" % round.thrower.name)
		if round.target.dodge_streak >= 3:
			print("🌀 %s is dodging everything!" % round.target.name)
		if round.target.catch_streak >= 3:
			print("🧤 %s is catching fire!" % round.target.name)
		if round.target.clutch_streak >= 3:
			print("💥 %s thrives under pressure!" % round.target.name)

	# Fallback return
	return "Unknown"

# 🧩 Series Simulation (Best of 3)
func simulate_series():
	var red_wins = 0
	var blue_wins = 0
	var match_number = 1

	while red_wins < 2 and blue_wins < 2:
		reset_players()
		print("Match %d begins!" % match_number)
		var winner = simulate_match()
		if winner == "Red":
			red_wins += 1
		else:
			blue_wins += 1
		match_number += 1

	print("Series over! %s wins the best-of-3!" % ("Red" if red_wins > blue_wins else "Blue"))

# 🧩 Reset Players Between Matches
func reset_players():
	for p in players:
		p.alive = true
		p.ball_held = false
		p.hit_streak = 0
		p.dodge_streak = 0
		p.catch_streak = 0
		p.clutch_streak
