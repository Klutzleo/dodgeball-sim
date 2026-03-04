extends Node2D
class_name GameUI

const Archetypes = preload("res://scripts/Archetypes.gd")

var match_engine: MatchEngine
var players: Array = []
var screen_width: float = 1450
var screen_height: float = 950
var court_margin: float = 24
var court_inner_pad: float = 40
var court_left: float = court_margin
var court_right: float = screen_width - court_margin
var court_top: float = 60  # Leave room for title
var court_bottom: float = 0  # Computed in _ready

var ui_font: Font
var ui_font_size: int = 14

# Live console for match output
var console_lines: Array = []
var max_console_lines: int = 200  # Allow scrolling through many lines
var console_scroll: float = 0.0  # Scroll position

# Player visual positions (for court display)
var player_positions: Dictionary = {}
var player_velocities: Dictionary = {}

# Ball trajectories (cosmetic)
var active_balls: Array = []  # [{start_pos, end_pos, start_time, duration, color}]

# Real-time match state
var match_running: bool = false
var match_time: float = 0.0
var dev_mode: bool = true  # Set to false for official 6-min halves, true for 2-min halves
var max_match_time: float = 240.0 if dev_mode else 720.0  # 2-min halves (dev) or 6-min halves (official)
var time_step: float = 0.5  # Seconds per simulation step
var accumulated_time: float = 0.0
var user_scrolling: bool = false  # Track if user is manually scrolling
var scroll_idle_time: float = 0.0  # Time since last scroll

# Stats overlay panel
var stats_panel: Panel = null
var stats_title: Label = null
var stats_mvp: Label = null
var stats_text: Label = null
var close_button: Button = null
var seed_input: LineEdit = null
var apply_seed_button: Button = null
var pre_seed_input: LineEdit = null
var pre_apply_seed_button: Button = null

func _ready():
	set_process(true)
	ui_font = ThemeDB.fallback_font
	ui_font_size = 14
	
	# Create match engine
	match_engine = MatchEngine.new()
	
	# Set up callback so match logs go to screen
	match_engine.ui_callback = Callable(self, "add_console_line")
	
	# Set up ball spawn callback for visual trajectories
	match_engine.ball_spawn_callback = Callable(self, "spawn_ball")
	
	# Read actual viewport and compute court + console bounds BEFORE positioning players
	var vp_size: Vector2i = get_viewport().get_visible_rect().size
	screen_width = float(vp_size.x)
	screen_height = float(vp_size.y)
	court_left = court_margin
	court_right = screen_width - court_margin
	# Target console height ~ 38% of screen for more room
	var console_target: float = max(320.0, screen_height * 0.38)
	court_top = 110.0
	# Leave enough space for the console; clamp to avoid overlap
	court_bottom = clamp(screen_height - console_target - 12.0, court_top + 240.0, screen_height - 140.0)

	# Ensure window size matches
	get_window().size = Vector2i(int(screen_width), int(screen_height))
	
	# Create stats overlay panel (hidden initially)
	setup_stats_panel()

	# Create pre-match seed controls (always visible)
	setup_pre_match_seed_controls()
	
	# Initialize players after bounds are set so positions land inside the court
	initialize_teams()
	
	# Auto-start match after scene loads
	await get_tree().process_frame
	start_match()

func setup_stats_panel():
	"""Create a hidden stats panel overlay that shows when match ends"""
	# Main panel backdrop
	stats_panel = Panel.new()
	stats_panel.position = Vector2(screen_width / 2 - 300, screen_height / 2 - 250)
	stats_panel.size = Vector2(600, 500)
	stats_panel.visible = false
	add_child(stats_panel)
	
	# VBox layout inside panel
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(560, 460)
	stats_panel.add_child(vbox)
	
	# Title label
	stats_title = Label.new()
	stats_title.text = "🏁 MATCH COMPLETE"
	stats_title.add_theme_font_size_override("font_size", 24)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_title)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer1)
	
	# MVP label
	stats_mvp = Label.new()
	stats_mvp.text = "🏅 MVP: ???"
	stats_mvp.add_theme_font_size_override("font_size", 18)
	stats_mvp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_mvp)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)
	
	# ScrollContainer for stats text
	var scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(560, 340)
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_container)
	
	# Stats text inside scroll container
	stats_text = Label.new()
	stats_text.text = ""
	stats_text.add_theme_font_size_override("font_size", 14)
	stats_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(stats_text)
	
	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer3)
	
	# Close button
	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 40)
	close_button.pressed.connect(_on_close_stats_panel)
	vbox.add_child(close_button)

	# Restart button
	var restart_button = Button.new()
	restart_button.text = "Restart Match"
	restart_button.custom_minimum_size = Vector2(160, 40)
	restart_button.pressed.connect(_on_restart_match)
	vbox.add_child(restart_button)

	# Seed replay controls (HBox: label + input + button)
	var seed_hbox = HBoxContainer.new()
	seed_hbox.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(seed_hbox)

	var seed_label = Label.new()
	seed_label.text = "Seed:"
	seed_label.add_theme_font_size_override("font_size", 14)
	seed_hbox.add_child(seed_label)

	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Enter integer seed"
	seed_input.custom_minimum_size = Vector2(220, 40)
	seed_hbox.add_child(seed_input)

	apply_seed_button = Button.new()
	apply_seed_button.text = "Replay with Seed"
	apply_seed_button.custom_minimum_size = Vector2(160, 40)
	apply_seed_button.pressed.connect(_on_apply_seed_replay)
	seed_hbox.add_child(apply_seed_button)

func setup_pre_match_seed_controls():
	"""Top-of-screen controls to set seed and restart immediately"""
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(court_left + 10, 62)
	hbox.custom_minimum_size = Vector2(520, 36)
	add_child(hbox)

	var label = Label.new()
	label.text = "Seed:"
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)

	pre_seed_input = LineEdit.new()
	pre_seed_input.placeholder_text = "Enter integer seed"
	pre_seed_input.custom_minimum_size = Vector2(220, 32)
	hbox.add_child(pre_seed_input)

	pre_apply_seed_button = Button.new()
	pre_apply_seed_button.text = "Set Seed + Restart"
	pre_apply_seed_button.custom_minimum_size = Vector2(180, 32)
	pre_apply_seed_button.pressed.connect(_on_apply_seed_pre_match)
	hbox.add_child(pre_apply_seed_button)

func initialize_teams():
	var red_team = []
	var blue_team = []
	var all_archetypes = Archetypes.all_names()

	# Create 6 Red players
	for i in range(6):
		var p = Player.new()
		p.name = "Red%d" % (i + 1)
		p.team = "Red"
		p.archetype = all_archetypes[i % all_archetypes.size()]
		_apply_archetype(p)
		red_team.append(p)

	# Create 6 Blue players
	for i in range(6):
		var p = Player.new()
		p.name = "Blue%d" % (i + 1)
		p.team = "Blue"
		# Offset so Blue doesn't mirror Red's archetype order
		p.archetype = all_archetypes[(i + 5) % all_archetypes.size()]
		_apply_archetype(p)
		blue_team.append(p)
	
	players = red_team + blue_team
	match_engine.players = players
	
	# Calculate static court positions (Red left, Blue right)
	var red_x = court_left + 100
	var blue_x = court_right - 100
	var y_spacing = (court_bottom - court_top - 2.0 * court_inner_pad) / 6.0
	
	for i in range(6):
		var pos = Vector2(red_x, court_top + court_inner_pad + i * y_spacing)
		player_positions[red_team[i].name] = pos
		player_velocities[red_team[i].name] = Vector2.ZERO
	for i in range(6):
		var pos_b = Vector2(blue_x, court_top + court_inner_pad + i * y_spacing)
		player_positions[blue_team[i].name] = pos_b
		player_velocities[blue_team[i].name] = Vector2.ZERO

# Applies archetype stat bonuses, skill, and max_balls to a freshly created player.
# Base roll is 3 + randi(0,1) giving 3-4, then archetype bonus applied and clamped 1-7.
func _apply_archetype(p: Player) -> void:
	var data = Archetypes.get_data(p.archetype)
	if data.is_empty():
		push_warning("Unknown archetype: %s" % p.archetype)
		return

	var bonus: Dictionary = data.get("stat_bonus", {})
	for stat in ["accuracy", "ferocity", "instinct", "hustle", "hands", "backbone"]:
		var base_roll = 3 + randi() % 2  # 3-4
		p.stats[stat] = clamp(base_roll + bonus.get(stat, 0), 1, 7)

	# Apply max_balls override if archetype defines one (e.g. Receptionist holds 3)
	var max_override: int = data.get("max_balls_override", -1)
	if max_override > 0:
		p.max_balls = max_override

	# Wire up the special skill and initial charges
	p.special_skill = data.get("special_skill", "")
	p.skill_charges = data.get("skill_charges", -1)

func start_match():
	var mode_str = "DEV (2-min halves)" if dev_mode else "OFFICIAL (6-min halves)"
	print("🎮 Match starting! %s..." % mode_str)
	
	if players.is_empty():
		print("❌ No players initialized!")
		add_console_line("❌ Error: No players!")
		return

	# Baseline team totals for Throw/Dodge/Catch
	var red_throw = 0
	var red_dodge = 0
	var red_catch = 0
	var blue_throw = 0
	var blue_dodge = 0
	var blue_catch = 0
	for p in players:
		var t = p.stats["accuracy"] + p.stats["ferocity"]
		var d = p.stats["instinct"] + p.stats["hustle"]
		var c = p.stats["hands"] + p.stats["backbone"]
		if p.team == "Red":
			red_throw += t
			red_dodge += d
			red_catch += c
		else:
			blue_throw += t
			blue_dodge += d
			blue_catch += c
	add_console_line("Baseline — Red: Throw %d | Dodge %d | Catch %d" % [red_throw, red_dodge, red_catch])
	add_console_line("Baseline — Blue: Throw %d | Dodge %d | Catch %d" % [blue_throw, blue_dodge, blue_catch])

	# Prepare RNG (fixed seed if set, else time-derived)
	match_engine.prepare_match_rng()
	add_console_line("Seed — %d" % match_engine.match_seed)

	match_engine.simulate_opening_rush(players)
	add_console_line("Opening rush complete! Match in progress...")
	
	match_running = true
	match_time = 0.0
	accumulated_time = 0.0

func _restart_match(seed_val: int = -1) -> void:
	if stats_panel:
		stats_panel.visible = false
	if seed_val >= 0:
		match_engine.set_seed(seed_val)
		add_console_line("🎲 Fixed seed set → %d" % seed_val)
	match_engine.reset_players()
	match_time = 0.0
	accumulated_time = 0.0
	start_match()

func _on_restart_match():
	_restart_match()

func _on_apply_seed_replay():
	var seed_text = seed_input.text.strip_edges()
	if seed_text == "":
		add_console_line("⚠️ Please enter a numeric seed.")
		return
	_restart_match(int(seed_text))

func _on_apply_seed_pre_match():
	var seed_text = pre_seed_input.text.strip_edges()
	if seed_text == "":
		add_console_line("⚠️ Please enter a numeric seed.")
		return
	_restart_match(int(seed_text))

func add_console_line(line: String):
	console_lines.append(line)
	if console_lines.size() > max_console_lines:
		console_lines.pop_front()
	queue_redraw()

func spawn_ball(thrower_name: String, target_name: String, throw_time: float) -> void:
	var start_pos = player_positions.get(thrower_name, Vector2.ZERO)
	var end_pos = player_positions.get(target_name, Vector2.ZERO)
	if start_pos == Vector2.ZERO or end_pos == Vector2.ZERO:
		print("⚠️ Ball spawn failed: invalid positions for %s → %s" % [thrower_name, target_name])
		return
	
	# Flight duration: 1.0 second (increased from 0.4 for visibility across simulation steps)
	var duration = 1.0
	var ball_color = Color.ORANGE
	
	active_balls.append({
		"start_pos": start_pos,
		"end_pos": end_pos,
		"start_time": throw_time,
		"duration": duration,
		"color": ball_color
	})
	print("🏐 Ball spawned: %s → %s at time %.2f (total active: %d)" % [thrower_name, target_name, throw_time, active_balls.size()])
	queue_redraw()

func _update_player_positions(delta: float) -> void:
	var mid_x = (court_left + court_right) / 2.0
	for p in players:
		if not p.alive:
			continue
		var player_name = p.name
		var pos: Vector2 = player_positions.get(player_name, Vector2.ZERO)
		var vel: Vector2 = _compute_velocity(p, pos, mid_x)
		pos += vel * delta

		# Bounds per team (stay on own half, leave margin)
		if p.team == "Red":
			var min_x = court_left + 60.0
			var max_x = mid_x - 40.0
			if pos.x < min_x:
				pos.x = min_x
				vel.x = abs(vel.x)
			elif pos.x > max_x:
				pos.x = max_x
				vel.x = -abs(vel.x)
		else:
			var min_x_b = mid_x + 40.0
			var max_x_b = court_right - 60.0
			if pos.x < min_x_b:
				pos.x = min_x_b
				vel.x = abs(vel.x)
			elif pos.x > max_x_b:
				pos.x = max_x_b
				vel.x = -abs(vel.x)

		player_positions[player_name] = pos
		player_velocities[player_name] = vel
		# Sync position to match engine for cover logic
		if match_engine:
			match_engine.set_player_position(player_name, pos)

func _update_balls(_delta: float) -> void:
	# Remove expired balls
	var i = 0
	while i < active_balls.size():
		var ball = active_balls[i]
		var elapsed = match_time - ball["start_time"]
		if elapsed > ball["duration"]:
			active_balls.remove_at(i)
		else:
			i += 1

func _compute_velocity(p: Player, pos: Vector2, mid_x: float) -> Vector2:
	var has_ball = p.ball_count > 0
	var hustle = p.stats.get("hustle", 0)
	var ferocity = p.stats.get("ferocity", 0)
	var instinct = p.stats.get("instinct", 0)

	var base_speed = 30.0 + 6.0 * float(hustle)
	if has_ball:
		if ferocity >= instinct:
			base_speed += 4.0
		else:
			base_speed -= 4.0

	var dir = 1.0 if p.team == "Red" else -1.0

	# Bias: without ball, move toward mid; with ball, slightly back unless ferocity is high
	var bias = 0.0
	if not has_ball:
		bias = 1.0
	elif ferocity > instinct:
		bias = 0.3
	else:
		bias = -0.5

	# Apply bias toward or away from midline
	var target_dir = dir * bias
	var vx = base_speed * target_dir

	# Preserve last horizontal direction to avoid getting stuck at bounds
	var prev_vel: Vector2 = player_velocities.get(p.name, Vector2.ZERO)
	if prev_vel.x < 0:
		vx = -abs(vx)
	elif prev_vel.x > 0:
		vx = abs(vx)

	# Loose-ball pursuit: if there are loose balls and capacity, nudge toward midline
	if match_engine and match_engine.loose_balls > 0 and p.ball_count < p.max_balls:
		var dir_to_mid = 0.0
		if abs(mid_x - pos.x) > 1.0:
			dir_to_mid = 1.0 if mid_x > pos.x else -1.0
		var pursuit_vx = 20.0 * dir_to_mid
		vx += pursuit_vx

	return Vector2(vx, 0)

func _draw():
	# Court background
	draw_rect(Rect2(court_left, court_top, court_right - court_left, court_bottom - court_top), Color.DARK_SLATE_GRAY)
	draw_rect(Rect2(court_left, court_top, court_right - court_left, court_bottom - court_top), Color.WHITE, false, 2.0)
	
	# Midcourt line
	var mid_x = (court_left + court_right) / 2.0
	draw_line(Vector2(mid_x, court_top), Vector2(mid_x, court_bottom), Color.WHITE, 1.0)
	
	# Draw players
	for p in players:
		var pos = player_positions.get(p.name, Vector2.ZERO)
		var color = Color.RED if p.team == "Red" else Color.BLUE
		var radius = 12.0
		
		# Eliminate visual: smaller, dimmed circle
		if not p.alive:
			color = color.darkened(0.6)
			radius = 6.0
		
		draw_circle(pos, radius, color)
		
		# Ball indicator (small white circle on player)
		if p.ball_count > 0:
			draw_circle(pos + Vector2(15, -15), 5.0, Color.WHITE)
			if p.ball_count > 1:
				draw_string(ui_font, pos + Vector2(10, -25), "x%d" % p.ball_count, HORIZONTAL_ALIGNMENT_LEFT, -1, ui_font_size)
		
		# Player name/archetype label
		var label = p.name.substr(0, 5)
		draw_string(ui_font, pos + Vector2(-20, 25), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	
	# Draw active balls (on top of players)
	for ball in active_balls:
		var t = (match_time - ball["start_time"]) / ball["duration"]
		if t >= 0.0 and t <= 1.0:
			# Draw trail/trace behind ball
			var trail_segments = 8
			for i in range(trail_segments):
				var trail_t = max(0.0, t - (trail_segments - i) * 0.08)
				if trail_t >= 0.0:
					var trail_pos = ball["start_pos"].lerp(ball["end_pos"], trail_t)
					var alpha = float(i) / float(trail_segments)  # Fade in from 0 to 1
					var trail_color = Color(ball["color"].r, ball["color"].g, ball["color"].b, alpha * 0.6)
					var trail_radius = 6.0 + 2.0 * alpha
					draw_circle(trail_pos, trail_radius, trail_color)
			
			# Draw main ball at current position
			var ball_pos = ball["start_pos"].lerp(ball["end_pos"], t)
			draw_circle(ball_pos, 8.0, ball["color"])
	
	# Console output at bottom (fill remaining space)
	var console_x = court_left
	var console_y_top = court_bottom + 50
	var console_width = court_right - court_left
	# Fill remaining space down to bottom; extend colored background fully without exceeding viewport
	var console_height = max(280.0, screen_height - console_y_top - 2.0)
	var console_content_height = console_height - 52.0
	
	# Background
	# Console background (ensure it reaches bottom without clipping)
	draw_rect(Rect2(console_x, console_y_top, console_width, console_height), Color.BLACK.lerp(Color.DARK_SLATE_GRAY, 0.5))
	draw_rect(Rect2(console_x, console_y_top, console_width, console_height), Color.WHITE, false, 1.0)
	
	# Title
	draw_string(ui_font, Vector2(console_x + 10, console_y_top + 14), "📋 Match Log", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	
	# Calculate scrollable area
	var line_height = 16.0
	var max_visible_lines = int(console_content_height / line_height)
	var total_lines_height = float(console_lines.size() * line_height)
	
	# Limit scroll to valid range
	var max_scroll = max(0.0, total_lines_height - console_content_height)
	console_scroll = clamp(console_scroll, 0.0, max_scroll)
	
	# Auto-scroll to bottom when new lines added (unless user is manually scrolling)
	if not user_scrolling and total_lines_height > console_content_height:
		console_scroll = max_scroll
	
	# Draw console lines with clipping
	var start_line = int(console_scroll / line_height)
	var console_y = console_y_top + 44 - int(console_scroll) % int(line_height)
	
	for i in range(start_line, min(start_line + max_visible_lines + 2, console_lines.size())):
		if i < console_lines.size() and console_y < console_y_top + console_height:
			draw_string(ui_font, Vector2(console_x + 12, console_y), console_lines[i], HORIZONTAL_ALIGNMENT_LEFT, console_width - 28, ui_font_size)
			console_y += int(line_height)
	
	# Draw scrollbar
	if total_lines_height > console_content_height:
		var scrollbar_x = console_x + console_width - 12
		var scrollbar_width = 8.0
		var scrollbar_height = console_content_height - 2
		var scroll_thumb_height = max(20.0, (console_content_height * console_content_height) / total_lines_height)
		var scroll_thumb_pos = (console_scroll / max_scroll) * (scrollbar_height - scroll_thumb_height)
		
		# Scrollbar track
		draw_rect(Rect2(scrollbar_x, console_y_top + 44, scrollbar_width, scrollbar_height), Color.DARK_GRAY)
		# Scrollbar thumb
		draw_rect(Rect2(scrollbar_x, console_y_top + 44 + scroll_thumb_pos, scrollbar_width, scroll_thumb_height), Color.LIGHT_GRAY)
	
	# Title & instructions
	draw_string(ui_font, Vector2(court_left, 24), "🏐 DODGEBALL SIM - Live View (Red vs Blue)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	
	# Timer display
	var time_str = "⏱️ Time: %.1f / %.0f" % [match_time, max_match_time]
	var status_str = "Match: %s" % ("RUNNING" if match_running else "ENDED")
	draw_string(ui_font, Vector2(court_right - 320, 24), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ui_font, Vector2(court_right - 320, 44), status_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

func _process(delta):
	# Track scroll idle time - auto-scroll to bottom after 3 seconds of inactivity
	if user_scrolling:
		scroll_idle_time += delta
		if scroll_idle_time > 3.0:
			user_scrolling = false
			scroll_idle_time = 0.0
	
	if not match_running:
		return

	# Update simple lateral movement for player visuals
	_update_player_positions(delta)
	
	# Update active ball trajectories
	_update_balls(delta)
	
	# Redraw if balls are active
	if active_balls.size() > 0:
		queue_redraw()
	
	# Accumulate real time
	accumulated_time += delta
	
	# Check time limit first
	if match_time >= max_match_time:
		end_match("Draw")
		return
	
	# Step the simulation when enough real time has passed
	while accumulated_time >= time_step and match_time < max_match_time:
		accumulated_time -= time_step
		
		# Run one step of the match
		match_engine.simulate_reaction_queue(match_time)
		match_time += time_step
		
		# Check win condition
		var alive_teams := {}
		for p in players:
			if p.alive:
				alive_teams[p.team] = true
		
		if alive_teams.size() < 2:
			end_match(alive_teams.keys()[0] if alive_teams.size() > 0 else "Draw")
			return
		
		# Check time limit immediately after incrementing
		if match_time >= max_match_time:
			end_match("Draw")
			return
	
	queue_redraw()

func _input(event):
	"""Handle mouse wheel for scrolling"""
	# Skip console scrolling if stats panel is visible (let it handle scroll instead)
	if stats_panel and stats_panel.visible:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			console_scroll += 50
			user_scrolling = true
			scroll_idle_time = 0.0
			queue_redraw()
			get_tree().root.set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			console_scroll = max(0, console_scroll - 50)
			user_scrolling = true
			scroll_idle_time = 0.0
			queue_redraw()
			get_tree().root.set_input_as_handled()

func end_match(winner: String):
	match_running = false
	var summary = match_engine.generate_match_summary(match_engine.rounds)
	var mvp = match_engine.detect_mvp(summary)

	if winner == "Draw":
		add_console_line("🏁 Match Over! Draw.")
	else:
		add_console_line("🏁 Match Over! %s wins!" % winner)
	add_console_line("🏅 MVP: %s" % mvp["name"])
	
	print("\n==================================================")
	print("MATCH COMPLETE")
	print("==================================================")
	match_engine.print_match_summary(summary)
	
	# Show stats overlay panel
	show_stats_panel(winner, mvp, summary)

func show_stats_panel(winner: String, mvp: Dictionary, summary: Dictionary):
	"""Populate and display the stats overlay"""
	if not stats_panel:
		return

	# Set title with winner / draw
	if winner == "Draw":
		stats_title.text = "🏁 DRAW"
	else:
		stats_title.text = "🏁 %s WINS!" % winner.to_upper()
	
	# Set MVP
	stats_mvp.text = "🏅 MVP: %s (Impact: %d)" % [mvp["name"], mvp["score"]]
	
	# Calculate team totals and count alive players
	var red_totals = {"hits": 0, "catches": 0, "dodges": 0, "passes": 0, "alive": 0}
	var blue_totals = {"hits": 0, "catches": 0, "dodges": 0, "passes": 0, "alive": 0}
	
	for player_name in summary.keys():
		var s = summary[player_name]
		var team_totals = red_totals if player_name.begins_with("Red") else blue_totals
		team_totals["hits"] += s["hits"]
		team_totals["catches"] += s["catches"]
		team_totals["dodges"] += s["dodges"]
		team_totals["passes"] += s["passes"]
	
	# Count alive players from match_engine.players
	for p in match_engine.players:
		if p.team == "Red" and p.alive:
			red_totals["alive"] += 1
		elif p.team == "Blue" and p.alive:
			blue_totals["alive"] += 1
	
	# Format summary into readable text
	var stats_lines := []
	stats_lines.append("═══════════════════════════════════")
	stats_lines.append("TEAM SUMMARY")
	stats_lines.append("═══════════════════════════════════")
	stats_lines.append("")
	stats_lines.append("🔴 RED TEAM - 👥 Players Remaining: %d/6" % red_totals["alive"])
	stats_lines.append("   🎯 Hits: %d | 🧤 Catches: %d | 🌀 Dodges: %d" % [red_totals["hits"], red_totals["catches"], red_totals["dodges"]])
	stats_lines.append("   🤝 Passes: %d" % red_totals["passes"])
	stats_lines.append("")
	stats_lines.append("🔵 BLUE TEAM - 👥 Players Remaining: %d/6" % blue_totals["alive"])
	stats_lines.append("   🎯 Hits: %d | 🧤 Catches: %d | 🌀 Dodges: %d" % [blue_totals["hits"], blue_totals["catches"], blue_totals["dodges"]])
	stats_lines.append("   🤝 Passes: %d" % blue_totals["passes"])
	stats_lines.append("")
	stats_lines.append("═══════════════════════════════════")
	stats_lines.append("PLAYER STATS")
	stats_lines.append("═══════════════════════════════════")
	
	for player_name in summary.keys():
		var s = summary[player_name]
		stats_lines.append("")
		stats_lines.append("👤 %s" % player_name)
		stats_lines.append("   🎯 Hits: %d | 🧤 Catches: %d | 🌀 Dodges: %d" % [s["hits"], s["catches"], s["dodges"]])
		stats_lines.append("   🤝 Passes: %d | ⏳ Holds: %d | 💬 Taunts: %d" % [s["passes"], s["holds"], s["taunts"]])
		stats_lines.append("   🔥 Hit Streak: %d | 🧠 Clutch: %d" % [s["hit_streak"], s["clutch_streak"]])
		stats_lines.append("   🏐 Max Balls: %d" % s["ball_control"])
	
	stats_text.text = "\n".join(stats_lines)
	
	# Show the panel
	stats_panel.visible = true

func _on_close_stats_panel():
	"""Hide stats panel and optionally restart match"""
	if stats_panel:
		stats_panel.visible = false
	# Optional: restart match automatically
	# get_tree().reload_current_scene()
