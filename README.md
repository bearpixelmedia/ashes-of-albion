# Ashes of Albion — Phase 0–5 Prototype

A playable Godot 4.3 vertical slice of the AoC-mechanics MMO with Albion-style
art direction: it opens on a **title screen** (Enter World / Character Select /
Settings / Exit), then a **character-select screen** (concept image 3 — character
slots, a dais preview of your champion in a torchlit cathedral hall, the
eight-archetype picker), then drops you into the dusk town square beside
**Champions' Row** (the lineup from concept image 2). Walk the market street into the arena and fight a
**three-wave encounter** against three foe archetypes (melee warden, ranged
harrier, shielded bulwark), with a results panel after each cleared wave.
Two classes are playable: the **Fighter** (three-hit combo, Cleave, Second
Wind) and the **Ranger** (bow shots, Power Shot, Tumble). Lock on, trade blows
on a poise/stagger system, die and respawn if you lose, then return to the
square with the loop reset and your score preserved.

## Run it

- Open `ashes-of-albion/project.godot` in **Godot 4.3+** (GL Compatibility renderer, no extra assets required) and press **F5**.
- Boot scene: **`res://scenes/title_screen.tscn`** (the project main scene) → **Enter World** (last committed class) or **Character Select** → pick an archetype → **Enter World**.
- In the world, `Esc` opens the pause menu: Resume, Character Select or Title Screen.
- World scene: **`res://scenes/main.tscn`** (loads directly with the last committed class; useful for debugging, defaults to the Fighter).
- Standalone lineup view: run **`res://scenes/lineup.tscn`** (F6) for a clean concept view of the eight champions.
- Headless verification: `godot --headless --path ashes-of-albion res://tests/smoke.tscn`
- Progress (champion, level, tree ranks, volume/fullscreen) is saved to **`user://save.cfg`** on boot load and after every change; delete that file to start fresh.

## Controls

| Input | Action |
|---|---|
| `W A S D` | Move (camera-relative) — on the title/select screens: `W`/`S` or `↑`/`↓` move between menu entries / archetypes |
| Mouse | Orbit camera (over-the-shoulder, spring-arm collision) — on the select screen: click rows and buttons |
| `Shift` | Sprint (drains stamina) |
| `Space` | Jump |
| `E` | Recruit the cleric in the square / pick her back up when down (within 4 m) |
| `Q` | Lock on / off nearest attackable target (reticle appears; ranger bolts auto-aim at it) |
| `LMB` | **Fighter:** weapon combo 25 → 25 → **40 finisher** (0.5 s cooldown; chain resets after 1.2 s) · **Ranger:** loose an arrow (25 dmg, ranged) |
| `1` | **Fighter:** **Cleave** — 45 dmg arc (4.5 m cone, hits every foe), 30 stamina, 6 s CD · **Ranger:** **Power Shot** — 50 dmg bolt, 25 stamina, 5 s CD |
| `2` | **Fighter:** **Second Wind** — heals 35 HP + 25 stamina, 18 s CD · **Ranger:** **Tumble** — evade dash with brief i-frames, 7 s CD |
| `3`–`5` | Locked slots (`–`, dimmed) until their classes exist |
| `Enter` | On the title and select screens: activate the focused entry (Enter World, Character Select, …) |
| `Esc` | **In the world:** open / close the pause menu (Resume · **Skills** · Character Select · Title Screen); the skill tree closes back with `Esc`. **On the title/select screens:** close settings / return to the title screen. |

## Front end

The concept set has no title-screen piece, so **`res://scenes/title_screen.tscn`**
is built to the language the rest of the art uses: a dusk gradient behind a gold
tree-of-life crest and the **ASHES OF ALBION** wordmark, two house banners and a
hazy moon flanking it, and the four entries — **Enter World**, **Character
Select**, **Settings**, **Exit** — set into a dark gold-bordered board with a
gold primary button, keyboard focus (arrows or `W`/`S`, `Enter`) and a version
tag bottom-right. The crest (`scripts/heraldic_crest.gd`) is drawn from lines,
not a texture, and the same emblem is reused on the character-select panel and
in the 3D hall.

- **Enter World** loads `main.tscn` with the last committed class (the Fighter
  on a fresh run); **Character Select** opens the picker.
- **Settings** opens a small panel: **master volume** (drives audio bus 0 live)
  and a **fullscreen** toggle; `Back` or `Esc` closes it.
- **Exit** quits the game.

The picker's **Back** button (or `Esc`) returns to the title without committing
a class, so the front-end loop is title → picker → world and back again. Every
screen shares the dark-parchment + gold-trim styling.

**In-world pause menu** (`scenes/pause_menu.tscn`, instanced by `main.tscn` as a
`CanvasLayer`): `Esc` pauses the tree, frees the mouse and shows **Resume**,
**Character Select** and **Title Screen**. Resume recaptures the mouse and
unpauses; the other two unpause before changing scene, so no run is ever left
frozen behind a menu. `Esc` belongs to the menu — the player no longer owns it.

## The loop

0. **Title screen → world:** **Enter World** boots the world with the last
   committed class; **Character Select** goes through the picker first. `Esc`
   in the world opens the pause menu, which leads back to either screen.
1. Spawn in the town square (`z = +8`) facing north; HUD shows zone **Town Square**.
2. Walk the torch-lit path past 4 market stalls, 10 faction banners, 16 torches
   and 7 stone/timber buildings (all built from reusable prop scenes).
3. Pass through the arena gate → Area3D transition flips the zone to
   **Combat Arena**, starts **wave 1** and resets the placed opponents
   (training dummy + arena warden). The HUD gains a `Wave n / 3` counter.
4. `Q` to lock on, `LMB` to attack: floating billboard health bar drains, hit
   flash, damage number, scoreboard `Kills` on defeat (opponent topples).
   Swing within the 1.2 s combo window to chain into the **40 dmg finisher**;
   slot-`1` **Cleave** clears a pack (arc hits every foe in front, stamina +
   cooldown gated), slot-`2` **Second Wind** tops you back up.
5. **Clear a wave** (every foe down) → the **results panel** shows
   `Wave n cleared` with kills, deaths and run time; after a 2 s gap the next
   wave spawns at fixed arena spawn points and the panel clears.
6. Clear **wave 3** → `Arena Cleared` results panel and the loop stops
   spawning (no wave 4).
7. **Poise/stagger:** hits drain the poise bar; an empty bar = 1 s stagger
   (movement, attacks and skills locked; poise refills so there is no
   perma-stunlock). At 0 HP the player dies, the scoreboard records `Deaths`,
   and after 2.5 s they respawn full-health back in the square — which exits
   the arena and resets the loop.
8. Walk back out through the gate → zone returns to **Town Square**, spawned
   foes are removed, the placed opponents reset (HP full, warden home and
   idle), the wave counter and results panel hide, score is preserved,
   controls unchanged. Repeat.

## Foe archetypes

One script (`scripts/foe.gd`) drives all three via a `kind` export — the same
state machine `IDLE → CHASE → WINDUP → RECOVER → DOWN` (+ `GUARD_BREAK`):

| Foe | Kind | HP | Behaviour |
|---|---|---|---|
| Training dummy | — | 100 | Stationary target, topples on defeat |
| Arena warden | `MELEE` | 120 | Chases within 10 m, telegraphs each swing (raised weapon + red `!`, 0.7 s), hits for 18 HP + 35 poise |
| **Harrier** | `RANGED` | 90 | Holds a 7–14 m band: approaches past 14 m, kites back below 7 m, then fires a bolt every 2.2 s (0.6 s orange `!` windup). Bolts raycast every step, so torch posts, cover and walls block them |
| **Bulwark** | `SHIELDED` | 240 | Slow heavy melee (1.0 s windup, 26 HP + 45 poise). Frontal hits are reduced 75 % and drain a **100 guard meter** instead of health; an empty guard triggers a 3 s `BROKEN` window at full damage; attacks from behind bypass the shield entirely |

Guard loop: chip the bulwark from the front and the guard drains by the full
hit value (a Cleave drains 45 at once) → `BROKEN` → punish for 3 s → it
recovers and the guard refills. Go around the back to skip the shield, at the
risk of its wind-up catching you.

## Fighter class kit

The Fighter is the only playable class in this prototype; the kit lives in
`scripts/player.gd` and the roster data in `scripts/class_kit.gd`:

| Slot | Skill | Effect | Cost / cooldown |
|---|---|---|---|
| Passive | 3-hit combo | `LMB` chains 25 → 25 → **40** within a 1.2 s window, then restarts | — |
| `1` | **Cleave** | 45 dmg in a 4.5 m cone in front (half-angle ≈ 72°, `dot ≥ 0.3`); hits **every** foe in the cone | 30 stamina, 6 s |
| `2` | **Second Wind** | Heals 35 HP and restores 25 stamina | 18 s |
| `3`–`5` | Locked | Dimmed slot, `–` caption — reserved for skills of classes that aren't playable yet | — |

The HUD labels the bar **FIGHTER**, names each unlocked slot, shows live
cooldown countdowns on `1`/`2`, and locks everything the class hasn't earned.

## Fighter skill tree (concept image 1)

`res://scenes/skill_tree.tscn` is the board from the concept: **Swordcraft**
splits into **Offensive Form** and **Defensive Form**, and each branch carries
ranked nodes. Open it with **Skills** in the in-world pause menu (`Esc`); the
world pauses behind the board, `Esc` or **Back** returns, and every rank is
pushed onto the live kit immediately. Running the scene directly (F6) opens the
board for inspection.

| Node | Ranks | Effect |
|---|---|---|
| Swordcraft | — | root of the tree |
| Offensive Form | 3 | +3 Cleave damage per rank |
| Cleave | 3 | +6 Cleave damage per rank |
| Sundering Strike | 3 | +0.25 m Cleave reach per rank |
| Whirlwind | **locked** | not in this build |
| Armor Break | **locked** | not in this build |
| Defensive Form | 3 | +4 Second Wind healing per rank |
| Fortify | 3 | +5 max health per rank |
| Guard Stance | 3 | +3 max poise per rank |
| Second Wind | 3 | +8 Second Wind healing per rank |
| Bulwark | **locked** | not in this build |

- **Points:** 8 total, with the concept's six ranks already committed
  (Offensive Form 2, Defensive Form 1, Cleave 1, Sundering Strike 1, Fortify 1)
  and **two to spend** — the two gold orbs beside the counter. Clicking a node
  spends one; a full pool or a maxed node is refused with a line of feedback.
- **Reset** refunds every point and returns the kit to its base numbers
  (Cleave 45, Second Wind 35). Ranks live in `SkillTreeData` as statics, so they
  survive scene changes the same way the class selection does.
- The **Secondary Archetype** rail is drawn and gated: "Unlocks at Level 25".
- Fortify and Guard Stance raise the health/poise ceilings, and the HUD bars
  follow the player's maxima.
- Cleave and Second Wind are the only ranks with skills behind them today; the
  other nodes hold the bonuses for skills still to be built.

## Character select (concept image 3)

`res://scenes/character_select.tscn` is the picker behind the title screen's
**Character Select**, laid out like the concept: the **CHARACTERS** slot card on the left (`Rowan Vale · Level 12 ·
Albion` plus two empty slots), the **ARCHETYPES** picker on the right (all
eight with their concept flavor lines — "Master the blade.", "Strike from
afar.", …), the chosen champion on a **lit stone dais** in the centre
(SubViewport with its own camera, light and dusk environment; the figure is
the same `archetype_figure.tscn` builder used in Champions' Row, rotated to
face the camera), and the action bar below (`Enter World` and `Back` live, `Create New` /
`Delete` present but disabled, prototype version tag bottom-right).

Behind the dais `scripts/select_hall.gd` builds the concept's cathedral backdrop
from primitives: pointed arches with gold trim, a moonlit window, four hanging
house banners, torch sconces and a red carpet, with three ghostly champions on
plinths behind the dais and a gold triquetra on the floor in front of it. Each
archetype row carries a heraldic chip in its class colour, and the slot card
carries the fighter's red crest.

- Mouse or `W`/`S`/arrows cycle the roster; every archetype can be **previewed**
  on the dais, but **Enter World** is only enabled for playable classes
  (Fighter, Ranger) — the status line explains the rest.
- `Enter` / **Enter World** commits the pick to `ClassKit.selected` and loads
  `main.tscn`, which applies it in `_ready` (so a directly launched world uses
  the last committed class, defaulting to the Fighter).
- **Back** / `Esc` leaves for the title screen without committing.

## Ranger class kit

The second playable class, entered from the select screen; the HUD relabels
itself and the controls hint swaps to bow controls:

| Slot | Skill | Effect | Cost / cooldown |
|---|---|---|---|
| Passive | Bow shots | `LMB` looses a 25 dmg arrow from chest height (ranged; aims at the `Q` lock-on target when held) | 0.5 s |
| `1` | **Power Shot** | 50 dmg bolt down the sightline (cover still blocks it) | 25 stamina, 5 s |
| `2` | **Tumble** | 0.25 s evade dash forward with **0.4 s i-frames** (cleanse-free window through a hit) | 7 s |
| `3`–`5` | Locked | As above | — |

Implementation notes: `player.gd` branches on `ClassKit.is_ranged(class_id)`
(attack, both skill slots, `setup_class()` swaps the sword for a
runtime-built primitive bow), and `projectile.gd` gained a friendly mode —
the same cover-aware bolt the harrier fires, now damaging `attackable` foes
instead of the player when loosed by the ranger.

## Champions' Row (concept image 2)

The town square's east side stages **eight champions** on a stone plinth —
one per archetype from `docs/art-direction/concept/classes.png`, left to right:
**Bard, Cleric, Fighter, Mage, Ranger, Rogue, Summoner, Tank**. Each figure
(`scripts/archetype_figure.gd`) is built from engine primitives with its own
body/trim colours, headgear (feather hat, hood, helm, wide hat, glasses), back
prop (cape, quiver) and weapon prop (lute, mace, greatsword, staff, bow,
daggers, book, tower shield); the Summoner is joined by a floating spectral
ally and every champion carries a billboarded nameplate (name + role). They
idle with a gentle bob under a `CHAMPIONS' ROW` sign.

Run **`res://scenes/lineup.tscn` directly (F6)** for a clean, framed view of
the row (it then adds its own camera/light/floor); in-world it is instanced
into `main.tscn` with `standalone_view = false`.

## Persistence

The run is saved to **`user://save.cfg`** (Linux:
`~/.local/share/godot/app_userdata/Ashes of Albion/save.cfg`) as a
`ConfigFile` with three sections:

| Section | Keys | Written by |
|---|---|---|
| `champion` | `class`, `level`, `xp`, `secondary`, `tree` (node → rank) | picker commit, skill-tree spend/reset, Secondary pick |
| `audio` | `volume`, `muted` | the title screen's settings panel |
| `display` | `fullscreen` | the title screen's settings panel |

`scripts/save_game.gd` (`SaveGame`) captures the live statics —
`ClassKit.selected`, `Progression.level`/`xp`, `Progression.secondary`,
`SkillTreeData.ranks`, the master bus and the window mode — and `restore()`
runs once on the title screen (and again on a direct `main.tscn` run). Saved
ranks are clamped to each node's maximum and an unknown class falls back to the
current one, so a stale or hand-edited file cannot break a launch. Delete the
file to reset the run.

The headless suite points `SaveGame.path` at `user://smoke_save.cfg` and turns
`SaveGame.auto` off, so a developer's own save never leaks into the checks and
the suite's writes are cleaned up afterwards.

## Progression

Kills feed experience and experience feeds the Fighter tree:

- **XP** — every defeated foe banks 50 XP (`Progression.XP_PER_KILL`). The
  curve is flat at **100 XP per level**, so two kills complete a level.
- **Levels → points** — the champion starts at **level 12**, the state the
  concept art shows, which owns the tree's eight-point pool. Every level above
  12 adds **one skill point** (`Progression.points_total()`), so the tree's
  `Available Skill Points` counter, orb row and `Ranks n / 21 spent` summary all
  grow as you level. A level-25 champion holds 21 points — the tree's full
  unlocked capacity.
- **HUD readout** — `Lv n` sits beside the class name above the hotbar and
  follows level-ups live, including the ones that happen on a kill.
- **Level 25 rail** — the Secondary Archetype rail is padlocked and reads
  `Unlocks at Level 25` until the champion reaches 25; then the padlock and
  shield clear and the rail opens into the eight archetypes. The pick is
  identity only for now (no secondary kit exists) and is saved with the run.

XP and level are part of the save file, so a levelled champion comes back at
the same level with the same points after a relaunch.

## The cleric companion

**Maelis Orr** stands in the town square with an **ALLY** nameplate and a
`Press E to recruit` prompt. Press `E` within 4 m and she joins the party:

- **Follows** — she trails the champion at ~2.4 m, catching up at 4.2 m/s and
  settling when close.
- **Heals on a cooldown** — when the champion is below 75 % health and within
  9 m, she mends 18 HP and starts an 8 s cooldown. A full-health, dead or
  out-of-range champion gets nothing.
- **Can be downed** — once recruited she is a legal arena target whenever she
  is the closer of the two, so her 80 HP can be emptied. She drops for 8 s with
  no following and no healing, the party frame darkens and reads `Downed`, then
  she gets back up at half health; press `E` beside her to pick her up early.
- **Live party frame** — row two of the HUD reads her name, role and state over
  a bar fed from her health every frame.

She is not in the save file yet: a fresh session finds her waiting in the
square again.

## HUD (concept image 6)

The in-world HUD follows the concept's layout: **party frames top-left**, the
**Combatant objective bar** top-centre, stat bars bottom-left, the **icon
hotbar** bottom-centre, scoreboard top-centre, minimap top-right and the
lock-on reticle in the middle.

- **Party frames** (`scripts/hud.gd`) — two dark, gold-trimmed rows, each a
tree crest, name and role over a slim health bar. The first row is the live
champion (name and role from `ClassKit`, health straight off `player.hp`); the
second is **Maelis Orr**, the cleric companion, with her real health and state
(`In the square` / `Following` / `Downed`).
- **Objective bar** — a `COMBATANT` header, one gold segment per wave (lit up to
the current wave), the `Wave n / 3` ticker and the run timer, which `main.gd`
feeds from `arena_time`. It appears with the wave loop and hides in the square.
- **Nameplates** (`scripts/nameplate.gd`) — colour-coded faction tags over a
`Label3D`: the champion is a gold **COMBATANT**, the sparring dummy and the
cleric companion a green **ALLY**, and every arena foe (warden, harrier,
bulwark) **CORRUPTED** in red.
The plates billboard and draw over geometry.
- **Icon hotbar** — five slots whose skills carry drawn icons from
`scripts/skill_icon.gd` (Cleave's arc, Second Wind's gust, Power Shot's bow,
Tumble's chevrons, padlocks for locked slots) above the name and key caption.
Cooldown countdowns and dimming behave as before.

## Wave table

| Wave | Composition | Spawn points |
|---|---|---|
| 1 | Training dummy + arena warden | placed in the scene |
| 2 | 1 harrier + 1 bulwark | `(-8, -33.5)`, `(6.5, -19)` |
| 3 | 1 warden + 1 harrier + 1 bulwark | `(0, -34)`, `(-6.5, -19)`, `(6.5, -33.5)` |

Spawn points sit clear of the central pillar, the four cover boxes, the two
raised platforms and the torch posts at `x = ±6.5` (those posts have collision
and will stop a bolt — the Phase 2 test lane runs along `x = -8` for exactly
that reason).

## Structure

```
ashes-of-albion/
├── project.godot            # 13 input actions (WASD/mouse + 5 hotbar), GL Compatibility, boot scene = title screen
├── shaders/cel.gdshader     # 3-tone cel ramp + ambient floor (dusk-readable)
├── materials/               # 15 cel materials (slate, timber, 4 faction cloths, bars…)
├── scenes/
│   ├── title_screen.tscn    # boot screen: wordmark, four-entry menu, settings panel (volume + fullscreen)
│   ├── character_select.tscn # picker: slot card, dais preview (SubViewport), 8-archetype picker, action bar
│   ├── pause_menu.tscn      # in-world Esc menu: Resume / Skills / Character Select / Title Screen
│   ├── skill_tree.tscn      # Fighter Skill Tree board: Swordcraft branches, ranks, locks, Secondary Archetype rail
│   ├── main.tscn            # world env (dusk sky+fog), moon light, ground, arena trigger, ArenaFoes, ChampionsRow instance
│   ├── player.tscn          # CharacterBody3D + SpringArm3D/Camera3D + sword (bow built at runtime for the ranger)
│   ├── companion.tscn       # Maelis Orr: cleric body, ALLY nameplate, recruit prompt
│   ├── training_dummy.tscn  # damageable + billboard health bar + defeat/reset
│   ├── arena_warden.tscn    # MELEE variant of foe.gd (Phase 1 behaviour)
│   ├── harrier.tscn         # RANGED variant: bow + nocked bolt, blue tabard, projectile_scene wired
│   ├── bulwark.tscn         # SHIELDED variant: shield mesh, green tabard, guard exports
│   ├── projectile.tscn      # cover-aware bolt; friendly mode (player-fired) vs foe-fired
│   ├── lineup.tscn          # Champions' Row: 8-figure lineup (standalone concept view)
│   ├── archetype_figure.tscn# one champion figure (built at runtime by archetype_figure.gd)
│   ├── hud.tscn             # party frames, Combatant objective bar (segments + timer), icon hotbar, stat bars, scoreboard, results panel, minimap, reticle, damage flash
│   └── props/               # market_stall, banner, torch, building (reused by town_layout)
├── scripts/                 # progression (XP, levels, points), save_game (user:// profile), title_screen (front door + settings), heraldic_crest (drawn tree-of-life emblem), select_hall (cathedral backdrop for the dais), skill_tree_data (nodes, ranks, kit effects), skill_tree (board + point spending), skill_icon + tree_links (drawn art), nameplate (ally/combatant/corrupted faction tags), companion (recruitable cleric: follow, heal, down), pause_menu (in-world Esc menu + pause), character_select (commit ClassKit.selected), player (fighter+ranger kits), class_kit (8 archetypes, skills, selection), lineup + archetype_figure, training_dummy, foe (3 variants), projectile, hud (party frames + objective bar + icon hotbar), main (wave loop + apply_class), town_layout
└── tests/
    ├── smoke.tscn/.gd       # 271-check headless suite: loop + class kits + lineup + select + front end + skill tree + HUD + persistence + progression + companion (exit code 0/1, 900 s watchdog)
    ├── probe_harrier.tscn/.gd  # ranged-duel diagnostic (state, distance, bolt count, HP trace)
    ├── probe.gd             # camera placement probe
    └── mesh_audit.gd        # null-mesh audit over main + character select (0 found of 339)
```

## Verification (headless, Godot 4.3-stable)

- `--import`: clean, no parse errors.
- `tests/mesh_audit.gd` (main + character select): **339 mesh instances, 0 null meshes**.
- `tests/smoke.tscn`: **SMOKE_RESULT: PASS — 271/271 checks**, exit code 0
  (900 s watchdog reports FAIL + exit 1 if the run ever stalls).
  - Phase 0/1 (42): spawn zone, camera behind + looking at player `(0, 2.64, 4.01)` / dot `1.0`, WASD movement, mouse camera yaw, arena transition + opponent resets, lock-on target + reticle, cleave damage/cooldown/stamina, basic attack damage/defeat/kill counter/scoreboard, warden strike damaging HP and poise, HUD damage flash, poise-break stagger and recovery, lock-on switching targets, player death, death counter, respawn in the square with full health, zone/opponent reset on return, score preserved, controls preserved after reset.
  - Phase 2 (40): loop restarts at wave 1 on re-entry; wave-clear results panel appears with the right title and run summary; wave 2 spawns exactly the harrier + bulwark and the panel clears; wave counter follows each spawn; bulwark blocks 75 % of frontal damage and drains guard; an attack from behind bypasses the shield; an empty guard breaks the stance (`GUARD_BREAK`) and takes full damage; guard recovers and refills; the bulwark topples on defeat; **the harrier's bolt damages the player from range**; wave 3 spawns three foes; clearing it reports `Arena Cleared`; no wave 4 spawns afterwards; leaving the arena clears spawned foes, resets the wave counter, closes the panel, hides the wave label and resets the placed opponents.
  - Phase 3 (32): the player enters as the fighter; HUD shows `FIGHTER` above the bar with slots named `Cleave`/`Second Wind` and `3–5` locked (`–`); **Cleave hits two foes in one arc** (45 dmg each), enters its 6 s cooldown, dims HUD slot 1, is blocked by stamina without starting its cooldown, and damages the warden on lock-on; **Second Wind** heals 35 HP, starts its 18 s cooldown, shows the countdown on slot 2 and is blocked while recharging; the **weapon combo** chains 25 → 25 → 40 and resets after the 1.2 s window; **Champions' Row** stages all eight champions in concept-image order with readable nameplates, built weapon props, distinct body colours, a collidable plinth, the fighter's greatsword, the summoner's spectral ally and the tank's tower shield; the standalone `lineup.tscn` stages the same eight with its own camera.
  - Phase 4 (34): the select screen lists all eight archetypes, opens on the Fighter with its dais figure and preview camera; the `Rowan Vale` slot card reads as in the concept; picking the Bard swaps the preview and gates Enter World with an explanatory status; picking the Ranger re-enables it and `commit_selection()` writes `ClassKit.selected`; **the world swaps to the ranger live** (HUD `RANGER`, slots `Power Shot`/`Tumble`, bow-controls hint, sword sheathed, bow equipped); **a 25 dmg arrow from 8 m — beyond the 3.2 m melee range — damages the warden**; **Power Shot** costs stamina, starts its 5 s cooldown, lands 50 dmg and dims slot 1; **Tumble** starts its cooldown, grants the evade window and dashes the ranger ≥1.5 m forward; switching back restores the fighter kit, sword and hint; **a freshly instanced world boots as the committed ranger** (class id, HUD label, skill names).
  - Phase 5 (20): the project boots on the title screen; the menu offers all four entries and names the last committed champion; Enter World / Character Select request `main.tscn` / `character_select.tscn`; Settings opens and closes, and its volume slider drives the master audio bus; the picker's Back button is live and returns to the title; the world's pause menu opens over the scene, pauses the tree, resumes and unpauses, the `Esc` key opens it, and its Character Select / Title Screen entries unpause the run and request the right scene.
  - Phase 6 (33): the board opens over the paused world with all eleven nodes staged; the concept's starting ranks (Offensive Form 2/3, Defensive Form 1/3, Cleave 1/3, Sundering Strike 1/3, Fortify 1/3) leave two points and two gold orbs; pips read `Rank 1/3`; Whirlwind, Armor Break and Bulwark read `Locked` and refuse ranks; the Secondary Archetype rail reads `Level 25`; spending on Cleave raises its live damage by 6 and spending on Second Wind raises its live heal by 8, then the empty pool blocks further ranks; **Reset** refunds all eight points and returns Cleave to 45 and Second Wind to 35; closing unpauses; and the pause menu's **Skills** button opens the board.
  - Phase 7 (19): the HUD reads out the champion's level; the HUD stages the champion and the cleric, the champion's frame names the class and tracks live health, and the cleric's frame carries her name and health; the objective bar follows the live wave loop, lights up to the current wave, carries one segment per wave plus the `Wave n / 3` ticker, and formats the run timer as `0:42`; the bar hides again when the run ends; the hotbar stages five icons with Cleave's arc on slot 1 and padlocks on locked slots; the champion's nameplate reads **COMBATANT**, the sparring dummy **ALLY** and the arena warden **CORRUPTED**.
  - Phase 8 (16): the run writes a save file; champion class, level, experience, secondary archetype, skill-tree ranks and the audio setting all survive a relaunch; a missing file reports no data; **the title screen restores the saved champion, level and name on boot**; the picker's slot card shows the persisted level and committing a champion writes the save; spending a skill point writes the new rank; and the scratch save is cleaned up.
  - Phase 9 (19): a fresh run starts at the concept's level 12 with its eight-point pool; a kill awards experience and a kill can complete a level; levels grant skill points and the tree pool grows by the extra point; the kill path banks XP and the HUD readout follows; the Secondary Archetype rail is locked below 25 (padlock, `Level 25` hint, refuses a pick), opens at 25 with all eight archetypes, remembers the choice and writes it to the save.
  - Phase 10 (16): the square stages the cleric unrecruited with an `ALLY` plate; her party frame names her; she can be recruited at full health and the frame reads her live health; she follows the champion; she heals a wounded champion, starts the cooldown, respects it and holds the heal at full health; she can be downed (frame drops to zero) and cannot heal while down, then revives at half health and the frame recovers.
- Main scene `--quit-after 240` frames: no script errors or warnings.
- Title screen `--quit-after 240` frames: no script errors or warnings.
- Character-select scene `--quit-after 240` frames: no script errors or warnings.

Headless-only noise: `Parameter "m" is null` lines from the dummy renderer when
runtime `Label3D` damage numbers are created — no scene node lacks a mesh; this
does not occur with a real renderer.

### Needs a manual run (visual, not verifiable headless)

1. Palette/lighting against the concept set: cool blue dusk vs warm gold torchlight,
   2–3 cel tones, soft shadows, distance fog.
2. HUD placement vs concept image 6 (party frames top-left, Combatant objective
   bar with segments + timer top-centre, icon hotbar bottom-centre, faction
   nameplates over champion/ally/corrupted foes) and player framing ≈ 1/3 frame height.
3. Walk feel: sprint, jump onto the arena platforms, spring-arm camera collision
   against stalls/walls; lock-on reticle centered on the dummy/warden.
4. Damage numbers/health bar billboarding readability at gameplay distance.
5. Combat feel: warden approach speed and `!` telegraph readability, stagger
   duration (1 s), red damage-flash intensity, cleave/combo impact timing.
6. Phase 2 feel: harrier kiting distance and bolt speed/visibility, the bulwark's
   `BROKEN` telegraph readability, guard-break punish window (3 s), results-panel
   placement and 4 s auto-dismiss, wave spawn choreography (2 s gap).
7. Phase 3 look: **Champions' Row vs concept image 2** — silhouette/colour
   identity of all eight (order, headgear, weapons, summoner ally), nameplate
   readability, the plinth and sign framing; open `lineup.tscn` (F6) for the
   clean comparison view.
8. Companion feel: Maelis's ALLY plate and recruit prompt readability in the
   square, her follow spacing and turn as you walk, the heal timing/cooldown,
   the downed pose and how clearly the party frame reports `Following` /
   `Downed`.
8. Phase 3 feel: **Cleave arc readability** (wide swing + how many foes it
   catches), combo finisher impact (25/25/40 cadence and the 1.2 s window),
   Second Wind feedback (heal number/green flash), HUD class label + skill-slot
   layout (names, locked slots, cooldown dim/countdown) vs concept image 4.
9. Phase 4 look: **character select vs concept image 3** — panel layout, gold
   trim on dark parchment, dais lighting/framing of the champion, archetype
   rows with flavor lines, bottom action bar, and whether the preview figure
   faces the camera; every archetype's preview swaps cleanly.
10. Phase 4 feel: **ranger combat** — arrow travel/impact visibility at 8–14 m,
    lock-on bolt curving to the target, Power Shot weight vs basic arrows,
    Tumble distance/speed and the i-frame window (does a warden swing pass
    through you mid-dash?), sword↔bow swap on class change, HUD hint swap.
11. Phase 5 look: **title screen** — wordmark scale/outline, the dusk gradient,
    the crest and banners, gold trim on the four menu entries, focus highlight
    and the settings panel; and **the dais hall vs concept image 3** — do the
    arches read as gothic, is the banner/torch lighting warm enough against the
    blue moonlight, are the ghost plinths legible, and is the champion framed
    like the concept rather than lost in the hall?
12. Phase 5 feel: **front-end flow** — title → Enter World with the last
    champion, title → Character Select → Back, and the in-world `Esc` menu:
    pause/unpause, mouse release/recapture, and both exits back to the front end.

## Next recommended milestone

**Phase 7 — the Mage (third playable class), then the social screens:** `ClassKit`
and `player.setup_class()` already branch by data (ranged flag + skill names),
and `projectile.tscn`'s friendly mode gives the Mage an instant bolt; its
identity would come from an area skill (a ground-target nova reusing
`_arc_targets`) and the wide-hat figure already previewable on the dais. After
that, encounter groundwork: `foe.gd` adds a variant by export values and
`_composition()` in `main.gd` is a plain wave table, so elite waves, mixed
reinforcements and a boss wave are data changes rather than new systems.
