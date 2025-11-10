extends Node
class_name MatchEngine

# 🧩 Core State
var players: Array = []
var rounds: Array = []
var turn_count: int = 0
var rng := RandomNumberGenerator.new()

# 🧩 Opening Rush
func simulate_opening_rush(players: Array) -> void:
	var ball_grab_scores := []

	for p in players:
		var score = p.stats["hustle"] + p.stats["ferocity"] + rng.randi_range(0, 5)
		ball_grab_scores.append({ "player": p, "score": score })

	ball_grab_scores.sort_custom(func(a, b): return b["score"] - a["score"])

	for i in range(6):
		var p = ball_grab_scores[i]["player"]
		p.ball_held = true
		p.commentary.append("🏃‍♂️ Grabbed a ball in the opening rush!")
		var base_time = 6.0
		var modifier = 0.5
		var reaction_time = base_time - (p.stats["instinct"] * modifier) + rng.randf_range(0.0, 1.0)
		p.reaction_timer = reaction_time

	for i in range(6, ball_grab_scores.size()):
		var p = ball_grab_scores[i]["player"]
		p.commentary.append("😬 Missed the ball scramble.")

# 🧩 Throw Resolution
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
	var eliminated := players.filter(func(p): return not p.alive and p.team == team)
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

	return abs(roll - dodge_cutoff) <= 2 or abs(roll - catch_cutoff) <= 2 or abs(roll - total) <= 2

func choose_action(player: Player) -> String:
	var options := []
	var weights := {}

	var has_ball = player.ball_held
	var teammates_alive = players.filter(func(p): return p.alive and p.team == player.team and p != player).size()
	var enemies_alive = players.filter(func(p): return p.alive and p.team != player.team).size()

	# 🔥 Hothead: favors throw
	if player.archetype == "Hothead":
		if has_ball:
			options = ["throw", "taunt", "hold"]
			weights = { "throw": 5, "taunt": 2, "hold": 1 }
		else:
			options = ["taunt", "dodge"]
			weights = { "taunt": 3, "dodge": 2 }

	# 🧠 Strategist: favors pass and hold
	elif player.archetype == "Strategist":
		if has_ball:
			options = ["pass", "hold", "throw"]
			weights = { "pass": 4, "hold": 3, "throw": 2 }
		else:
			options = ["dodge", "hold"]
			weights = { "dodge": 3, "hold": 2 }

	# 👻 Ghost: favors dodge and taunt
	elif player.archetype == "Ghost":
		if has_ball:
			options = ["throw", "taunt", "hold"]
			weights = { "throw": 3, "taunt": 3, "hold": 1 }
		else:
			options = ["dodge", "taunt"]
			weights = { "dodge": 5, "taunt": 2 }

	# 🧱 Default: balanced chaos
	else:
		if has_ball:
			options = ["throw", "pass", "hold", "taunt"]
			weights = { "throw": 3, "pass": 2, "hold": 2, "taunt": 1 }
		else:
			options = ["dodge", "taunt", "hold"]
			weights = { "dodge": 3, "taunt": 2, "hold": 1 }

	# 🧠 Streak modifiers
	if player.hit_streak >= 2:
		weights["throw"] = weights.get("throw", 1) + 2
	if player.catch_streak >= 2:
		weights["pass"] = weights.get("pass", 1) + 2
	if player.clutch_streak >= 2:
		weights["hold"] = weights.get("hold", 1) + 2
	if player.dodge_streak >= 2:
		weights["dodge"] = weights.get("dodge", 1) + 2

	# 🎲 Weighted roll
	var total_weight = 0
	for action in options:
		total_weight += weights.get(action, 1)

	var roll = rng.randi_range(0, total_weight - 1)
	var cumulative = 0
	for action in options:
		cumulative += weights.get(action, 1)
		if roll < cumulative:
			return action

	return options[0]  # fallback

# 🧩 Real-Time Reaction Queue
func simulate_reaction_queue(current_time: float) -> void:
	for p in players:
		if not p.alive or not p.ball_held:
			continue

		if p.reaction_timer <= current_time:
			var target_pool := players.filter(func(t): return t.alive and t.team != p.team)
			if target_pool.size() == 0:
				continue

			var target: Player = target_pool[rng.randi_range(0, target_pool.size() - 1)]
			var round := MatchRound.new()
			round.turn = turn_count
			round.thrower = p
			round.target = target
			round.match_time = current_time

			var result = resolve_throw(p, target, rng)
			round.outcome = result["outcome"]
			round.throw_power = result["throw_power"]
			round.dodge_power = result["dodge_power"]
			round.catch_power = result["catch_power"]
			round.roll = result["roll"]
			round.commentary = generate_commentary(round)

			if round.outcome == "Caught":
				var revived = revive_teammate(p)
				round.revived_player = revived
				round.ball_holder_after = revived if revived else target
			else:
				round.ball_holder_after = target

			for q in players:
				q.ball_held = q == round.ball_holder_after

			# Streak logic
			if detect_clutch(round):
				round.target.clutch_streak += 1
			else:
				round.target.clutch_streak = 0

			for q in players:
				if q != round.target and q != round.thrower:
					q.hit_streak = 0
					q.dodge_streak = 0
					q.catch_streak = 0
					q.clutch_streak = 0

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

			# Snapshot streaks
			round.thrower_hit_streak = round.thrower.hit_streak
			round.target_dodge_streak = round.target.dodge_streak
			round.target_catch_streak = round.target.catch_streak
			round.target_clutch_streak = round.target.clutch_streak

			rounds.append(round)
			print("⏱️ %.2f | %s throws at %s → %s" % [current_time, p.name, target.name, round.outcome])
			print("Commentary: %s" % round.commentary)

			# Reset reaction timer
			var base_time = 6.0
			var modifier = 0.5
			p.reaction_timer = current_time + base_time - (p.stats["instinct"] * modifier) + rng.randf_range(0.0, 1.0)

func simulate_throw(p: Player, current_time: float) -> void:
	var target_pool := players.filter(func(t): return t.alive and t.team != p.team)
	if target_pool.size() == 0:
		return

	var target: Player = target_pool[rng.randi_range(0, target_pool.size() - 1)]
	var round := MatchRound.new()
	round.turn = turn_count
	round.thrower = p
	round.target = target
	round.match_time = current_time

	var result = resolve_throw(p, target, rng)
	round.outcome = result["outcome"]
	round.throw_power = result["throw_power"]
	round.dodge_power = result["dodge_power"]
	round.catch_power = result["catch_power"]
	round.roll = result["roll"]
	round.commentary = generate_commentary(round)

	if round.outcome == "Caught":
		var revived = revive_teammate(p)
		round.revived_player = revived
		round.ball_holder_after = revived if revived else target
	else:
		round.ball_holder_after = target

	for q in players:
		q.ball_held = q == round.ball_holder_after

	# Streak logic
	if detect_clutch(round):
		round.target.clutch_streak += 1
	else:
		round.target.clutch_streak = 0

	for q in players:
		if q != round.target and q != round.thrower:
			q.hit_streak = 0
			q.dodge_streak = 0
			q.catch_streak = 0
			q.clutch_streak = 0

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

	# Snapshot streaks
	round.thrower_hit_streak = round.thrower.hit_streak
	round.target_dodge_streak = round.target.dodge_streak
	round.target_catch_streak = round.target.catch_streak
	round.target_clutch_streak = round.target.clutch_streak

	rounds.append(round)
	print("🎯 %.2f | %s throws at %s → %s" % [current_time, p.name, target.name, round.outcome])
	print("Commentary: %s" % round.commentary)

func simulate_pass(p: Player, current_time: float) -> void:
	var teammate_pool := players.filter(func(t): return t.alive and t.team == p.team and t != p)
	if teammate_pool.size() == 0:
		return  # No one to pass to

	var receiver: Player = teammate_pool[rng.randi_range(0, teammate_pool.size() - 1)]

	var round := MatchRound.new()
	round.turn = turn_count
	round.thrower = p
	round.target = receiver
	round.match_time = current_time
	round.outcome = "Pass"
	round.commentary = "%s passed the ball to %s." % [p.name, receiver.name]
	round.ball_holder_after = receiver

	for q in players:
		q.ball_held = q == receiver

	# Optional: reset receiver's reaction timer for immediate follow-up
	var base_time = 6.0
	var modifier = 0.5
	receiver.reaction_timer = current_time + base_time - (receiver.stats["instinct"] * modifier) + rng.randf_range(0.0, 1.0)

	rounds.append(round)
	print("🤝 %.2f | %s passed to %s" % [current_time, p.name, receiver.name])
	print("Commentary: %s" % round.commentary)

func simulate_dodge(p: Player, current_time: float) -> void:
	var round := MatchRound.new()
	round.turn = turn_count
	round.thrower = p
	round.target = p  # Self-targeted action
	round.match_time = current_time
	round.outcome = "Dodge"
	round.commentary = "%s juked and rolled — just in case." % p.name
	round.ball_holder_after = p if p.ball_held else null

	# Optional: add streak logic
	p.dodge_streak += 1
	round.target_dodge_streak = p.dodge_streak

	rounds.append(round)
	print("🌀 %.2f | %s dodged preemptively" % [current_time, p.name])
	print("Commentary: %s" % round.commentary)

func simulate_hold(p: Player, current_time: float) -> void:
	var round := MatchRound.new()
	round.turn = turn_count
	round.thrower = p
	round.target = p  # Self-targeted action
	round.match_time = current_time
	round.outcome = "Hold"
	round.commentary = "%s held the ball, waiting for the perfect moment..." % p.name
	round.ball_holder_after = p if p.ball_held else null

	rounds.append(round)
	print("⏳ %.2f | %s held the ball" % [current_time, p.name])
	print("Commentary: %s" % round.commentary)

func simulate_taunt(p: Player, current_time: float) -> void:
	var taunts := [
		"%s shouted, 'You call that a throw?'",
		"%s winked and pointed at the other team.",
		"%s spun the ball and grinned.",
		"%s yelled, 'You're next!'",
		"%s did a little dance. It was... unsettling."
	]

	var line = taunts[rng.randi_range(0, taunts.size() - 1)] % p.name

	var round := MatchRound.new()
	round.turn = turn_count
	round.thrower = p
	round.target = p
	round.match_time = current_time
	round.outcome = "Taunt"
	round.commentary = line
	round.ball_holder_after = p if p.ball_held else null

	rounds.append(round)
	print("💬 %.2f | %s taunted" % [current_time, p.name])
	print("Commentary: %s" % round.commentary)

# 🧩 Real-Time Match Loop
func simulate_match(max_time: float = 360.0, step: float = 1.0) -> String:
	var current_time := 0.0

	while current_time <= max_time:
		simulate_reaction_queue(current_time)

		var alive_teams := {}
		for p in players:
			if p.alive:
				alive_teams[p.team] = true

		if alive_teams.size() < 2:
			var winner = alive_teams.keys()[0]
			print("🏁 Match ends at %.2f seconds — %s wins!" % [current_time, winner])
			return winner

		current_time += step

	print("⏱️ Time expired — match ends in a draw.")
	return "Draw"

func generate_match_summary(rounds: Array) -> Dictionary:
	var stats := {}
	for p in players:
		stats[p.name] = {
			"hits": 0,
			"catches": 0,
			"dodges": 0,
			"passes": 0,
			"holds": 0,
			"taunts": 0,
			"clutch": 0,
			"revives": 0,
			"hit_streak": 0,
			"catch_streak": 0,
			"dodge_streak": 0,
			"clutch_streak": 0
		}

	for round in rounds:
		var name = round.thrower.name
		match round.outcome:
			"Hit":
				stats[name]["hits"] += 1
			"Caught":
				stats[round.target.name]["catches"] += 1
			"Dodged":
				stats[round.target.name]["dodge_streak"] += 1
				stats[round.target.name]["dodges"] += 1
			"Pass":
				stats[name]["passes"] += 1
			"Hold":
				stats[name]["holds"] += 1
			"Taunt":
				stats[name]["taunts"] += 1
			"Dodge":
				stats[name]["dodges"] += 1
			"Revive":
				if round.revived_player:
					stats[name]["revives"] += 1

		# Streak snapshots
		stats[name]["hit_streak"] = max(stats[name]["hit_streak"], round.thrower_hit_streak)
		stats[round.target.name]["catch_streak"] = max(stats[round.target.name]["catch_streak"], round.target_catch_streak)
		stats[round.target.name]["dodge_streak"] = max(stats[round.target.name]["dodge_streak"], round.target_dodge_streak)
		stats[round.target.name]["clutch_streak"] = max(stats[round.target.name]["clutch_streak"], round.target_clutch_streak)

	return stats

func print_match_summary(summary: Dictionary) -> void:
	print("\n📊 MATCH SUMMARY")
	print("────────────────────────────")

	for name in summary.keys():
		var s = summary[name]
		print("👤 %s" % name)
		print("   🎯 Hits: %d | 🧤 Catches: %d | 🌀 Dodges: %d" % [s["hits"], s["catches"], s["dodges"]])
		print("   🤝 Passes: %d | ⏳ Holds: %d | 💬 Taunts: %d" % [s["passes"], s["holds"], s["taunts"]])
		print("   🔁 Revives: %d | 🔥 Hit Streak: %d | 🧠 Clutch Streak: %d" % [s["revives"], s["hit_streak"], s["clutch_streak"]])
		print("────────────────────────────")

func calculate_impact_score(stats: Dictionary) -> int:
	return (
		stats["hits"] * 5 +
		stats["catches"] * 4 +
		stats["dodges"] * 3 +
		stats["passes"] * 2 +
		stats["holds"] * 1 +
		stats["taunts"] * 1 +
		stats["revives"] * 4 +
		stats["hit_streak"] * 2 +
		stats["clutch_streak"] * 3
	)

func detect_mvp(summary: Dictionary) -> Dictionary:
	var best := { "name": "", "score": -1 }
	for name in summary.keys():
		var score = calculate_impact_score(summary[name])
		if score > best["score"]:
			best = { "name": name, "score": score }
	return best

# 🧩 Reset Players Between Matches
func reset_players():
	for p in players:
		p.reset()
		p.commentary.clear()
		p.reaction_timer = 0.0

	rounds.clear()
	turn_count = 0

func simulate_series():
	var red_wins = 0
	var blue_wins = 0
	var match_number = 1
	var series_stats := {}
	var series_log := []

	while red_wins < 2 and blue_wins < 2:
		reset_players()
		print("🎮 Match %d begins!" % match_number)
		var winner = simulate_match()

		var match_summary = generate_match_summary(rounds)
		print_match_summary(match_summary)

		# 🧠 Accumulate into series_stats
		for name in match_summary.keys():
			if not series_stats.has(name):
				series_stats[name] = match_summary[name].duplicate()
			else:
				for key in match_summary[name].keys():
					series_stats[name][key] += match_summary[name][key]

		# 🏆 Match MVP
		var match_mvp = detect_mvp(match_summary)
		print("🏅 Match %d MVP: %s with %d impact" % [match_number, match_mvp["name"], match_mvp["score"]])

		# 🗂️ Log this match
		series_log.append({
			"match": match_number,
			"winner": winner,
			"mvp": match_mvp["name"],
			"impact": match_mvp["score"]
		})

		if winner == "Red":
			red_wins += 1
		elif winner == "Blue":
			blue_wins += 1
		else:
			print("⚠️ Unexpected result: %s" % winner)

		match_number += 1

	# 🏆 Series MVP
	var series_mvp = detect_mvp(series_stats)
	print("\n🏆 SERIES MVP: %s with %d impact" % [series_mvp["name"], series_mvp["score"]])

	# 📊 Series Log Recap
	print("\n📘 SERIES LOG")
	for entry in series_log:
		print("Match %d → Winner: %s | MVP: %s (%d impact)" % [entry["match"], entry["winner"], entry["mvp"], entry["impact"]])

func generate_series_report(series_log: Array) -> Dictionary:
	var report := {
		"matches": [],
		"red_wins": 0,
		"blue_wins": 0,
		"draws": 0,
		"mvp_tally": {}
	}

	for entry in series_log:
		report["matches"].append({
			"match": entry["match"],
			"winner": entry["winner"],
			"mvp": entry["mvp"],
			"impact": entry["impact"]
		})

		if entry["winner"] == "Red":
			report["red_wins"] += 1
		elif entry["winner"] == "Blue":
			report["blue_wins"] += 1
		else:
			report["draws"] += 1

		if not report["mvp_tally"].has(entry["mvp"]):
			report["mvp_tally"][entry["mvp"]] = 1
		else:
			report["mvp_tally"][entry["mvp"]] += 1

	return report
