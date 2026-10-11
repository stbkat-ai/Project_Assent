# Project Ascent — notes for Claude

Godot 4.3 game (GDScript), mobile landscape, 2D placeholder pixel art drawn in code. The creator is Luke;
the design document (source of truth for game design) is
https://claude.ai/code/artifact/c152695d-a333-43db-9af9-d9aa2f2796e3 — record new design decisions there.

## Conventions (they keep blind-written code from breaking)
- **No `class_name`, no autoloads.** Every script references others with
  `const X = preload("res://...")`. Game state is a `GameState` object passed to screens via `setup()`.
- **Screens are built in code** (no hand-written `.tscn` beyond `main.tscn`).
- **Store ids, not indices**, in saves and data (JSON turns numbers into floats). Saves carry a version.
- Never use `:=` when the right-hand side is a Variant (dictionary/untyped-array access); write `var x = …`
  or give an explicit type. Loop variables over `get_nodes_in_group()` are re-bound untyped (`var other = node`).
- Gear and looks are separate: gear sets stats (`scripts/data/unit_stats.gd`), looks are cosmetic.
- Every drawable piece is its own layer in `scripts/render/figure.gd` so real sprites can replace it.
- Tabs for indentation.

## Testing / CI
- `tests/run_tests.gd` loads every script (catches parse errors) and checks the rules. Add new scripts to
  its `SCRIPTS` list and add tests for new rules.
- `.github/workflows/build.yml`: on every push to `main` → tests → web export + Android debug APK → `gh-pages` branch →
  GitHub Pages (https://stbkat-ai.github.io/Project_Assent/, APK at `/project-ascent.apk`).
- Godot can't be downloaded inside the Claude cloud container, so CI is the test loop: push, then read
  the Actions run and its logs, and fix until green.
