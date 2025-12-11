extends Node
class_name MatchEngine

# 🧩 Core State
var players: Array = []
var rounds: Array = []
var turn_count: int = 0
var rng := RandomNumberGenerator.new()
var loose_balls: int = 0
const TOTAL_BALLS: int = 6

# 🧩 UI Callback for live logging
var ui_callback: Callable = Callable()  # Will be set by GameUI

func log_action(msg: String):
	"""Log action to console and UI if callback is set"""
	print(msg)
	if ui_callback.is_valid():
		ui_callback.call(msg)

# 🧮 Utility: keep total balls accounted for and pick up loose ones
func give_dropped_ball(preferred_team: String):
	var preferred := players.filter(func(p): return p.alive and p.team == preferred_team and p.ball_count < p.max_balls)
	var other := players.filter(func(p): return p.alive and p.team != preferred_team and p.ball_count < p.max_balls)

	# ~92% chance the ball stays with the same side, ~8% it rolls across mid
	var roll = rng.randf()
	var pool: Array = []
	if roll < 0.08 and not other.is_empty():
		pool = other
	elif not preferred.is_empty():
		pool = preferred
	elif not other.is_empty():
		pool = other

	if pool.size() > 0:
		pool.sort_custom(func(a, b):
			var sa = a.stats["hustle"] + a.stats["instinct"]
			var sb = b.stats["hustle"] + b.stats["instinct"]
			return sb - sa
		)
		var picker: Player = pool[0]
		picker.give_ball(1)
		return

	# No one can take it right now; track as loose for later rebalance
	loose_balls += 1

func rebalance_balls():
	var on_players = 0
	for p in players:
		on_players += p.ball_count
	var missing = TOTAL_BALLS - (on_players + loose_balls)
	if missing > 0:
		loose_balls += missing

	if loose_balls <= 0:
		return

	var eligible := players.filter(func(p): return p.alive and p.ball_count < p.max_balls)
	if eligible.is_empty():
		return

	eligible.sort_custom(func(a, b):
		var sa = a.stats["hustle"] + a.stats["instinct"]
		var sb = b.stats["hustle"] + b.stats["instinct"]
		return sb - sa
	)

	var idx = 0
	while loose_balls > 0 and eligible.size() > 0:
		var p: Player = eligible[idx % eligible.size()]
		if p.ball_count < p.max_balls:
			p.give_ball(1)
			loose_balls -= 1
		idx += 1

# 🧩 Opening Rush
func simulate_opening_rush(player_list: Array) -> void:
	var ball_grab_scores := []

	for p in player_list:
		p.drop_all_balls()
	loose_balls = 0

	for p in player_list:
		var score = p.stats["hustle"] + p.stats["ferocity"] + rng.randi_range(0, 5)
		ball_grab_scores.append({ "player": p, "score": score })

	ball_grab_scores.sort_custom(func(a, b): return b["score"] - a["score"])

	# Fastest six grab the six balls (speed wins the scramble)
	for i in range(ball_grab_scores.size()):
		var p: Player = ball_grab_scores[i]["player"]
		if i < TOTAL_BALLS:
			p.give_ball(1)
			p.commentary.append("🏃‍♂️ Grabbed a ball in the opening rush!")
			var base_time = 6.0
			var modifier = 0.5
			var reaction_time = base_time - (p.stats["instinct"] * modifier) + rng.randf_range(0.0, 1.0)
			p.reaction_timer = reaction_time
		else:
			p.commentary.append("😬 Missed the ball scramble.")

# 🧩 Throw Resolution
func resolve_throw(thrower: Player, target: Player, rng_local: RandomNumberGenerator) -> Dictionary:
	var throw_power = thrower.stats["accuracy"] + thrower.stats["ferocity"]
	var dodge_power = target.stats["instinct"] + target.stats["hustle"]
	var dodge_bonus = 1 if target.ball_count > 0 else 0  # Ball shield bonus
	dodge_power += dodge_bonus
	var catch_power = target.stats["hands"] + target.stats["backbone"]
	var total = throw_power + dodge_power + catch_power
	var roll = rng_local.randi_range(0, total - 1)

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
		"roll": roll,
		"dodge_bonus": dodge_bonus
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
func generate_commentary(round_rec: MatchRound) -> String:
	var key = "%s_%s" % [round_rec.outcome, round_rec.target.archetype]
	var templates = {
		# Dodged outcomes
		"Dodged_Default": "%s saw it coming and moved fast.",
		"Dodged_Ghost": "%s melted away like a whisper.",
		"Dodged_Hothead": "%s spun away with explosive reflexes!",
		"Dodged_Strategist": "%s anticipated that and sidestepped cleanly.",
		
		# Caught outcomes
		"Caught_Default": "%s snatched it mid-air—%s is out.",
		"Caught_Hothead": "%s lunged and grabbed it—classic hothead reflex.",
		"Caught_Ghost": "%s materialized to catch it mid-flight.",
		"Caught_Strategist": "%s read the trajectory perfectly and caught it.",
		
		# Hit outcomes
		"Hit_Default": "%s landed the hit—%s is out.",
		"Hit_Hothead": "%s got smashed—%s brought the heat!",
		"Hit_Ghost": "%s couldn't escape—caught by the phantom!",
		"Hit_Strategist": "%s calculated the angle and scored.",
		
		# Revived outcomes
		"Revived_Default": "%s caught it! %s returns to the fray!",
		
		# Pass outcomes
		"Pass_Default": "%s passed to %s.",
		
		# Hold outcomes
		"Hold_Default": "%s held the ball steady.",
		
		# Taunt outcomes
		"Taunt_Default": "%s taunted the other team.",
		
		# Dodge (self-action) outcomes
		"Dodge_Default": "%s dodged preemptively."
	}
	
	if templates.has(key):
		return templates[key].format([round_rec.target.name, round_rec.thrower.name])
	
	var fallback = "%s_Default" % round_rec.outcome
	if templates.has(fallback):
		return templates[fallback].format([round_rec.target.name, round_rec.thrower.name])
	
	return "A moment passes."

# 🧩 Clutch Detection
func detect_clutch(round_rec: MatchRound) -> bool:
	var dodge_cutoff = round_rec.dodge_power
	var catch_cutoff = round_rec.dodge_power + round_rec.catch_power
	var total = round_rec.throw_power + round_rec.dodge_power + round_rec.catch_power
	var roll = round_rec.roll

	return abs(roll - dodge_cutoff) <= 2 or abs(roll - catch_cutoff) <= 2 or abs(roll - total) <= 2

func choose_action(player: Player) -> String:
	var options := []
	var weights := {}

	var has_ball = player.ball_count > 0
	var _teammates_alive = players.filter(func(p): return p.alive and p.team == player.team and p != player).size()
	var _enemies_alive = players.filter(func(p): return p.alive and p.team != player.team).size()

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
	rebalance_balls()

	for p in players:
		if not p.alive or p.ball_count == 0:
			continue

		if p.reaction_timer <= current_time:
			var target_pool := players.filter(func(t): return t.alive and t.team != p.team)
			if target_pool.size() == 0:
				continue

			var target: Player = target_pool[rng.randi_range(0, target_pool.size() - 1)]
			var round_rec := MatchRound.new()
			round_rec.turn = turn_count
			round_rec.thrower = p
			round_rec.target = target
			round_rec.match_time = current_time
			p.take_ball(1)  # Spend one ball on this throw

			var target_balls_before = target.ball_count
			var result = resolve_throw(p, target, rng)
			round_rec.outcome = result["outcome"]
			round_rec.throw_power = result["throw_power"]
			round_rec.dodge_power = result["dodge_power"]
			round_rec.catch_power = result["catch_power"]
			round_rec.roll = result["roll"]
			round_rec.dodge_bonus = result.get("dodge_bonus", 0)
			round_rec.commentary = generate_commentary(round_rec)

			match round_rec.outcome:
				"Caught":
					var revived = revive_teammate(target)
					round_rec.revived_player = revived
					round_rec.ball_holder_after = revived if revived else target
					if revived == null:
						target.give_ball(1)
					var revived_msg = " ↩️ %s revived!" % revived.name if revived else " (No one to revive!)"
					log_action("   %s caught the ball!%s" % [target.name, revived_msg])
				"Hit":
					# Target is eliminated inside resolve_throw; drop carried balls + thrown ball to loose pool
					loose_balls += target_balls_before + 1
					round_rec.ball_holder_after = null
					# Ensure target has no balls
					target.drop_all_balls()
				"Dodged":
					# Missed throw becomes a loose ball
					loose_balls += 1
					round_rec.ball_holder_after = null
				_:
					# Default: drop to loose
					loose_balls += 1
					round_rec.ball_holder_after = null

			# Streak logic
			if detect_clutch(round_rec):
				round_rec.target.clutch_streak += 1
			else:
				round_rec.target.clutch_streak = 0

			for q in players:
				if q != round_rec.target and q != round_rec.thrower:
					q.hit_streak = 0
					q.dodge_streak = 0
					q.catch_streak = 0
					q.clutch_streak = 0

			match round_rec.outcome:
				"Hit":
					round_rec.thrower.hit_streak += 1
					round_rec.target.hit_streak = 0
					round_rec.target.dodge_streak = 0
					round_rec.target.catch_streak = 0
				"Dodged":
					round_rec.target.dodge_streak += 1
					round_rec.thrower.hit_streak = 0
				"Caught":
					round_rec.target.catch_streak += 1
					round_rec.thrower.hit_streak = 0

			# Snapshot streaks
			round_rec.thrower_hit_streak = round_rec.thrower.hit_streak
			round_rec.target_dodge_streak = round_rec.target.dodge_streak
			round_rec.target_catch_streak = round_rec.target.catch_streak
			round_rec.target_clutch_streak = round_rec.target.clutch_streak

			rounds.append(round_rec)
			var action_msg = "⏱️ %.2f | %s throws at %s → %s" % [current_time, p.name, target.name, round_rec.outcome]
			log_action(action_msg)
			log_action("   %s" % round_rec.commentary)

			# Reset reaction timer
			var base_time = 6.0
			var modifier = 0.5
			p.reaction_timer = current_time + base_time - (p.stats["instinct"] * modifier) + rng.randf_range(0.0, 1.0)

func simulate_throw(p: Player, current_time: float) -> void:
	var target_pool := players.filter(func(t): return t.alive and t.team != p.team)
	if target_pool.size() == 0:
		return
	if p.ball_count == 0:
		return

	var target: Player = target_pool[rng.randi_range(0, target_pool.size() - 1)]
	var round_rec := MatchRound.new()
	round_rec.turn = turn_count
	round_rec.thrower = p
	round_rec.target = target
	round_rec.match_time = current_time
	p.take_ball(1)

	var target_balls_before = target.ball_count
	var result = resolve_throw(p, target, rng)
	round_rec.outcome = result["outcome"]
	round_rec.throw_power = result["throw_power"]
	round_rec.dodge_power = result["dodge_power"]
	round_rec.catch_power = result["catch_power"]
	round_rec.roll = result["roll"]
	round_rec.dodge_bonus = result.get("dodge_bonus", 0)
	round_rec.commentary = generate_commentary(round_rec)

	match round_rec.outcome:
		"Caught":
			var revived = revive_teammate(target)
			round_rec.revived_player = revived
			round_rec.ball_holder_after = revived if revived else target
			if revived == null:
				target.give_ball(1)
			var revived_msg = " ↩️ %s revived!" % revived.name if revived else " (No one to revive!)"
			print("🧤 Caught: %s caught the ball!%s" % [target.name, revived_msg])
		"Hit":
			loose_balls += target_balls_before + 1
			round_rec.ball_holder_after = null
			target.drop_all_balls()
		"Dodged":
			loose_balls += 1
			round_rec.ball_holder_after = null
		_:
			loose_balls += 1
			round_rec.ball_holder_after = null

	# Streak logic
	if detect_clutch(round_rec):
		round_rec.target.clutch_streak += 1
	else:
		round_rec.target.clutch_streak = 0


	for q in players:
		if q != round_rec.target and q != round_rec.thrower:
			q.hit_streak = 0
			q.dodge_streak = 0
			q.catch_streak = 0
			q.clutch_streak = 0

	match round_rec.outcome:
		"Hit":
			round_rec.thrower.hit_streak += 1
			round_rec.target.hit_streak = 0
			round_rec.target.dodge_streak = 0
			round_rec.target.catch_streak = 0
		"Dodged":
			round_rec.target.dodge_streak += 1
			round_rec.thrower.hit_streak = 0
		"Caught":
			round_rec.target.catch_streak += 1
			round_rec.thrower.hit_streak = 0

	# Snapshot streaks
	round_rec.thrower_hit_streak = round_rec.thrower.hit_streak
	round_rec.target_dodge_streak = round_rec.target.dodge_streak
	round_rec.target_catch_streak = round_rec.target.catch_streak
	round_rec.target_clutch_streak = round_rec.target.clutch_streak

	rounds.append(round_rec)
	var action_msg = "🎯 %.2f | %s throws at %s → %s" % [current_time, p.name, target.name, round_rec.outcome]
	log_action(action_msg)
	log_action("   %s" % round_rec.commentary)

func simulate_pass(p: Player, current_time: float) -> void:
	var teammate_pool := players.filter(func(t): return t.alive and t.team == p.team and t != p)
	if teammate_pool.size() == 0:
		return  # No one to pass to
	if p.ball_count == 0:
		return  # Nothing to pass

	var receiver: Player = teammate_pool[rng.randi_range(0, teammate_pool.size() - 1)]

	var round_rec := MatchRound.new()
	round_rec.turn = turn_count
	round_rec.thrower = p
	round_rec.target = receiver
	round_rec.match_time = current_time
	round_rec.outcome = "Pass"
	round_rec.commentary = "%s passed the ball to %s." % [p.name, receiver.name]
	round_rec.ball_holder_after = receiver
	p.take_ball(1)
	receiver.give_ball(1)

	# Optional: reset receiver's reaction timer for immediate follow-up
	var base_time = 6.0
	var modifier = 0.5
	receiver.reaction_timer = current_time + base_time - (receiver.stats["instinct"] * modifier) + rng.randf_range(0.0, 1.0)

	rounds.append(round_rec)
	print("🤝 %.2f | %s passed to %s" % [current_time, p.name, receiver.name])
	print("Commentary: %s" % round_rec.commentary)

func simulate_dodge(p: Player, current_time: float) -> void:
	var round_rec := MatchRound.new()
	round_rec.turn = turn_count
	round_rec.thrower = p
	round_rec.target = p  # Self-targeted action
	round_rec.match_time = current_time
	round_rec.outcome = "Dodge"
	round_rec.commentary = "%s juked and rolled — just in case." % p.name
	round_rec.ball_holder_after = p if p.ball_count > 0 else null

	# Optional: add streak logic
	p.dodge_streak += 1
	round_rec.target_dodge_streak = p.dodge_streak

	rounds.append(round_rec)
	print("🌀 %.2f | %s dodged preemptively" % [current_time, p.name])
	print("Commentary: %s" % round_rec.commentary)

func simulate_hold(p: Player, current_time: float) -> void:
	var round_rec := MatchRound.new()
	round_rec.turn = turn_count
	round_rec.thrower = p
	round_rec.target = p  # Self-targeted action
	round_rec.match_time = current_time
	round_rec.outcome = "Hold"
	round_rec.commentary = "%s held the ball, waiting for the perfect moment..." % p.name
	round_rec.ball_holder_after = p if p.ball_count > 0 else null

	rounds.append(round_rec)
	print("⏳ %.2f | %s held the ball" % [current_time, p.name])
	print("Commentary: %s" % round_rec.commentary)

func simulate_taunt(p: Player, current_time: float) -> void:
	var taunts := [
		"%s shouted, 'You call that a throw?'",
		"%s winked and pointed at the other team.",
		"%s spun the ball and grinned.",
		"%s yelled, 'You're next!'",
		"%s did a little dance. It was... unsettling."
	]

	var line = taunts[rng.randi_range(0, taunts.size() - 1)] % p.name

	var round_rec := MatchRound.new()
	round_rec.turn = turn_count
	round_rec.thrower = p
	round_rec.target = p
	round_rec.match_time = current_time
	round_rec.outcome = "Taunt"
	round_rec.commentary = line
	round_rec.ball_holder_after = p if p.ball_count > 0 else null

	rounds.append(round_rec)
	print("💬 %.2f | %s taunted" % [current_time, p.name])
	print("Commentary: %s" % round_rec.commentary)

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

func generate_match_summary(round_log: Array) -> Dictionary:
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
			"hit_streak": 0,
			"catch_streak": 0,
			"dodge_streak": 0,
			"clutch_streak": 0,
			"ball_control": 0,
			"times_eliminated": 0
		}

	for round_rec in round_log:
		var thrower_name = round_rec.thrower.name
		var target_name = round_rec.target.name if round_rec.target else ""
		match round_rec.outcome:
			"Hit":
				stats[thrower_name]["hits"] += 1
			"Caught":
				stats[target_name]["catches"] += 1
			"Dodged":
				stats[target_name]["dodge_streak"] += 1
				stats[target_name]["dodges"] += 1
			"Pass":
				stats[thrower_name]["passes"] += 1
			"Hold":
				stats[thrower_name]["holds"] += 1
			"Taunt":
				stats[thrower_name]["taunts"] += 1
			"Dodge":
				stats[thrower_name]["dodges"] += 1

		# Streak snapshots
		stats[thrower_name]["hit_streak"] = max(stats[thrower_name]["hit_streak"], round_rec.thrower_hit_streak)
		stats[target_name]["catch_streak"] = max(stats[target_name]["catch_streak"], round_rec.target_catch_streak)
		stats[target_name]["dodge_streak"] = max(stats[target_name]["dodge_streak"], round_rec.target_dodge_streak)
		stats[target_name]["clutch_streak"] = max(stats[target_name]["clutch_streak"], round_rec.target_clutch_streak)

	# Peak possession (dual-ball awareness) and elimination count
	for p in players:
		stats[p.name]["ball_control"] = max(stats[p.name]["ball_control"], p.max_ball_count)
		stats[p.name]["times_eliminated"] = p.times_eliminated

	return stats

func print_match_summary(summary: Dictionary) -> void:
	print("\n📊 MATCH SUMMARY")
	print("────────────────────────────")

	for player_name in summary.keys():
		var s = summary[player_name]
		print("👤 %s" % player_name)
		print("   🎯 Hits: %d | 🧤 Catches: %d | 🌀 Dodges: %d" % [s["hits"], s["catches"], s["dodges"]])
		print("   🤝 Passes: %d | ⏳ Holds: %d | 💬 Taunts: %d" % [s["passes"], s["holds"], s["taunts"]])
		print("   🔥 Hit Streak: %d | 🧠 Clutch Streak: %d" % [s["hit_streak"], s["clutch_streak"]])
		print("   🏐 Max Balls Held: %d | 💀 Times Eliminated: %d" % [s["ball_control"], s["times_eliminated"]])
		print("────────────────────────────")

func calculate_impact_score(stats: Dictionary) -> int:
	return (
		stats["hits"] * 5 +
		stats["catches"] * 4 +
		stats["dodges"] * 3 +
		stats["passes"] * 2 +
		stats["holds"] * 1 +
		stats["taunts"] * 1 +
		stats["hit_streak"] * 2 +
		stats["clutch_streak"] * 3 +
		stats.get("ball_control", 0) * 1
	)

func detect_mvp(summary: Dictionary) -> Dictionary:
	var best := { "name": "", "score": -1 }
	for player_name in summary.keys():
		var score = calculate_impact_score(summary[player_name])
		if score > best["score"]:
			best = { "name": player_name, "score": score }
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
		for player_name in match_summary.keys():
			if not series_stats.has(player_name):
				series_stats[player_name] = match_summary[player_name].duplicate()
			else:
				for key in match_summary[player_name].keys():
					series_stats[player_name][key] += match_summary[player_name][key]

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

func save_report_to_json(report: Dictionary) -> String:
	var result = JSON.stringify(report, "\t")  # Pretty-print with tabs
	return result

func load_report_from_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var result = json.parse(content)
		if result.error == OK:
			return result.result
		else:
			print("❌ JSON parse error: %s" % result.error_string)
	else:
		print("❌ Failed to open file: %s" % path)
	return {}

# 🏃 Ball pickups (hooks for safe/contested/exposed zones)
func attempt_ball_pickup(player: Player, zone: String) -> bool:
	if player.ball_count >= player.max_balls:
		return false

	match zone:
		"safe":
			player.give_ball(1)
			return true
		"contested":
			var roll = player.stats["instinct"] + rng.randi_range(0, 5)
			if roll >= 4:
				player.give_ball(1)
				return true
			return false
		"exposed":
			var roll_exposed = player.stats["instinct"] + player.stats["hustle"] + rng.randi_range(0, 7)
			if roll_exposed >= 8:
				player.give_ball(1)
				return true
			return false
		_:
			return false
