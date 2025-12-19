extends Node
class_name MatchEngine

# 🧩 Core State
var players: Array = []
var rounds: Array = []
var turn_count: int = 0
var rng := RandomNumberGenerator.new()
var loose_balls: int = 0  # total (for UI/backward compatibility)
var loose_balls_red: int = 0
var loose_balls_blue: int = 0
const TOTAL_BALLS: int = 6
const DUAL_BALL_DEFENSE_ENABLED: bool = false
var use_fixed_seed: bool = false
var match_seed: int = 0
var player_positions: Dictionary = {}

# 🧩 UI Callback for live logging
var ui_callback: Callable = Callable()  # Will be set by GameUI
var ball_spawn_callback: Callable = Callable()  # For visual ball trajectories

func log_action(msg: String):
	"""Log action to console and UI if callback is set"""
	print(msg)
	if ui_callback.is_valid():
		ui_callback.call(msg)

# 🎲 Seeding controls
func set_seed(seed: int) -> void:
	use_fixed_seed = true
	match_seed = seed

func clear_seed() -> void:
	use_fixed_seed = false

# 📍 Position sync (from GameUI)
func set_player_position(name: String, pos: Vector2) -> void:
	player_positions[name] = pos

func prepare_match_rng() -> void:
	# Always set an explicit seed so we can log/replay
	if use_fixed_seed:
		rng.seed = match_seed
	else:
		match_seed = int(Time.get_unix_time_from_system())
		rng.seed = match_seed
	print("🎲 Match seed set: %d" % match_seed)

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

	# No one can take it right now; track as loose on the preferred side (with small bounce chance)
	_add_loose_balls(preferred_team, 1, 0.08)

func rebalance_balls():
	var on_players = 0
	for p in players:
		on_players += p.ball_count
	var missing = TOTAL_BALLS - (on_players + loose_balls)
	if missing > 0:
		# Split missing balls evenly to both sides (favor Red if odd)
		var half = missing / 2
		var extra = missing % 2
		_add_loose_balls("Red", half + extra)
		_add_loose_balls("Blue", half)

	if loose_balls <= 0:
		return

	# Distribute side-specific loose balls only to that side's eligible players
	loose_balls_red = _rebalance_side("Red", loose_balls_red)
	loose_balls_blue = _rebalance_side("Blue", loose_balls_blue)
	loose_balls = loose_balls_red + loose_balls_blue

func _add_loose_balls(team: String, count: int, bounce_chance: float = 0.0) -> void:
	if count <= 0:
		return
	var target_team = team
	if bounce_chance > 0.0 and rng.randf() < bounce_chance:
		target_team = "Red" if team == "Blue" else "Blue"
	if target_team == "Red":
		loose_balls_red += count
	elif target_team == "Blue":
		loose_balls_blue += count
	loose_balls = max(loose_balls_red, 0) + max(loose_balls_blue, 0)

func _rebalance_side(team: String, pool: int) -> int:
	if pool <= 0:
		return pool
	var eligible := players.filter(func(p): return p.alive and p.team == team and p.ball_count < p.max_balls)
	if eligible.is_empty():
		return pool

	var remaining = pool
	while remaining > 0 and not eligible.is_empty():
		eligible.sort_custom(func(a, b):
			var sa = a.stats["hustle"] + a.stats["instinct"]
			var sb = b.stats["hustle"] + b.stats["instinct"]
			return sb - sa
		)
		var picker: Player = eligible[0]
		picker.give_ball(1)
		remaining -= 1
		# Remove picker if full after receiving
		if picker.ball_count >= picker.max_balls:
			eligible.remove_at(0)

	return remaining

# 🧩 Opening Rush
func simulate_opening_rush(player_list: Array) -> void:
	var ball_grab_scores := []

	for p in player_list:
		p.drop_all_balls()
	loose_balls = 0
	loose_balls_red = 0
	loose_balls_blue = 0

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
			# Seed initial reaction timer for non-ball holders so they act later
			var base_time_miss = 7.0
			var modifier_miss = 0.5
			var reaction_time_miss = base_time_miss - (p.stats["instinct"] * modifier_miss) + rng.randf_range(0.5, 1.5)
			p.reaction_timer = reaction_time_miss

# 🧩 Throw Resolution
func resolve_throw(thrower: Player, target: Player, rng_local: RandomNumberGenerator) -> Dictionary:
	var throw_power = thrower.stats["accuracy"] + thrower.stats["ferocity"]
	var dodge_power = target.stats["instinct"] + target.stats["hustle"]
	var dodge_bonus = 1 if target.ball_count > 0 else 0  # Ball shield bonus
	dodge_power += dodge_bonus
	# Optional dual-ball defense (off by default)
	if DUAL_BALL_DEFENSE_ENABLED and target.ball_count >= 2:
		# Modest extra dodge bonus when holding 2 balls; keep Stats Contract
		dodge_power += 1
	var catch_power = target.stats["hands"] + target.stats["backbone"]

	# Cover bonus: if teammate is ahead (toward midline) in same lane band, add dodge, and add catch if they hold a ball
	var cover_bonus = _get_cover_bonus(target)
	dodge_power += cover_bonus.get("dodge", 0)
	catch_power += cover_bonus.get("catch", 0)
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
		"dodge_bonus": dodge_bonus,
		"cover_dodge_bonus": cover_bonus.get("dodge", 0),
		"cover_catch_bonus": cover_bonus.get("catch", 0)
	}

func _get_cover_bonus(target: Player) -> Dictionary:
	# Requires position sync from GameUI via set_player_position
	if not player_positions.has(target.name):
		return {"dodge": 0, "catch": 0}

	var pos_target: Vector2 = player_positions[target.name]
	var best_cover_dodge = 0
	var best_cover_catch = 0

	for mate in players:
		if mate == target or not mate.alive or mate.team != target.team:
			continue
		if not player_positions.has(mate.name):
			continue
		var pos_mate: Vector2 = player_positions[mate.name]
		var same_lane = abs(pos_mate.y - pos_target.y) < 40.0
		if not same_lane:
			continue
		if target.team == "Red":
			if pos_mate.x > pos_target.x + 8.0:
				best_cover_dodge = 1
				if mate.ball_count > 0:
					best_cover_catch = 1
		elif target.team == "Blue":
			if pos_mate.x < pos_target.x - 8.0:
				best_cover_dodge = 1
				if mate.ball_count > 0:
					best_cover_catch = 1

		# Early exit if both bonuses set
		if best_cover_dodge == 1 and best_cover_catch == 1:
			break

	return {"dodge": best_cover_dodge, "catch": best_cover_catch}

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
		"Caught_Default": "%s snatched it mid-air—possession secured.",
		"Caught_Hothead": "%s lunged and grabbed it—possession flips.",
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

	var template: String = ""
	if templates.has(key):
		template = templates[key]
	else:
		var fallback = "%s_Default" % round_rec.outcome
		if templates.has(fallback):
			template = templates[fallback]
		else:
			return "A moment passes."

	# Count placeholders safely
	var placeholder_count = 0
	var idx = template.find("%s")
	while idx != -1:
		placeholder_count += 1
		idx = template.find("%s", idx + 2)
	# Default names
	var thrower_name = round_rec.thrower.name
	var target_name = round_rec.target.name

	# Build arguments based on outcome and template style
	var args: Array = []
	match round_rec.outcome:
		"Dodged":
			args = [target_name]
		"Caught":
			args = [target_name]
		"Hit":
			if key.ends_with("Hothead"):
				# "%s got smashed—%s brought the heat!" → target, thrower
				args = [target_name, thrower_name]
			elif key.ends_with("Default"):
				# "%s landed the hit—%s is out." → thrower, target
				args = [thrower_name, target_name]
			elif key.ends_with("Ghost"):
				# "%s couldn't escape—caught by the phantom!" → target
				args = [target_name]
			elif key.ends_with("Strategist"):
				# "%s calculated the angle and scored." → thrower
				args = [thrower_name]
			else:
				# Fallback mapping: if two placeholders, use thrower,target else target
				if placeholder_count == 2:
					args = [thrower_name, target_name]
				else:
					args = [target_name]
		_:
			# Other outcomes (Pass, Hold, Taunt, Dodge)
			if placeholder_count == 2:
				args = [thrower_name, target_name]
			else:
				args = [thrower_name]

	# Apply formatting based on placeholder count
	if placeholder_count <= 0:
		return template
	elif placeholder_count == 1:
		return template % args[0]
	else:
		return template % [args[0], args[1]]

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
	var any_action = false

	for p in players:
		if not p.alive:
			continue

		if p.reaction_timer <= current_time:
			var action = choose_action(p)

			# Safeguards / fallbacks
			if action == "throw" and p.ball_count == 0:
				action = "dodge"
			if action == "pass":
				var teammate_pool := players.filter(func(t): return t.alive and t.team == p.team and t != p)
				if p.ball_count == 0 or teammate_pool.size() == 0:
					action = "hold"

			match action:
				"throw":
					simulate_throw(p, current_time)
				"pass":
					simulate_pass(p, current_time)
				"hold":
					simulate_hold(p, current_time)
				"taunt":
					simulate_taunt(p, current_time)
				"dodge":
					simulate_dodge(p, current_time)
				_:
					# Default to hold to keep pacing
					simulate_hold(p, current_time)

			any_action = true

			# Reset reaction timer for actor after any action
			var base_time = 6.0
			var modifier = 0.5
			p.reaction_timer = current_time + base_time - (p.stats["instinct"] * modifier) + rng.randf_range(0.0, 1.0)

	# Delay rebalance so loose balls from actions aren't redistributed in the same tick
	if not any_action:
		rebalance_balls()

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
	round_rec.cover_dodge_bonus = result.get("cover_dodge_bonus", 0)
	round_rec.cover_catch_bonus = result.get("cover_catch_bonus", 0)
	round_rec.commentary = generate_commentary(round_rec)

	match round_rec.outcome:
		"Caught":
			var revived = revive_teammate(target)
			round_rec.revived_player = revived
			# Catcher always keeps the ball
			round_rec.ball_holder_after = target
			target.give_ball(1)
			var revived_msg = " ↩️ %s revived!" % revived.name if revived else " (No one to revive!)"
			log_action("🧤 %s caught the ball!%s" % [target.name, revived_msg])
			# Faster follow-up for catcher
			var base_time_catch = 4.0
			var modifier_catch = 0.5
			target.reaction_timer = current_time + base_time_catch - (target.stats["instinct"] * modifier_catch) + rng.randf_range(0.0, 1.0)
		"Hit":
			# Thrown ball + any held by target drop on target side; tiny bounce chance
			_add_loose_balls(target.team, target_balls_before + 1, 0.05)
			round_rec.ball_holder_after = null
			target.drop_all_balls()
		"Dodged":
			# Missed throw becomes a loose ball on target side; tiny bounce chance
			_add_loose_balls(target.team, 1, 0.05)
			round_rec.ball_holder_after = null
		_:
			_add_loose_balls(target.team, 1, 0.05)
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

	# Spawn visual ball for UI
	if ball_spawn_callback.is_valid():
		ball_spawn_callback.call(p.name, target.name, current_time)

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
	var msg = "🤝 %.2f | %s passed to %s" % [current_time, p.name, receiver.name]
	log_action(msg)
	log_action("   %s" % round_rec.commentary)

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
	var msg_dodge = "🌀 %.2f | %s dodged preemptively" % [current_time, p.name]
	log_action(msg_dodge)
	log_action("   %s" % round_rec.commentary)

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
	var msg_hold = "⏳ %.2f | %s held the ball" % [current_time, p.name]
	log_action(msg_hold)
	log_action("   %s" % round_rec.commentary)

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
	var msg_taunt = "💬 %.2f | %s taunted" % [current_time, p.name]
	log_action(msg_taunt)
	log_action("   %s" % round_rec.commentary)

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
	loose_balls = 0
	loose_balls_red = 0
	loose_balls_blue = 0

func simulate_series():
	var red_wins = 0
	var blue_wins = 0
	var match_number = 1
	var series_stats := {}
	var series_log := []

	while red_wins < 2 and blue_wins < 2:
		reset_players()
		prepare_match_rng()
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
			"impact": match_mvp["score"],
			"seed": match_seed
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
			"impact": entry["impact"],
			"seed": entry.get("seed", 0)
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
