extends Node
class_name CampaignManager

# Tracks season-level data across multiple matches and series.
# Player profiles accumulate stats over time and persist across matches.

var season_number: int = 1
var teams: Dictionary = {}         # team_name → { players: Array, wins: int, losses: int }
var player_profiles: Dictionary = {}  # player_name → profile dict
var match_results: Array = []      # Log of every completed match this season

# Register a team for this season
func register_team(team_name: String, players: Array) -> void:
	teams[team_name] = {
		"players": players,
		"wins": 0,
		"losses": 0,
		"draws": 0
	}

# Call this after each match completes with the match summary from MatchEngine
func record_match(winner: String, match_summary: Dictionary, match_seed: int) -> void:
	# Log the result
	match_results.append({
		"season": season_number,
		"winner": winner,
		"seed": match_seed
	})

	# Update team win/loss record
	for team_name in teams.keys():
		if winner == team_name:
			teams[team_name]["wins"] += 1
		elif winner == "Draw":
			teams[team_name]["draws"] += 1
		else:
			teams[team_name]["losses"] += 1

	# Accumulate per-player stats into profiles
	for player_name in match_summary.keys():
		_ensure_profile(player_name)
		var profile = player_profiles[player_name]
		var s = match_summary[player_name]
		profile["total_hits"] += s.get("hits", 0)
		profile["total_catches"] += s.get("catches", 0)
		profile["total_dodges"] += s.get("dodges", 0)
		profile["total_passes"] += s.get("passes", 0)
		profile["matches_played"] += 1
		profile["peak_hit_streak"] = max(profile["peak_hit_streak"], s.get("hit_streak", 0))
		profile["peak_clutch_streak"] = max(profile["peak_clutch_streak"], s.get("clutch_streak", 0))

# Bump MVP fame after a match — call with the name from detect_mvp()
func award_mvp(player_name: String) -> void:
	_ensure_profile(player_name)
	player_profiles[player_name]["mvp_count"] += 1
	player_profiles[player_name]["fame"] += 5

func get_profile(player_name: String) -> Dictionary:
	_ensure_profile(player_name)
	return player_profiles[player_name]

func _ensure_profile(player_name: String) -> void:
	if not player_profiles.has(player_name):
		player_profiles[player_name] = {
			"matches_played": 0,
			"total_hits": 0,
			"total_catches": 0,
			"total_dodges": 0,
			"total_passes": 0,
			"peak_hit_streak": 0,
			"peak_clutch_streak": 0,
			"mvp_count": 0,
			"fame": 0
		}
