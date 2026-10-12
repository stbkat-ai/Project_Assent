# Project Ascent (working title)

A mobile, Dark Crusade–style conquest game where you **create your own civilization** and lead it from the
Stone Age to the space age. Built in **Godot 4** (GDScript), 2D pixel art, landscape phones first.

- **Design document:** https://claude.ai/code/artifact/c152695d-a333-43db-9af9-d9aa2f2796e3
- **Play in a browser:** https://stbkat-ai.github.io/Project_Assent/
- **Android install file (APK):** https://stbkat-ai.github.io/Project_Assent/project-ascent.apk

Both links rebuild automatically about 5 minutes after every push to `main`.

## What's playable now (v0.16.0)

| Prototype | Opening phase | What you can do |
| --- | --- | --- |
| **A. The leader** | 1. The first hero | Design your tribal leader: body, skin, hair, Shaman/Caveman clothing pieces, war paint, tribe color, and gear (armor, weapon, shield). Gear sets the stats; looks are cosmetic. |
| **B. The wilderness** | 2. Into the wilderness | Walk your leader across a wild map, fight wolves, boars, a bear and hostile cavemen, hunt deer and small game for points, and claim the clearing for your village. Your **score** sets how many Huts the village can raise at first. |
| **C. The village** | 3. Found the village | Design the **Chief's Hut** and the **Hut** (round hut or longhouse; walls, roof, doorway, roof crest, hanging decoration, yard prop), then place them freely in the clearing. Buildings can't overlap (an invisible grid keeps them tidy). Each Hut houses a family of four: **4 soldiers you can field**. |
| **D. The army** | 4. Create the army | Design soldiers on the Create Soldier screen (looks, armor, weapon, shield; the tribe's color is shared), then raise squads from the village's free people in the **Army** panel. Squads stand in formation; tap a soldier to select the squad and tap the ground to march it. |

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

**The wilderness map (0.16.0):** the wilderness is now a real map on a grid of person-sized squares (like the
original Warcraft), painted from Luke's terrain sheet: grass, tall grass, dirt, a trampled path, rocky ground,
sand, a river with two fords and a pond. Trees, bushes, rocks, stumps and logs are solid, forests and a rock
ridge form walls, and everyone walks around them on found paths. Deep water can't be crossed; shallow water,
tall grass and rocky ground slow you down; the path is quicker. Off the beaten path, dirt trails through the woods
lead to four hidden spots with caches to walk onto: a Flint cache (unlocks the Flint Axe) and a Bone cache
(unlocks the Bone-tipped Spear), each guarded by an **alpha wolf** and its pack, Sling and stones on a hidden
beach (unlocks the Sling), and Honey and hides in the bear's den (+60 points).

**Combat animation (0.15.0):** attacks follow the poses on Luke's animation sheets: the weapon hand moves (raised
overhead for a club or axe wind-up and the overhead stab, driven forward in a spear thrust, low in a sweep), the
body leans and crouches into the blow and the legs take the widest stride. A hit knocks a unit back for an
instant, and a fallen person stays on the ground (then fades) instead of vanishing.

**New bodies and walk (0.14.0):** the leader's and soldiers' bodies are now Luke's animation template itself:
the full figure walks with the template's 4 walk frames in every direction (no more stubby legs), and every
hair, clothing, armor and weapon layer is refitted to these bodies. The template's mannequins get simple eyes,
a loincloth and (female) a chest wrap.

**Tribal colors (0.13.0):** the tribe's color now shows on the models. War paint is a single "Tribal paint"
choice (a stripe across the eyes, a chest band and armbands, for both bodies in every direction) always drawn
in the tribe's color, and every banner, pennant and dyed hide on the huts (hangings, chieftain roofs, banner
doors and crests) takes the tribe's color too. Change it in the leader's Body tab or the soldier's Tribal
color strip and the whole tribe follows.

**Soldiers and squads (0.12.0):** the first army. A soldier design (blueprint) sets the look and gear every
soldier of its squads shares; its gear cost sets the squad size (cheap soldiers come 8 to a squad, pricier ones
6 or 4). Raising a squad takes that many people from the village (each Hut houses 4); disbanding gives them
back. Changing a design re-equips its squads. The squad leader carries a pennant in the tribe's color.
Weapon tiles use the icons from Luke's soldier weapon sheet; arrows, sling stones and thrown knives fly with
their art; and every swing picks one of three attacks for its weapon (spear: thrust, sweep, overhead stab;
club and axe: swing, overhead smash, sweep). Soldier armor, headgear, capes and arm guards in 5 directions
are coming as new sheets; until then soldiers wear the leader's clothing art.

**Creator screens (0.11.0):** the leader and hut designers now use Luke's ChatGPT screen mockups. Painted
tabs on the left pick a category (leader: Body, Hair, Facial hair, War paint, Clothing, Accessories, Weapons;
huts: Shape, Roof, Walls, Doorway, Decorations), the panel on the right shows every option as a tile with a
live picture of it, the stage shows the leader on the stone circle (or the hut in its clearing), the view strip
turns the leader (plus Walk and Attack previews), and Randomize / Confirm / Cancel are the painted buttons.
The Chief's Hut and the Hut share the hut screen. Facial hair is waiting on beard art.

**Walk and attack animation (0.10.0):** Luke's animation template sheet (a faceless mannequin walking
in 5 views, plus spear, club and axe attacks) now drives the leader. Walking swaps the body's legs below the
loincloth for the template's 4-frame walk cycle, fitted and recolored for every body and skin tone (the face,
loincloth and all worn layers stay). Attacks follow the template's poses as timed keyframes: spears draw back
and lunge level; clubs and axes are raised back overhead, then swung down and forward with a follow-through;
the legs take the widest stride during the strike.

**Hut art (0.9.0):** buildings are drawn from Luke's two ChatGPT hut sheets. A design picks a
**shape** (round hut or longhouse) and then 6 parts: 12 walls and 10 roofs per shape, 6 doorways and 13
roof crests per shape, 17 hanging decorations and 18 yard props (fire pit, rune stone, spear racks...).
The 5 decorated chieftain roofs per shape are only for the Chief's Hut. Designs from 0.7–0.8 reset to the
new defaults.

**Wildlife and score (0.8.0):** the wilderness is full of animals from the ChatGPT animal sheet, each
with its own temper:

| Animal | Temper | Points |
| --- | --- | --- |
| Rabbit, squirrel | skittish: runs from you | 5 |
| Wild turkey | skittish | 10 |
| Fox | defensive: only fights back when hit | 15 |
| Doe | skittish | 20 |
| Wolf | aggressive: attacks on sight | 25 |
| Stag | defensive | 35 |
| Hostile caveman | aggressive | 40 |
| Wild boar | territorial: attacks if you come close | 40 |
| Brown bear (one, in its corner of the map) | territorial | 100 |

Your score is shown under the objective. When you claim the clearing, the village may raise **2 Huts, plus
1 more for every 150 points (up to 6)**, so hunting is a risk you take for a bigger village. Retrying after
your leader falls starts the score over.

**Founding the village (0.7.0):** winning the wilderness now leads to the village. The first time, you
design the Chief's Hut and then the Hut, the same way as the leader. In the village, tap **Build Hut**,
tap a spot to preview it (green = fits, red = blocked), and tap the same spot again to build. Tap a
building to move or remove it (the Chief's Hut can be moved but not removed). Both designs can be changed
any time. Load Game returns you to
your village once the clearing is claimed.

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
scripts/data/              gear, appearance and building catalogs, unit_stats, village_layout (invisible grid)
scripts/render/            figure (layered 3/4-view drawing), directions (8 dirs -> 5 views), sprite_library
assets/sprites/            real art; overrides placeholders piece by piece (see assets/README.md)
tools/                     slice_sheet.py and place_sprite.py: turn concept sheets into game sprites
scripts/ui/                leader editor (Prototype A), building editor (Prototype C), shared UI style
scripts/world/             wilderness (Prototype B), village (Prototype C), creatures, buildings, map controls
tests/run_tests.gd         headless tests (run in CI on every push)
```

Run the tests locally: `godot --headless --path . -s res://tests/run_tests.gd`

## Roadmap (from the design doc)

A leader → B wilderness → C village (simple hut designer) → D army (uniform, blueprints, unit populator,
squads) → E revise-or-create blueprints → F first conquest (regional map, capture points, rival AI).
