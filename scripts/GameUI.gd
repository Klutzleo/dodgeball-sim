extends Node2D
class_name GameUI

var match_engine: MatchEngine
var players: Array = []
var screen_width: float = 1450
var screen_height: float = 950
var court_margin: float = 35
var court_left: float = court_margin
var court_right: float = screen_width - court_margin
var court_top: float = 55  # Leave room for title
var court_bottom: float = 480  # Leave room for console

var ui_font: Font
var ui_font_size: int = 14

# Live console for match output
var console_lines: Array = []
var max_console_lines: int = 15  # Show more lines
var console_scroll: float = 0.0  # Scroll position

# Player visual positions (for court display)
var player_positions: Dictionary = {}

# Real-time match state
var match_running: bool = false
var match_time: float = 0.0
var dev_mode: bool = true  # Set to false for official 6-min halves, true for 2-min halves
var max_match_time: float = 240.0 if dev_mode else 720.0  # 2-min halves (dev) or 6-min halves (official)
var time_step: float = 0.5  # Seconds per simulation step
var accumulated_time: float = 0.0
var user_scrolling: bool = false  # Track if user is manually scrolling
var scroll_idle_time: float = 0.0  # Time since last scroll

func _ready():
	set_process(true)
	ui_font = ThemeDB.fallback_font
	ui_font_size = 14
	
	# Create match engine
	match_engine = MatchEngine.new()
	
	# Set up callback so match logs go to screen
	match_engine.ui_callback = Callable(self, "add_console_line")
	
	# Initialize players
	initialize_teams()
	
	# Set custom window size for visibility
	get_window().size = Vector2i(int(screen_width), int(screen_height))
	
	# Auto-start match after scene loads
	await get_tree().process_frame
	start_match()

func initialize_teams():
	var red_team = []
	var blue_team = []
	
	# Create 6 Red players
	for i in range(6):
		var p = Player.new()
		p.name = "Red%d" % (i + 1)
		p.team = "Red"
		p.archetype = ["Hothead", "Strategist", "Ghost"][i % 3]
		p.stats = {
			"accuracy": 3 + randi() % 3,
			"ferocity": 3 + randi() % 3,
			"instinct": 3 + randi() % 3,
			"hustle": 3 + randi() % 3,
			"hands": 3 + randi() % 3,
			"backbone": 3 + randi() % 3,
		}
		red_team.append(p)
	
	# Create 6 Blue players
	for i in range(6):
		var p = Player.new()
		p.name = "Blue%d" % (i + 1)
		p.team = "Blue"
		p.archetype = ["Hothead", "Strategist", "Ghost"][i % 3]
		p.stats = {
			"accuracy": 3 + randi() % 3,
			"ferocity": 3 + randi() % 3,
			"instinct": 3 + randi() % 3,
			"hustle": 3 + randi() % 3,
			"hands": 3 + randi() % 3,
			"backbone": 3 + randi() % 3,
		}
		blue_team.append(p)
	
	players = red_team + blue_team
	match_engine.players = players
	
	# Calculate static court positions (Red left, Blue right)
	var red_x = court_left + 100
	var blue_x = court_right - 100
	var y_spacing = (court_bottom - court_top) / 6.0
	
	for i in range(6):
		player_positions[red_team[i].name] = Vector2(red_x, court_top + 30 + i * y_spacing)
	for i in range(6):
		player_positions[blue_team[i].name] = Vector2(blue_x, court_top + 30 + i * y_spacing)

func start_match():
	var mode_str = "DEV (2-min halves)" if dev_mode else "OFFICIAL (6-min halves)"
	print("🎮 Match starting! %s..." % mode_str)
	
	if players.is_empty():
		print("❌ No players initialized!")
		add_console_line("❌ Error: No players!")
		return
	
	match_engine.simulate_opening_rush(players)
	add_console_line("Opening rush complete! Match in progress...")
	
	match_running = true
	match_time = 0.0
	accumulated_time = 0.0

func add_console_line(line: String):
	console_lines.append(line)
	if console_lines.size() > max_console_lines:
		console_lines.pop_front()
	queue_redraw()

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
	
	# Console output at bottom
	var console_height = screen_height - court_bottom - 40
	var console_x = court_left
	var console_y_top = court_bottom + 10
	var console_content_width = court_right - court_left - 20
	var console_content_height = console_height - 35
	
	# Background
	draw_rect(Rect2(console_x, console_y_top, court_right - court_left, console_height), Color.BLACK.lerp(Color.DARK_SLATE_GRAY, 0.5))
	draw_rect(Rect2(console_x, console_y_top, court_right - court_left, console_height), Color.WHITE, false, 1.0)
	
	# Title
	draw_string(ui_font, Vector2(console_x + 10, console_y_top + 5), "📋 Match Log", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	
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
	var console_y = console_y_top + 25 - int(console_scroll) % int(line_height)
	
	for i in range(start_line, min(start_line + max_visible_lines + 2, console_lines.size())):
		if i < console_lines.size() and console_y < console_y_top + console_height:
			draw_string(ui_font, Vector2(console_x + 10, console_y), console_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ui_font_size)
			console_y += int(line_height)
	
	# Draw scrollbar
	if total_lines_height > console_content_height:
		var scrollbar_x = court_right - 12
		var scrollbar_width = 8.0
		var scrollbar_height = console_content_height - 2
		var scroll_thumb_height = max(20.0, (console_content_height * console_content_height) / total_lines_height)
		var scroll_thumb_pos = (console_scroll / max_scroll) * (scrollbar_height - scroll_thumb_height)
		
		# Scrollbar track
		draw_rect(Rect2(scrollbar_x, console_y_top + 25, scrollbar_width, scrollbar_height), Color.DARK_GRAY)
		# Scrollbar thumb
		draw_rect(Rect2(scrollbar_x, console_y_top + 25 + scroll_thumb_pos, scrollbar_width, scroll_thumb_height), Color.LIGHT_GRAY)
	
	# Title & instructions
	draw_string(ui_font, Vector2(court_left, 10), "🏐 DODGEBALL SIM - Live View (Red vs Blue)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	
	# Timer display
	var time_str = "⏱️ Time: %.1f / %.0f" % [match_time, max_match_time]
	var status_str = "Match: %s" % ("RUNNING" if match_running else "ENDED")
	draw_string(ui_font, Vector2(court_right - 300, 10), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ui_font, Vector2(court_right - 300, 30), status_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

func _process(delta):
	# Track scroll idle time - auto-scroll to bottom after 3 seconds of inactivity
	if user_scrolling:
		scroll_idle_time += delta
		if scroll_idle_time > 3.0:
			user_scrolling = false
			scroll_idle_time = 0.0
	
	if not match_running:
		return
	
	# Accumulate real time
	accumulated_time += delta
	
	# Step the simulation when enough real time has passed
	while accumulated_time >= time_step and match_time <= max_match_time:
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
	
	# Check time limit
	if match_time >= max_match_time:
		end_match("Draw")
	
	queue_redraw()

func _input(event):
	"""Handle mouse wheel for scrolling"""
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
	
	add_console_line("🏁 Match Over! %s wins!" % winner)
	add_console_line("🏅 MVP: %s" % mvp["name"])
	
	print("\n==================================================")
	print("MATCH COMPLETE")
	print("==================================================")
	match_engine.print_match_summary(summary)
