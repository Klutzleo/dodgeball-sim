# Dodgeball Sim

A chaotic, multiplayer dodgeball sim built in [Godot Engine](https://godotengine.org), featuring archetype-driven AI, real-time action resolution, and narrative match recaps. Designed for cross-platform play (desktop, web, mobile).

## 🎮 Features

- Deterministic, seeded match engine with narratable outcomes
- Archetype-driven actions and streak system (hits/dodges/catches/clutch)
- Real-time reaction queue (not turn-based)
- Live match log console + end-of-match stats overlay
- Planned Firebase/Supabase sync using authoritative `MatchRound` logs

## 🚀 Quick Start (Godot 4.5)

1. Clone the repo:
   ```bash
   git clone https://github.com/Klutzleo/dodgeball-sim.git
   ```
2. Open the project in Godot 4.5 and load the project file.
3. Run the main scene [Main.tscn](Main.tscn).
4. Watch the bottom console for emoji-prefixed logs and the stats overlay at match end.

Windows CLI (optional):
```powershell
# From the repo root
godot4.exe --path .
```

Deterministic replay:
- At match end, use the seed input in the stats overlay to enter an integer.
- Click "Replay with Seed" to rerun the match deterministically.

## 🧱 Project Structure

```
dodgeball-sim/
├── scenes/
├── scripts/
│   ├── GameUI.gd
│   ├── MatchEngine.gd
│   ├── MatchRound.gd
│   └── Player.gd
├── assets/
│   ├── sprites/
│   └── audio/
├── Main.tscn
├── project.godot
├── README.md
└── LICENSE
```

## 📦 Requirements

- Godot Engine 4.5
- Optional: Aseprite for sprites
- Optional: Firebase/Supabase for multiplayer sync (planned)

## 🧠 Vision

Chaotic, personality-driven gameplay with emergent storytelling. Each match is a narrative; archetypes and streaks shape the drama. The sim doubles as a deterministic backend for future online play.

## 🛠️ Troubleshooting

- No logs or UI? Make sure you run [Main.tscn](Main.tscn) (it wires `GameUI` to `MatchEngine`).
- Window too small/large? The scene auto-sizes to the viewport; adjust the editor window and rerun.
- Determinism checks: Use the seed controls in the stats overlay; re-enter the same seed to reproduce outcomes.
- Balls stalling? `rebalance_balls()` prevents deadlocks by redistributing `loose_balls` to eligible players.

## 📜 License

MIT License. See [LICENSE](LICENSE).
