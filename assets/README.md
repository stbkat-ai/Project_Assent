# Art assets

Art replaces the code-drawn placeholders **one piece at a time**: as soon as a file exists at the right
path, the game draws it instead of the placeholder. Anything without art keeps its placeholder.

## View: 3/4 top-down, 8 directions (5 drawn)

Like the original StarCraft, units face 8 directions but only **5 views are drawn**; the game mirrors
the rest:

| View file | Faces | Also used (mirrored) for |
| --- | --- | --- |
| `s`  | down, toward the viewer | |
| `se` | down-right | down-left (`sw`) |
| `e`  | right | left (`w`) |
| `ne` | up-right | up-left (`nw`) |
| `n`  | up, away from the viewer | |

## Folder layout

```
assets/sprites/<category>/<piece>/<view>.png              still frame
assets/sprites/<category>/<piece>/<view>_<anim>_<n>.png    animation frames, n = 0, 1, 2 ...
```

Animations so far: `walk`. The leader's walk cycle is `bodies/legs_<sex>__<skin>/<view>_walk_<0-3>.png`
(legs only, on the body's canvas), built by `tools/anim/build_walk.py` from Luke's animation template
`assets/source/sheet_anim_template.png`; it also writes `scripts/data/walk_rig.gd`. Attacks are keyframed in
code from the template's poses (`ATTACK_POSES` in `scripts/render/figure.gd`); `tools/anim/preview.py` renders
a GIF of both. Re-run `build_walk.py` after `tools/paper_doll/build.py`.

| Category | Piece ids (Stone Age) | Notes |
| --- | --- | --- |
| `bodies` | `body_male`, `body_female` | Bare body incl. head and face. Drawn in a **light neutral skin**; the game tints it to the chosen skin tone. |
| `hair` | `short`, `long`, `braids` | Drawn in **light grey**; the game tints it to the hair color. |
| `clothing` | `loincloth`, `hide_skirt`, `animal_hood`, `bone_headband`, `fur_cloak` | |
| `gear` | `hide_wrap`, `leather_armor`, `bone_hide`, `club`, `spear`, `stone_axe`, `flail`, `sling`, `hide_shield`, `bone_shield` | Weapons in the right hand, shields on the left arm, as worn. |
| `beasts` | `wolf_gray`, `wolf_brown`, `boar`, `bear`, `deer_doe`, `deer_stag`, `fox`, `rabbit`, `squirrel`, `turkey` (ids in `scripts/data/wildlife_catalog.gd`) | One whole animal per view. `e_death_0.png` = the body left behind (the small animals have none yet). |
| `units` | `caveman_spear` | Whole-character sprites for units that aren't customized (enemies, NPCs). |
| `buildings` | `<shape>_<slot>_<id>`, e.g. `round_walls_log_ring`, `long_roof_hide_gable`, `any_yard_fire_pit` (ids in the generated `scripts/data/building_parts.gd`) | Only the `s` view. Built by `tools/huts/build.py` from `assets/source/sheet_huts_1.png` and `sheet_huts_2.png`: every part sits on one shared 120 x 150 canvas, so the layers stack. To add parts, extend `PARTS` in the tool and re-run it; `tools/huts/preview.py` renders sample huts. |
| `scenery` | see `scripts/data/scenery_catalog.gd` (oaks, pines, birches, bushes, rocks, grass, ferns, flowers, mushrooms, stumps, log) | Only the `s` view is used; maps mirror them at random. |

Tribal color: parts that should wear the tribe's color have a grey companion layer, `<piece>__tint`, that the
game draws tinted with the tribe's color. `tools/huts/build.py` splits the sheets' red and blue cloth into
`buildings/<piece>__tint`; `tools/paper_doll/build_paint.py` makes the war paint (`clothing/<sex>_paint_tribal`),
a grey layer drawn in the tribe's color. For new art: paint tribal-color areas one flat, bright color that
appears nowhere else on the piece.

The creator screens are `assets/ui/leader_screen.png` and `assets/ui/hut_screen.png`, built by
`tools/ui/build_screens.py` from Luke's mockups (`assets/source/ui_*_mockup.png`): it paints the sample leader
and hut out of the scene, clears the options panel and view strip, and un-highlights the first tab. Needs
`pip install opencv-contrib-python-headless`. Tap-zone coordinates live in `LAYOUT` in
`scripts/ui/leader_editor.gd` and `scripts/ui/building_editor.gd`.

The soldier screen (`assets/ui/soldier_screen.png`) comes from `ui_soldier_mockup.png` the same way. Weapon
icons (`assets/ui/icons/weapon_*.png`) and projectiles (`assets/sprites/projectiles/<id>/e.png`, pointing
right; the game turns them to their flight) are cut from `sheet_soldier_weapons_anim.png` by
`tools/ui/build_icons.py`.

The title screen art is `assets/ui/title.png` (its painted buttons are tap zones, see
`scripts/ui/title_screen.gd`). Original ChatGPT sheets are kept in `assets/source/` (not shipped in the game).

Piece ids match `scripts/data/gear_catalog.gd` and `scripts/data/appearance_catalog.gd`.

## Rules every layer must follow (so layers stack)

- **Same canvas size** for every layer of a character and every view and frame of it
  (proposal: **32 x 48** art pixels).
- **Feet at the bottom center** of the canvas. The game anchors sprites there.
- Each gear or clothing piece is drawn **as worn, in place**, on an otherwise transparent canvas, so it
  lines up when stacked on the body.
- Transparent background, hard pixel edges, no anti-aliasing.
- Layer order is handled by the game (e.g. cloak behind the body when facing the viewer, in front of it
  when facing away), so each piece is drawn on its own.

## Turning a ChatGPT concept sheet into game sprites

ChatGPT's direction labels are often wrong (its "N" usually faces the viewer). Always map views by what
they show: `s` faces the viewer, `se` down-right, `e` right, `ne` up-right, `n` away. If no view faces
up-right, use the up-left one with `--flip ne`.

Scattered sheets (items in a grid):

```
python3 tools/slice_sheet.py sheet.png /tmp/out --scale 2   # cut, drop captions, key out magenta, halve
#   check /tmp/out/_index.png to see which piece number is which
python3 tools/place_sprite.py beasts wolf s=/tmp/out/piece_00.png se=/tmp/out/piece_01.png \
        e=/tmp/out/piece_02.png ne=/tmp/out/piece_03.png n=/tmp/out/piece_04.png
```

Row sheets (one character or animal per row: 8 directions, then idle / walk / attack / hurt / death):

```
python3 tools/slice_rows.py assets/source/sheet_animals.png /tmp/rows --band wolf_gray:5:148 --x-min 105
#   check /tmp/rows/_rows.png, then map views by what they show
python3 tools/place_sprite.py beasts wolf_gray s=/tmp/rows/wolf_gray_00.png se=/tmp/rows/wolf_gray_01.png \
        e=/tmp/rows/wolf_gray_02.png ne=/tmp/rows/wolf_gray_05.png n=/tmp/rows/wolf_gray_04.png --flip ne
python3 tools/place_sprite.py beasts wolf_gray e=/tmp/rows/wolf_gray_12.png --anim death
```

## The leader: paper-doll layers (`tools/paper_doll/`)

Built by `python3 tools/paper_doll/build.py` from the ChatGPT sheets in `assets/source/` (cell layouts in
`tools/paper_doll/sheets.py`):

- `sheet_paper_doll_male_2.png` — bald male body, hair (long, braids, short), hide wrap, leather armor,
  fur mantle, bone-and-hide armor, hide skirt, bone headband, red war paint, club, axe, flail, sling
- `sheet_paper_doll_female.png` — bald female body, hair, armor, mantle, skirt, headband, wolf hood,
  antler helm, wooden shield
- `sheet_weapons.png` — stone spear, bone spear, spiked club, stone axe (used for both bodies)
- `sheet_paper_doll_male.png` — the first male sheet; still used for the shields and the male helmets

ChatGPT draws each piece centered in its own cell at its own scale, so the build fits every piece to
landmarks on its body (head, torso, waist, hands per view, in `BODIES` in `build.py`), puts all layers of a
view on one canvas with the feet at the bottom center, and shrinks them to game size. Weapons are held at a
grip point near the handle end and lean forward in side views. Skin tone, hair color and war paint are
recolored into variants; skin-colored pixels are removed from hair so the body's face shows through.

Ids: `bodies/body_<sex>__<skin>`, `hair/<sex>_<style>__<color>`, `gear/<sex>_<id>`, `clothing/<sex>_<id>`,
`clothing/<sex>_paint_<color>__<skin>`. When a body has art, layers without art are left out (code-drawn
pieces don't line up with painted bodies); the leader editor marks them with `*`.
`python3 tools/paper_doll/preview.py out.png` renders outfit previews.

**Animation is done in code** (no walk/attack frames needed yet): `build.py` also writes
`scripts/data/rig.gd` with each body's hand and hip positions per view. Walking splits the body below the hip
into two halves that lift in turn while the upper body bobs; attacking leans the body forward and thrusts
the weapon out from the hand. Whole-body sprites (wolves, cavemen) get the same leg trick. Real animation
frames (`<view>_walk_<n>.png`) can replace this later.
