extends Node2D
class_name GameUI

var match_engine: MatchEngine
var players: Array = []
var screen_width: float = 1200
var screen_height: float = 400
var court_margin: float = 50
var court_left: float = court_margin
var court_right: float = screen_width - court_margin
var court_top: float = court_margin
var court_bottom: float = screen_height - court_margin

var ui_font: Font
var ui_font_size: int = 14

# Live console for match output
var console_lines: Array = []
var max_console_lines: int = 8

# Player visual positions (for court display)
var player_positions: Dictionary = {}

func _ready():
	set_process(false)  # Will start after match init
	ui_font = ThemeDB.fallback_font
	ui_font_size = 14
	
	# Create match engine
	match_engine = MatchEngine.new()
	
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
	set_process(true)
	print("🎮 Match starting! Watch the court above.")
	
	if players.is_empty():
		print("❌ No players initialized!")
		add_console_line("❌ Error: No players!")
		return
	
	match_engine.simulate_opening_rush(players)
	add_console_line("Opening rush complete!")
	
	var winner = match_engine.simulate_match(360.0, 0.5)
	var summary = match_engine.generate_match_summary(match_engine.rounds)
	var mvp = match_engine.detect_mvp(summary)
	
	add_console_line("🏁 Match Over! %s wins!" % winner)
	add_console_line("🏅 MVP: %s" % mvp["name"])
	
	match_engine.print_match_summary(summary)

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
	draw_rect(Rect2(court_left, court_bottom + 20, court_right - court_left, 150), Color.BLACK.lerp(Color.DARK_SLATE_GRAY, 0.5))
	var console_y = court_bottom + 30
	for line in console_lines:
		draw_string(ui_font, Vector2(court_left + 10, console_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, ui_font_size)
		console_y += 18
	
	# Title & instructions
	draw_string(ui_font, Vector2(court_left, 10), "🏐 DODGEBALL SIM - Live View (Red vs Blue)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

func _process(_delta):
	# Console is populated by match callbacks via add_console_line
	pass
