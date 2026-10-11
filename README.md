# Project Ascent (working title)

A mobile, Dark Crusade–style conquest game where you **create your own civilization** and lead it from the
Stone Age to the space age. Built in **Godot 4** (GDScript), 2D pixel art, landscape phones first.

- **Design document:** https://claude.ai/code/artifact/c152695d-a333-43db-9af9-d9aa2f2796e3
- **Play in a browser:** https://stbkat-ai.github.io/Project_Assent/
- **Android install file (APK):** https://stbkat-ai.github.io/Project_Assent/project-ascent.apk

Both links rebuild automatically about 5 minutes after every push to `main`.

## What's playable now (v0.1.1)

| Prototype | Opening phase | What you can do |
| --- | --- | --- |
| **A. The leader** | 1. The first hero | Design your tribal leader: body, skin, hair, Shaman/Caveman clothing pieces, war paint, tribe color, and gear (armor, weapon, shield). Gear sets the stats; looks are cosmetic. |
| **B. The wilderness** | 2. Into the wilderness | Walk your leader across a wild map, fight wolves and hostile cavemen, and claim the clearing for your village. |

All art is placeholder pixel art drawn in code. Every clothing and gear piece is its own layer, so the
real sprites can replace it piece by piece later.

### Controls

- **Tap** the ground to walk; **tap an enemy** to attack (your leader also fights back automatically).
- **Drag** to look around, **pinch** to zoom (mouse wheel on desktop).
- **Tap your leader's card** (bottom left) to re-center the camera.

## Testing on your phone

- **Fastest:** open the browser link above.
- **As a real app (Android):** download the APK link, open it, and allow installing from your browser
  when Android asks. It's debug-signed, so it installs alongside nothing else and can be removed anytime.
- **In the Godot editor app:** on GitHub tap *Code → Download ZIP*, unzip, then *Import* the folder in Godot.

## Project layout

```
main.tscn                  entry scene (just runs scripts/main.gd)
scripts/main.gd            screen manager + main menu
scripts/game_state.gd      saved progress (JSON in user://save.json, versioned)
scripts/data/              gear catalog, appearance catalog, unit_stats (gear -> stats, squad size, damage)
scripts/render/figure.gd   placeholder pixel-art drawing, one layer per clothing/gear piece
scripts/ui/                leader editor (Prototype A), shared UI style
scripts/world/             wilderness map (Prototype B), creatures, projectiles
tests/run_tests.gd         headless tests (run in CI on every push)
```

Run the tests locally: `godot --headless --path . -s res://tests/run_tests.gd`

## Roadmap (from the design doc)

A leader → B wilderness → C village (simple hut designer) → D army (uniform, blueprints, unit populator,
squads) → E revise-or-create blueprints → F first conquest (regional map, capture points, rival AI).
