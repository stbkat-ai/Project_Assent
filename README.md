# Project Ascent (working title)

A mobile, Dark Crusade–style conquest game where you **create your own civilization** and lead it from the
Stone Age to the space age. Built in **Godot 4** (GDScript), 2D pixel art, landscape phones first.

- **Design document:** https://claude.ai/code/artifact/c152695d-a333-43db-9af9-d9aa2f2796e3
- **Play in a browser:** https://stbkat-ai.github.io/Project_Assent/
- **Android install file (APK):** https://stbkat-ai.github.io/Project_Assent/project-ascent.apk

Both links rebuild automatically about 5 minutes after every push to `main`.

## What's playable now (v0.6.0)

| Prototype | Opening phase | What you can do |
| --- | --- | --- |
| **A. The leader** | 1. The first hero | Design your tribal leader: body, skin, hair, Shaman/Caveman clothing pieces, war paint, tribe color, and gear (armor, weapon, shield). Gear sets the stats; looks are cosmetic. |
| **B. The wilderness** | 2. Into the wilderness | Walk your leader across a wild map, fight wolves and hostile cavemen, and claim the clearing for your village. |

Battles use a **3/4 top-down view like the original StarCraft**, and units face **8 directions** (5 drawn,
3 mirrored). The leader editor's **Turn** and **Walk** buttons preview every direction.

**First real art (0.3.0):** the title screen, all wilderness scenery (trees, bushes, rocks, plants),
wolves and hostile spear-carrying cavemen come from ChatGPT concept sheets, with bodies left behind when
they fall.

**Female leader and full gear art (0.6.0):** male and female leaders both use paper-doll art now: bald
bodies in 6 skin tones, long / braided / short hair in 5 colors, hide wrap, leather and bone-and-hide armor,
fur mantle, hide skirt, bone headband, wolf hood, antler helm, red war paint (male), and every starting
weapon plus flail and sling, held in the hand and leaning forward in side views.

**Weapons (0.5.0):** a new game starts with the **spear, club and axe**. The full Stone Age list (knives,
bone and stone clubs, mace, flail, flint axe, bone-tipped spear, sling, and two-handed great club, war spear,
halberd and bows) is in the game data, locked until unlocks arrive. Two-handed weapons leave no hand for a
shield. Attacks animate by weapon type: spears thrust, clubs and axes swing, bows and slings shoot.

**Leader art (0.4.0):** a male leader is drawn from ChatGPT paper-doll layers: body in 6 skin tones x 5 hair
colors, long or braided hair, hide or leather armor, fur mantle, wolf-pelt hood, antler skull helm, two
spears and two shields, all in 5 views. Choices without art yet are marked `*` in the editor. A female
leader is still the code-drawn placeholder.

Remaining placeholders are pixel art drawn in code. Every clothing and gear piece is its own layer, and
real sprites replace placeholders **one piece at a time** as they're added: see
[`assets/README.md`](assets/README.md) for the folder layout, naming and the sheet-slicing tools.

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
scripts/render/            figure (layered 3/4-view drawing), directions (8 dirs -> 5 views), sprite_library
assets/sprites/            real art; overrides placeholders piece by piece (see assets/README.md)
tools/                     slice_sheet.py and place_sprite.py: turn concept sheets into game sprites
scripts/ui/                leader editor (Prototype A), shared UI style
scripts/world/             wilderness map (Prototype B), creatures, projectiles
tests/run_tests.gd         headless tests (run in CI on every push)
```

Run the tests locally: `godot --headless --path . -s res://tests/run_tests.gd`

## Roadmap (from the design doc)

A leader → B wilderness → C village (simple hut designer) → D army (uniform, blueprints, unit populator,
squads) → E revise-or-create blueprints → F first conquest (regional map, capture points, rival AI).
