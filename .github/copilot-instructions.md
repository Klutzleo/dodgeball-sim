# Copilot Instructions

## Project Overview
Godot-based **multiplayer** dodgeball sim featuring real-time action resolution, archetype-driven AI, and narrative match recaps. Core loop: 6v6 teams, 6 balls, reaction timers drive throws/catches/dodges until one team eliminated or time expires. Designed for cross-platform play (desktop, web, mobile).

## Dev Workflow
- **Run/debug**: Open project in Godot 4.5, run `Main.tscn`. No build scripts or test framework; validate via Godot console output and printed logs.
- **Feedback loop**: All gameplay outputs to console with emoji-prefixed timestamps (`⏱️`, `🎯`, `🤝`, etc.). Check terminal for action flow, commentary, and summaries.
- **UI**: Live match log console (scrollable) at bottom of screen with auto-scroll. Stats overlay panel pops up on match end with team summaries and player breakdown.
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
**Positional cover bonus**: If a teammate is ahead in the same lane band (within ~40px vertically and slightly forward toward midline), target gains +1 dodge; if that covering teammate holds a ball, target also gains +1 catch. Powered by GameUI positional sync and `_get_cover_bonus()`.

### Opening Rush
`simulate_opening_rush` ranks players by `hustle + ferocity + rng`, top 6 grab balls, seeds initial `reaction_timer`. Changing ball/player counts? Update this + UI assumptions.

### Archetypes Drive Actions
`choose_action` weights options by archetype + streaks:
- **Hothead**: Favors throw (5), taunt (2), hold (1)
- **Strategist**: Favors pass (4), hold (3), throw (2)
- **Ghost**: Favors dodge (5), taunt (2)
- **Default**: Balanced chaos
- **Streak modifiers**: Hit/catch/dodge/clutch streaks ≥2 boost corresponding actions.

### Streak System
Per-player counters (`hit_streak`, `dodge_streak`, `catch_streak`, `clutch_streak`) live on `Player`:
- **Clutch detection**: Roll within ±2 of dodge/catch/total cutoffs triggers `clutch_streak++`
- **Reset logic**: Only thrower/target keep streak progress for their outcome; all other players' streaks reset to 0
- **Snapshot**: Streak values stored on `MatchRound` for summaries

### MVP Scoring
`calculate_impact_score` weights:
- Hits: 5 | Catches: 4 | Dodges: 3 | Passes: 2
- Holds/Taunts: 1 | Hit streak: 2 | Clutch streak: 3 | Ball control: 1
- **Note**: Revives removed as redundant stat (catches = revives + defensive wins without revives)

### State Management
**Between matches/series**: Call `reset_players()` once—it clears streaks, commentary, ball state, timers, `rounds`, `turn_count`, `times_eliminated`. Never duplicate this logic.

### Ball Management & Drops
**Ball accounting**: `TOTAL_BALLS = 6` constant enforced via `loose_balls` counter + player `ball_count`.
- **Drop logic**: When a player is eliminated, their held balls go to `loose_balls` + the thrown ball.
- **Drop bias**: `give_dropped_ball()` biases dropped balls to same team (~92%), with ~8% chance to cross midcourt.
- **Rebalancing**: `rebalance_balls()` distributes loose balls to alive players with capacity, prioritizing by `hustle + instinct`.

### Catch & Revive Mechanics
- **Catch outcome**: When target catches thrower's ball, target gets +1 catch and revives first eliminated teammate (if any exist).
- **Revive order**: `revive_teammate()` returns first eliminated player in order (FIFO on elimination).
- **No teammate to revive**: If all teammates alive when catch occurs, catcher gets ball but no revive happens (catch still counts).
- **Match log**: Catches logged as `"Caught: [catcher] caught the ball! ↩️ [revived] revived!"` or `"(No one to revive!)"` if team full.

### Stats & Counts
- **Hits**: Offensive eliminations (every "Hit" outcome increments thrower's hit count).
- **Catches**: Defensive wins (every "Caught" outcome increments target's catch count), with or without revives.
- **Times Eliminated**: Counter tracking total times a player was eliminated (increments on `eliminate()`, resets with other stats).
- **Players Remaining**: Live count of alive players per team shown in match end stats.

### UI Components
**GameUI.gd provides**:
- **Court display**: Red left, Blue right; shows player circles (dimmed if eliminated), ball indicators.
- **Match log**: Scrollable console at bottom, auto-scrolls unless user scrolling. Wheel events captured by scrolling UI only.
- **Stats panel**: Overlay showing team summary (hits, catches, dodges, passes, players remaining), individual player breakdown, MVP info. Scrollable if content exceeds height.
- **Seed replay controls**: Input + button to set a fixed seed and replay deterministically from the stats overlay.
- **Dev/official halves**: Dev mode uses ~2-minute halves; official uses ~6-minute halves.

## Key Files
- `scripts/MatchEngine.gd`: All match/series logic, simulators, summaries, MVP, JSON persistence
- `scripts/Player.gd`: Stats, streaks, ball possession (max 2), `times_eliminated` counter, `to_dict()` serialization
- `scripts/MatchRound.gd`: Action log entry (thrower, target, outcome, commentary, power breakdown, streaks, revived player)
- `scripts/GameUI.gd`: Real-time match visualization (court, player positions, ball state), match log console, stats overlay panel
- `CampaignManager.gd`: Aggregates series into campaigns, tracks player profiles/fame/MVP tallies

## Conventions
- **Commentary templates**: Keyed by `"{outcome}_{archetype}"` with fallback to `"{outcome}_Default"`. Keep emoji/tone consistent with existing strings.
- **Revive ordering**: First eliminated teammate returns (stable ordering). Document if changing priority.
- **Ball pickups (design hooks)**: `attempt_ball_pickup(player, zone)` supports safe/contested/exposed zones with instinct/hustle rolls. Not yet integrated into main loop.
- **JSON persistence**: `save_report_to_json` pretty-prints with tabs; `load_report_from_json` uses Godot `FileAccess`. Extend report shape cautiously, keep loader tolerant.

### Action Integration (Live)
`simulate_reaction_queue` now calls `choose_action(player)` to dispatch all actions (throw/pass/hold/taunt/dodge) in real time with safe fallbacks:
- **Dispatch logic**: Actions route to `simulate_throw`, `simulate_pass`, `simulate_hold`, `simulate_taunt`, `simulate_dodge` with guards (e.g., no-ball throw → dodge, no teammate pass → hold).
- **Timing**: Each action resets the player's `reaction_timer` using the same base formula. Catchers get a faster follow-up (4.0 base vs 6.0).
- **Non-ball holders**: Opening rush now seeds `reaction_timer` for players who missed the ball grab, so non-throwing actions (pass, hold, taunt, dodge) happen naturally without stalling.
- **Logging**: Pass/hold/taunt/dodge route through `log_action()` so they appear in the on-screen match log.
- **Ball visuals**: Throws still spawn ball trajectories via `ball_spawn_callback` for UI.
- **Delay rebalance**: `rebalance_balls()` runs only on idle ticks (no actions fired), preventing same-tick ball pickup after throws/eliminations.

### Ball Management (Side-Aware)
Loose balls are now tracked per team (`loose_balls_red`, `loose_balls_blue`) with rare bounce chance:
- **Drop origin**: Hits/dodges/misses add loose balls to the target's side (where the action occurred).
- **Bounce chance**: Tiny 5% chance for a ball to bounce cross-court; 8% for legacy `give_dropped_ball()` calls.
- **Rebalance scope**: Distributes Red-side loose balls only to Red players with capacity; Blue-side to Blue. Missing-ball backfill splits evenly.
- **Total tracking**: `loose_balls` still aggregates both pools for UI/backward compatibility.
- **No same-tick pickup**: Loose balls cannot be redistributed in the same tick they're created; must wait for next idle tick.

### Pre-Match Seed Controls
`GameUI.gd` now exposes seed input at top of screen (always visible):
- **Set Seed + Restart button**: Enables fast iteration on match flow without opening the stats overlay; sets seed and immediately restarts.
- **Post-match replay**: Stats overlay also has seed input + "Replay with Seed" for deterministic debugging.

### Draw Display
Match-end UI now displays "Draw" instead of "Draw wins!" when time expires.

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
If modifying ball shield bonus, dual-ball defense, drop bias, catch/revive logic, or core resolution math—**flag it first**. These systems cascade through `resolve_throw`, `choose_action`, summaries, and MVP scoring. When adding networked features, ensure all game logic remains deterministic and state changes are logged as `MatchRound` events.
If altering positional cover: update `_get_cover_bonus()` logic and ensure UI position sync via `set_player_position()` remains deterministic across clients.

## Recent Updates (December 18, 2025)
- **Action Integration**: `choose_action()` now wired into `simulate_reaction_queue()` for live dispatch of throws/passes/holds/taunts/dodges with safe fallbacks.
- **Side-Aware Ball Drops**: Loose balls tracked per team; stay on their side with rare bounce chance (5%). Only redistributed on idle ticks to prevent same-tick pickups.
- **Pre-Match Seed UI**: Added always-visible seed input at top to set seed and restart match immediately.
- **Non-Ball Holder Timers**: Opening rush now seeds reaction timers for players without balls, enabling pass/hold/taunt/dodge actions to happen naturally.
- **Draw Display**: Match-end text now shows "Draw" instead of "Draw wins!" on timeout.
- **Cover Bonuses Logged**: `cover_dodge_bonus` and `cover_catch_bonus` added to `MatchRound` for post-match analytics.
- **Dual-Ball Defense Toggle**: Optional `DUAL_BALL_DEFENSE_ENABLED` (default false) adds +1 dodge when target holds 2 balls; kept within Stats Contract.

## Roadmap (Q1 2026)
- **Log cover bonuses in analytics**: Thread `cover_dodge_bonus` and `cover_catch_bonus` into match summaries or a future analytics panel.
- **Visual ball persistence**: Spawn loose ball sprites on court that track side and removal on pickup.
- **Network sync hooks**: Prototype Firebase/Supabase event sync using `MatchRound` as the authoritative stream; keep RNG seeded.
- **Balance knobs UI**: Add in-app sliders/toggles for base times, modifiers, and archetype weights (dev-only).
- **Dual-ball tuning**: Decide on final defensive bonus when holding 2 balls; A/B test with seed replays before flipping default to true.

## Contribution Workflow
- **Run and verify**: Launch [Main.tscn](../Main.tscn), observe console and stats overlay.
- **Document changes**: For any change to resolution math, ball management, streaks, or UI, update this file in the relevant section.
- **Cross-check**: Ensure updates reflect `resolve_throw`, `_get_cover_bonus`, `simulate_reaction_queue`, `generate_match_summary`, and `calculate_impact_score`.
- **Determinism**: Confirm reproducibility with a fixed seed using the stats overlay seed controls when introducing new features.
