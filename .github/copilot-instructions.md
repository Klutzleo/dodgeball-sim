# Copilot Instructions

## Project Overview
Godot-based **multiplayer** dodgeball sim featuring real-time action resolution, archetype-driven AI, and narrative match recaps. Core loop: 6v6 teams, 6 balls, reaction timers drive throws/catches/dodges until one team eliminated or time expires. Designed for cross-platform play (desktop, web, mobile).

## Dev Workflow
- **Run/debug**: Open project in Godot 4.5, run `Main.tscn`. No build scripts or test framework; validate via Godot console output and printed logs.
- **Feedback loop**: All gameplay outputs to console with emoji-prefixed timestamps (`⏱️`, `🎯`, `🤝`, etc.). Check terminal for action flow, commentary, and summaries.
- **No external deps**: Pure GDScript, no plugins. Aseprite for sprites (future), but prototype is code-driven.
- **Multiplayer target**: Game is being built for online multiplayer from the ground up. Current sim engine provides the foundation for networked gameplay via Firebase/Supabase sync.

## Architecture
**Core loop**: `MatchEngine.gd` orchestrates everything:
- `simulate_match(max_time, step)`: Time-stepped loop advancing by `step` seconds, calling `simulate_reaction_queue` each tick until win condition or timeout.
- `simulate_reaction_queue(current_time)`: Checks each alive player with balls; fires actions when `reaction_timer <= current_time`.
- **Not turn-based**: Multiple actions can fire same tick; players can throw while targeted. Timer resets to `current_time + base_time - (instinct * modifier) + rng` after each action.
- **Multiplayer design**: Current sim serves as deterministic backend. Player actions will eventually replace AI `choose_action` calls; `MatchRound` logs provide authoritative state for sync.

**Data flow**: `MatchEngine` → `Player` nodes → `MatchRound` resources → summaries → `CampaignManager`:
1. Match runs, creates `MatchRound` entries logged into `rounds[]`
2. `generate_match_summary(rounds)` tallies per-player stats
3. `detect_mvp(summary)` calculates impact scores
4. `simulate_series()` runs best-of-3, accumulates series stats, logs MVPs
5. `CampaignManager.add_series_to_campaign()` aggregates player profiles, fame, MVP counts
6. **Network layer (planned)**: Firebase/Supabase will sync `MatchRound` events, player states, and match results across clients

## Critical Systems

### Stats Contract (Non-Negotiable)
`Player.gd` defines six stats in three pairs:
- **Throw** = `accuracy + ferocity`
- **Dodge** = `instinct + hustle`
- **Catch** = `hands + backbone`

All new mechanics MUST align with these pairs. Thread changes through: `resolve_throw`, `choose_action`, `generate_match_summary`, `calculate_impact_score`.

### Resolution Math (Single-Roll System)
`resolve_throw` rolls once against combined total:
```gdscript
var total = throw_power + dodge_power + catch_power
var roll = rng.randi_range(0, total - 1)
if roll < dodge_power: → "Dodged"
elif roll < dodge_power + catch_power: → "Caught"
else: → "Hit" (eliminate target)
```
**Ball shield bonus**: Holding ball grants +1 dodge (already implemented in `resolve_throw`). Keep consistent if adding dual-ball bonuses.

### Opening Rush
`simulate_opening_rush` ranks players by `hustle + ferocity + rng`, top 6 grab balls, seeds initial `reaction_timer`. Changing ball/player counts? Update this + UI assumptions.

### Archetypes Drive Actions
`choose_action` weights options by archetype + streaks:
- **Hothead**: Favors throw (5), taunt (2), hold (1)
- **Strategist**: Favors pass (4), hold (3), throw (2)
- **Ghost**: Favors dodge (5), taunt (2)
- **Default**: Balanced chaos

**Adding new actions**: Must implement simulator (`simulate_X`), log into `MatchRound`, count in `generate_match_summary`, weight in `calculate_impact_score`.

### Streak System
Per-player counters (`hit_streak`, `dodge_streak`, `catch_streak`, `clutch_streak`) live on `Player`:
- **Clutch detection**: Roll within ±2 of dodge/catch/total cutoffs triggers `clutch_streak++`
- **Reset logic**: Only thrower/target keep streak progress for their outcome; all other players' streaks reset to 0
- **Snapshot**: Streak values stored on `MatchRound` for summaries

### MVP Scoring
`calculate_impact_score` weights:
- Hits: 5 | Catches: 4 | Dodges: 3 | Passes: 2 | Revives: 4
- Holds/Taunts: 1 | Hit streak: 2 | Clutch streak: 3 | Ball control: 1

### State Management
**Between matches/series**: Call `reset_players()` once—it clears streaks, commentary, ball state, timers, `rounds`, `turn_count`. Never duplicate this logic.

## Key Files
- `scripts/MatchEngine.gd`: All match/series logic, simulators, summaries, MVP, JSON persistence
- `scripts/Player.gd`: Stats, streaks, ball possession (max 2), `to_dict()` serialization
- `scripts/MatchRound.gd`: Action log entry (thrower, target, outcome, commentary, power breakdown, streaks)
- `CampaignManager.gd`: Aggregates series into campaigns, tracks player profiles/fame/MVP tallies

## Conventions
- **Commentary templates**: Keyed by `"{outcome}_{archetype}"` with fallback to `"{outcome}_Default"`. Keep emoji/tone consistent with existing strings.
- **Revive ordering**: First eliminated teammate returns (stable ordering). Document if changing priority.
- **Ball pickups (design hooks)**: `attempt_ball_pickup(player, zone)` supports safe/contested/exposed zones with instinct/hustle rolls. Not yet integrated into main loop.
- **JSON persistence**: `save_report_to_json` pretty-prints with tabs; `load_report_from_json` uses Godot `FileAccess`. Extend report shape cautiously, keep loader tolerant.

## Style
- Concise GDScript, emoji for log clarity (`🎯`, `🤝`, `🌀`, `⏳`, `💬`)
- Light comments only when non-obvious
- Print statements use formatting: `"⏱️ %.2f | %s throws at %s → %s" % [time, thrower, target, outcome]`

## Multiplayer Considerations
- **Deterministic sim**: All RNG uses seeded `RandomNumberGenerator` to ensure identical outcomes across clients with same seed
- **Action authority**: `choose_action` is placeholder AI; will be replaced with player input. Keep action simulators (`simulate_throw`, etc.) stateless and replayable
- **State sync points**: `MatchRound` entries are authoritative events. Network layer should transmit these, not individual stat changes
- **Latency design**: Reaction timers provide natural buffer for input lag. Consider predictive client-side actions with server reconciliation
- **Cross-platform**: Godot 4.5 exports to desktop, web (WASM), and mobile. Keep UI/input abstractions platform-agnostic

## Before Making Changes
If modifying ball shield bonus, dual-ball defense, contested pickups, or core resolution math—**flag it first**. These systems cascade through `resolve_throw`, `choose_action`, summaries, and MVP scoring. When adding networked features, ensure all game logic remains deterministic and state changes are logged as `MatchRound` events.
