extends Node
class_name CampaignManager

var campaigns := {}

func create_campaign(name: String) -> void:
	campaigns[name] = {
		"start_date": Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system()),
		"teams": {},
		"series": [],
		"player_profiles": {}
	}

func add_team_to_campaign(campaign_name: String, team_name: String, players: Array) -> void:
	if campaigns.has(campaign_name):
		campaigns[campaign_name]["teams"][team_name] = {
			"players": players,
			"fame": 0,
			"mvp_count": 0
	}

func add_series_to_campaign(campaign_name: String, series_log: Array, series_report: Dictionary) -> void:
	if campaigns.has(campaign_name):
		campaigns[campaign_name]["series"].append({
			"log": series_log,
			"report": series_report
		})

		# 🔹 Update player profiles
		for name in series_report.keys():
			ensure_player_profile(campaign_name, name)
			var profile = campaigns[campaign_name]["player_profiles"][name]
			var stats = series_report[name]

			profile["total_hits"] += stats["hits"]
			profile["total_catches"] += stats["catches"]
			profile["total_dodges"] += stats["dodges"]
			profile["total_revives"] += stats["revives"]
			profile["clutch_streaks"].append(stats["clutch_streak"])
			profile["hit_streaks"].append(stats["hit_streak"])

		# 🔹 MVP Fame Boost
		var mvp_name = series_report["mvp"]
		ensure_player_profile(campaign_name, mvp_name)
		campaigns[campaign_name]["player_profiles"][mvp_name]["total_mvp"] += 1
		campaigns[campaign_name]["player_profiles"][mvp_name]["fame"] += 5

func ensure_player_profile(campaign_name: String, player_name: String) -> void:
	if not campaigns[campaign_name]["player_profiles"].has(player_name):
		campaigns[campaign_name]["player_profiles"][player_name] = {
			"total_mvp": 0,
			"total_hits": 0,
			"total_catches": 0,
			"total_dodges": 0,
			"total_revives": 0,
			"clutch_streaks": [],
			"hit_streaks": [],
			"fame": 0
	}
