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

Animations so far: `walk`. Attacks and hits are code-driven motion for now.

| Category | Piece ids (Stone Age) | Notes |
| --- | --- | --- |
| `bodies` | `body_male`, `body_female` | Bare body incl. head and face. Drawn in a **light neutral skin**; the game tints it to the chosen skin tone. |
| `hair` | `short`, `long`, `braids` | Drawn in **light grey**; the game tints it to the hair color. |
| `clothing` | `loincloth`, `hide_skirt`, `animal_hood`, `bone_headband`, `fur_cloak` | |
| `gear` | `hide_wrap`, `leather_armor`, `bone_hide`, `club`, `spear`, `stone_axe`, `flail`, `sling`, `hide_shield`, `bone_shield` | Weapons in the right hand, shields on the left arm, as worn. |
| `beasts` | `wolf` | One whole animal per sprite. |
| `scenery` | `tree`, `rock` | Only the `s` view is used. |

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

```
python3 tools/slice_sheet.py sheet.png /tmp/out          # cut, key out magenta, shrink to true pixels
#   check /tmp/out/_index.png to see which piece number is which
python3 tools/place_sprite.py beasts wolf s=/tmp/out/piece_00.png se=/tmp/out/piece_01.png \
        e=/tmp/out/piece_02.png ne=/tmp/out/piece_03.png n=/tmp/out/piece_04.png
```
