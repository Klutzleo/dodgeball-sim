extends RefCounted
class_name Archetypes

# 📖 Archetype roster — single source of truth for all archetype data.
# stat_bonus values are added on top of the base random stat roll (base: 3 + rng(0,1)).
# Bonuses: +2 = elite, +1 = strong, 0 = average, -1 = weak, -2 = liability
# Special skill IDs are resolved by MatchEngine._apply_skill().

const ROSTER: Dictionary = {

	"Meathead": {
		"description": "Pure gym energy, zero strategy.",
		"stat_bonus": { "ferocity": 2, "accuracy": 1, "instinct": -1, "backbone": -1, "hustle": 0, "hands": 0 },
		"action_weights_ball":    { "throw": 6, "taunt": 2, "hold": 1 },
		"action_weights_no_ball": { "taunt": 3, "dodge": 2 },
		"special_skill": "protein_rage",
		"skill_charges": -1,  # passive — triggers on revival
		"max_balls_override": -1,  # -1 = use default (2)
		"commentary": {
			"Hit":    "%s hit with the force of someone who definitely skips leg day. %s is out.",
			"Dodged": "%s somehow missed a shot fueled by pure protein and rage.",
			"Caught": "%s caught it mid-flex. Accidental, but effective.",
			"Taunt":  "%s lifted their shirt and pointed at their abs. No one asked."
		}
	},

	"Gamer": {
		"description": "Inhuman reflexes. Zero cardio.",
		"stat_bonus": { "instinct": 2, "hands": 1, "hustle": -2, "ferocity": -1, "accuracy": 0, "backbone": 0 },
		"action_weights_ball":    { "throw": 3, "hold": 3, "pass": 1 },
		"action_weights_no_ball": { "dodge": 5, "hold": 2 },
		"special_skill": "pro_gamer_move",
		"skill_charges": -1,  # passive — dodge boost when holding no ball
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s calculated the optimal trajectory. %s never had a chance.",
			"Dodged": "%s sidestepped with the muscle memory of ten thousand hours.",
			"Caught": "%s caught it without looking up. Impressive or infuriating — unclear.",
			"Taunt":  "%s typed 'gg ez' into the void. No keyboard present."
		}
	},

	"Receptionist": {
		"description": "Has seen worse. Completely unphased.",
		"stat_bonus": { "backbone": 2, "hands": 1, "ferocity": -2, "accuracy": -1, "instinct": 0, "hustle": 0 },
		"action_weights_ball":    { "hold": 4, "pass": 3, "throw": 1 },
		"action_weights_no_ball": { "dodge": 2, "hold": 3 },
		"special_skill": "hold_please",
		"skill_charges": -1,  # passive — max_balls = 3
		"max_balls_override": 3,
		"commentary": {
			"Hit":    "%s was eliminated. They've had worse Mondays.",
			"Dodged": "%s sidestepped without breaking eye contact. Terrifying.",
			"Caught": "%s caught it one-handed while mentally drafting a strongly worded email.",
			"Taunt":  "%s put a caller on hold, turned around, and stared directly at the enemy."
		}
	},

	"Emo Kid": {
		"description": "Would rather be anywhere else.",
		"stat_bonus": { "instinct": 1, "hustle": 1, "ferocity": -2, "accuracy": -2, "hands": 0, "backbone": 0 },
		"action_weights_ball":    { "throw": 2, "hold": 2, "taunt": 1 },
		"action_weights_no_ball": { "dodge": 5, "taunt": 2 },
		"special_skill": "leave_me_alone",
		"skill_charges": -1,  # passive — dodge spikes after 3 targets
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s got hit. They expected this. They expect everything bad.",
			"Dodged": "%s dodged with the grace of someone who has practiced disappearing.",
			"Caught": "%s caught it, looked at it, then looked at the sky.",
			"Taunt":  "%s sighed loudly. It echoed."
		}
	},

	"PE Teacher": {
		"description": "Fundamentally sound. Knees are shot.",
		"stat_bonus": { "accuracy": 2, "backbone": 1, "hustle": -2, "instinct": 0, "ferocity": 0, "hands": 0 },
		"action_weights_ball":    { "throw": 4, "hold": 3, "pass": 2 },
		"action_weights_no_ball": { "dodge": 3, "hold": 2 },
		"special_skill": "fundamentals",
		"skill_charges": -1,  # passive — always targets weakest opponent
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s called the angle, set their feet, and delivered. %s is out.",
			"Dodged": "%s pivoted properly. Old habits.",
			"Caught": "%s caught it with textbook form and immediately corrected their own posture.",
			"Taunt":  "%s blew a whistle that appeared from nowhere. 'That's a foul.'"
		}
	},

	"Influencer": {
		"description": "Playing for the highlight reel.",
		"stat_bonus": { "ferocity": 1, "instinct": 1, "hands": -2, "backbone": -1, "accuracy": 0, "hustle": 0 },
		"action_weights_ball":    { "throw": 3, "taunt": 4, "hold": 1 },
		"action_weights_no_ball": { "taunt": 4, "dodge": 2 },
		"special_skill": "for_the_content",
		"skill_charges": -1,  # passive — taunts stack throw bonus
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s landed the throw at the perfect angle for their ring light. %s is out.",
			"Dodged": "%s ducked and immediately checked their angles.",
			"Caught": "%s caught it and held it up for the camera that isn't there.",
			"Taunt":  "%s struck a pose. Someone in the bleachers actually clapped."
		}
	},

	"Intern": {
		"description": "Terrified. Running on cortisol.",
		"stat_bonus": { "hustle": 2, "accuracy": -2, "backbone": -2, "ferocity": 0, "instinct": 0, "hands": 0 },
		"action_weights_ball":    { "throw": 2, "pass": 3, "hold": 2 },
		"action_weights_no_ball": { "dodge": 4, "hold": 2 },
		"special_skill": "please_dont_fire_me",
		"skill_charges": -1,  # passive — stat surge when last alive
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s threw with the shaking hands of someone who just got Slacked by their manager. %s is out.",
			"Dodged": "%s dove out of the way, apologized, then dove again.",
			"Caught": "%s caught it by accident while flinching.",
			"Taunt":  "%s said 'I just wanted to say I'm a huge fan of your work.'"
		}
	},

	"Coach's Kid": {
		"description": "Unearned confidence. Mediocre talent.",
		"stat_bonus": { "backbone": 2, "accuracy": -1, "instinct": -1, "ferocity": 0, "hustle": 0, "hands": 0 },
		"action_weights_ball":    { "throw": 3, "hold": 4, "taunt": 2 },
		"action_weights_no_ball": { "dodge": 2, "hold": 3, "taunt": 2 },
		"special_skill": "participation_trophy",
		"skill_charges": 1,  # one free revival per match
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s threw it wrong but it worked anyway. %s is out. Dad would be proud.",
			"Dodged": "%s dodged on instinct, then looked around to make sure someone saw.",
			"Caught": "%s caught it and immediately pointed at the bench like they planned it.",
			"Taunt":  "%s said 'My dad says I'm the best one out here.' Unprompted."
		}
	},

	"Yoga Mom": {
		"description": "Suspiciously flexible. Annoyingly calm.",
		"stat_bonus": { "instinct": 2, "backbone": 1, "ferocity": -2, "accuracy": -1, "hustle": 0, "hands": 0 },
		"action_weights_ball":    { "hold": 3, "throw": 2, "pass": 2 },
		"action_weights_no_ball": { "dodge": 5, "hold": 2 },
		"special_skill": "flow_state",
		"skill_charges": -1,  # passive — dodge streak bonus applied faster
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s released the ball with a deep exhale. %s is out. Namaste.",
			"Dodged": "%s flowed around the ball like water around a stone.",
			"Caught": "%s caught it mid-warrior-pose without losing her balance.",
			"Taunt":  "%s closed their eyes, breathed deeply, and said 'I see you.'"
		}
	},

	"Soccer Mom": {
		"description": "Spent 12 years on the sideline. Now it's her turn.",
		"stat_bonus": { "ferocity": 2, "hustle": 1, "backbone": 1, "accuracy": -1, "hands": -2, "instinct": 0 },
		"action_weights_ball":    { "throw": 5, "taunt": 3, "hold": 1 },
		"action_weights_no_ball": { "taunt": 3, "dodge": 2, "hold": 1 },
		"special_skill": "i_volunteer",
		"skill_charges": -1,  # passive — always wins opening rush
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s has been waiting twelve years to do that. %s is out.",
			"Dodged": "%s sidestepped and immediately demanded to speak to someone.",
			"Caught": "%s caught it and glared at the referee on principle.",
			"Taunt":  "%s yelled 'YOU WERE WIDE OPEN' at a player on her own team."
		}
	},

	"Retiree": {
		"description": "68 years old. Been playing since before you were born.",
		"stat_bonus": { "accuracy": 2, "backbone": 1, "hustle": -2, "ferocity": -1, "instinct": 0, "hands": 0 },
		"action_weights_ball":    { "throw": 3, "hold": 4, "pass": 1 },
		"action_weights_no_ball": { "hold": 3, "dodge": 2 },
		"special_skill": "back_in_my_day",
		"skill_charges": 1,  # one auto-catch per match
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s has been throwing like that since 1987. %s is out.",
			"Dodged": "%s didn't dodge so much as refuse to be in the ball's way.",
			"Caught": "%s caught it and nodded slowly. They've seen worse.",
			"Taunt":  "%s said 'Back in my day, we played in the parking lot. No lines.'"
		}
	},

	"Veteran": {
		"description": "Discipline and pain tolerance.",
		"stat_bonus": { "backbone": 2, "accuracy": 1, "hustle": -1, "instinct": 0, "ferocity": 0, "hands": 0 },
		"action_weights_ball":    { "throw": 4, "pass": 3, "hold": 2 },
		"action_weights_no_ball": { "dodge": 3, "hold": 2 },
		"special_skill": "no_man_left_behind",
		"skill_charges": -1,  # passive — ferocity bonus per eliminated teammate
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s locked in and delivered. %s is out. Mission complete.",
			"Dodged": "%s moved like they've done this before. Because they have.",
			"Caught": "%s secured the ball. No wasted motion.",
			"Taunt":  "%s said nothing. Just stared. It was worse than yelling."
		}
	},

	"Boy/Girl Scout": {
		"description": "Absurdly prepared for everything.",
		"stat_bonus": { "hands": 2, "instinct": 1, "ferocity": -1, "accuracy": 0, "hustle": 0, "backbone": 0 },
		"action_weights_ball":    { "pass": 4, "throw": 3, "hold": 2 },
		"action_weights_no_ball": { "dodge": 3, "hold": 2 },
		"special_skill": "always_prepared",
		"skill_charges": -1,  # passive — starts with extra ball
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s had already identified the optimal target and release angle. %s is out.",
			"Dodged": "%s had mapped the ball's trajectory before it left the hand.",
			"Caught": "%s caught it. They brought a glove just in case.",
			"Taunt":  "%s handed the opponent a first aid kit, just to be safe."
		}
	},

	"Track Kid": {
		"description": "Runs a 4.4. Never stops moving.",
		"stat_bonus": { "hustle": 3, "instinct": 1, "ferocity": -1, "accuracy": -1, "hands": -1, "backbone": 0 },
		"action_weights_ball":    { "throw": 4, "pass": 3, "hold": 1 },
		"action_weights_no_ball": { "dodge": 4, "hold": 1 },
		"special_skill": "lap_everyone",
		"skill_charges": -1,  # passive — priority on loose ball pickups
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s released the ball mid-sprint without slowing down. %s is out.",
			"Dodged": "%s was already somewhere else before the ball arrived.",
			"Caught": "%s ran down the ball and caught it before it bounced twice.",
			"Taunt":  "%s lapped the court twice during a timeout. No one told them to stop."
		}
	},

	"Black Friday Doorbuster": {
		"description": "Has survived worse. A dodgeball court is practically a spa day.",
		"stat_bonus": { "hustle": 2, "ferocity": 1, "backbone": -2, "instinct": 0, "accuracy": 0, "hands": 0 },
		"action_weights_ball":    { "throw": 4, "hold": 2, "taunt": 1 },
		"action_weights_no_ball": { "dodge": 3, "hold": 2, "taunt": 1 },
		"special_skill": "doorbuster_deal",
		"skill_charges": -1,  # passive — guaranteed first pickup on any dropped ball
		"max_balls_override": -1,
		"commentary": {
			"Hit":    "%s got to the ball first. As always. %s is out.",
			"Dodged": "%s ducked under the throw and kept moving toward the next objective.",
			"Caught": "%s snatched it out of the air like a marked-down flatscreen.",
			"Taunt":  "%s elbowed past two teammates to get to the front. Instinct."
		}
	}
}

# Returns the archetype data dict, or an empty dict if not found
static func get_data(archetype_name: String) -> Dictionary:
	return ROSTER.get(archetype_name, {})

# Returns all archetype names as an array
static func all_names() -> Array:
	return ROSTER.keys()
