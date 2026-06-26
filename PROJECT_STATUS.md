---
phase: active                  # active / prototyping / paused / complete / archived
priority: high                 # high / medium / low
category: game                 # hardware / game / tool / app / learning / other
progress: 38                   # 0-100 percent to current milestone
focus: "Roster management layer — Creep Sheet, Hustle Points, hire/fire"
next_milestone: "Player store with Creep Sheets (first hireable player with hidden archetype)"
milestone_distance: weeks      # days / weeks / months
community_pressure: none       # none / low / medium / high — are people waiting?
excitement: high               # low / medium / high — your honest energy on this
strategic: false               # does shipping this unlock something bigger?
momentum: rolling              # rolling / steady / blocked / stalled
audience: "management sim fans who want personality-driven humor and chaotic gameplay"
uniqueness: first-mover        # first-mover / competitive / crowded
viral_potential: medium        # low / medium / high — could this spread on its own?
mvp_distance: months           # days / weeks / months — to minimum shippable thing
---

## Why this exists
A dodgeball management sim where every player is a ridiculous archetype — the Gamer, the Yoga Mom, the Black Friday Doorbuster — and you scout, train, and field them through a season of chaotic matches.

## Strategic picture
This is a humor-first management game in a near-empty niche. The archetype system is the identity hook: discovering what your Creep Sheet hire actually is (a PE Teacher? a Retiree?) is the moment the game becomes shareable. The sim engine is already fast, seeded, and deterministic — the foundation is real. The layer on top (roster economy, season loop, progression) is what turns a tech demo into a game. Online multiplayer is the long-horizon goal; shipping a tight single-player season loop is the unlock.

## What's done
- [x] Core match engine — seeded, deterministic, fully simulated 6v6
- [x] 15 archetypes with stat bonuses, action weights, special skills, and commentary
- [x] All 15 skill IDs implemented in MatchEngine (`protein_rage`, `pro_gamer_move`, `hold_please`, etc.)
- [x] Player progression system — Sweat (XP), training ceiling, stat growth
- [x] Training Room UI — pending/confirm/cancel workflow
- [x] Save/load — roster persisted to `user://roster.json`
- [x] Seed replay (Rematch = same seed, New Match = fresh seed)
- [x] Live match log console + end-of-match stats overlay
- [x] Cover bonuses (positional teammate cover on dodge/catch)
- [x] Side-aware ball drop and rebalancing
- [x] Opening rush with archetype-aware priority

## Next up
- [ ] Hustle Points — team currency (earn from wins/match performance)
- [ ] Player store — hire screen with Creep Sheet cards (archetype hidden until scouted)
- [ ] Scouting mechanic — spend Hustle Points to reveal archetype/stats/ceiling on Creep Sheet
- [ ] Roster management — fire/release players (with cap implications later)
- [ ] Remove debug sweat/ceiling print block from `end_match()` before any release
- [ ] Campaign Manager — wire season scheduling (skeleton exists in `CampaignManager.gd`)
- [ ] Visual ball persistence — loose ball sprites on court

## Blockers
No hard blockers. The management/economy layer (Hustle Points, Creep Sheets) is the next major design decision — needs the hire/fire loop designed before CampaignManager gets wired up. The multiplayer backend (Firebase/Supabase) is long-horizon and not blocking anything now.

## Resume here
The match sim is solid. The progression system works. The gap is the meta-game: players need a reason to care about who's on their roster. Start with **Hustle Points** — define how they're earned (wins, performance bonuses, match stats) and where they're spent (hire, scout, train). Then build the **Creep Sheet** hire screen: a card with a hidden name/archetype, 3 revealed stats, and a "Scout" button. That's the first moment the game feels like a game. Key files to open: `CampaignManager.gd` (season skeleton), `scripts/Player.gd` (add hustle_points field), `scripts/GameUI.gd` (add store/hire UI node).

## Last session
2026-06-26: Reviewed project structure and updated PROJECT_STATUS. Core sim, archetypes, training, and save/load are all complete. Roster management (Creep Sheet, Hustle Points, hire/fire) is the active build target.
