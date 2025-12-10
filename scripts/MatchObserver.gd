extends Node
class_name MatchObserver

var ui: Node  # Reference to GameUI

func _init(ui_ref: Node):
	ui = ui_ref

func on_round_complete(match_round: MatchRound):
	"""Called after each action resolves"""
	var msg = "⏱️ %.1f | %s → %s: %s" % [match_round.match_time, match_round.thrower.name, match_round.target.name, match_round.outcome]
	ui.add_console_line(msg)

func on_player_eliminated(player: Player):
	"""Called when a player is eliminated"""
	ui.add_console_line("💀 %s eliminated!" % player.name)

func on_player_revived(player: Player):
	"""Called when a player revives"""
	ui.add_console_line("🔄 %s revived!" % player.name)

func on_match_end(winner: String):
	"""Called when match ends"""
	ui.add_console_line("🏁 %s wins!" % winner)
