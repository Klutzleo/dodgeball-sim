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
