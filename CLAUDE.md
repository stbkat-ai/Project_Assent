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
- View is 3/4 top-down, 8 directions; only views s/se/e/ne/n are drawn, the rest mirrored
  (`scripts/render/directions.gd`). Art lives in `assets/sprites/<category>/<piece>/<view>[_<anim>_<n>].png`
  and overrides the placeholder automatically (`sprite_library.gd`). Art comes from Luke as ChatGPT concept
  sheets: slice with `tools/slice_sheet.py`, check `_index.png`, show Luke the cut pieces, then
  `tools/place_sprite.py` (row-style sheets: `tools/slice_rows.py`). ChatGPT mislabels directions: map
  views by what they show. Source sheets are archived in `assets/source/`. Rules in `assets/README.md`.
  The leader uses paper-doll layers fitted to body landmarks by `tools/paper_doll/build.py` (male and
  female bodies; sheet layouts in `sheets.py`); with body art, layers lacking art are skipped, never mixed with code-drawn pieces.
- Village (`scripts/world/village.gd`): an invisible grid (`scripts/data/village_layout.gd`) with free,
  non-overlapping placement; buildings are designed like the leader (base + parts,
  `scripts/data/building_catalog.gd`, drawn by `scripts/render/building_draw.gd`). A Hut houses 4 = 4 soldiers.
  Hut art is a kit (shape + walls/roof/door/crest/hang/yard) built by `tools/huts/build.py`, which also
  writes `scripts/data/building_parts.gd` (never edit that by hand).
- Wilderness wildlife and scoring: `scripts/data/wildlife_catalog.gd` (stats, temper, points; the score sets
  the village's starting Hut limit via `huts_for_score`). Creature tempers live in `creature.gd`.
- Tabs for indentation.

## Testing / CI
- `tests/run_tests.gd` loads every script (catches parse errors) and checks the rules. Add new scripts to
  its `SCRIPTS` list and add tests for new rules.
- `.github/workflows/build.yml`: on every push to `main` → tests → web export + Android debug APK → `gh-pages` branch →
  GitHub Pages (https://stbkat-ai.github.io/Project_Assent/, APK at `/project-ascent.apk`).
- Godot can't be downloaded inside the Claude cloud container, so CI is the test loop: push, then read
  the Actions run and its logs, and fix until green.
