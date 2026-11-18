# Ashes of Albion — Phase 0–5 Prototype

A playable Godot 4.3 vertical slice of the AoC-mechanics MMO with Albion-style
art direction: it boots to a **title screen** (concept image 1 — gold-trim menu
over an orbiting torchlit diorama), then to the **character-select screen**
(concept image 3 — character slots, a dais preview of your champion, the
eight-archetype picker), and from there into the dusk town square beside
**Champions' Row** (the lineup from concept image 2). Walk the market street into the arena and fight a
**three-wave encounter** against three foe archetypes (melee warden, ranged
harrier, shielded bulwark), with a results panel after each cleared wave.
Two classes are playable: the **Fighter** (three-hit combo, Cleave, Second
Wind) and the **Ranger** (bow shots, Power Shot, Tumble). Lock on, trade blows
on a poise/stagger system, die and respawn if you lose, then return to the
square with the loop reset and your score preserved. Every combat actor is
**combat-flagged** — Ally, Combatant, Corrupted or Neutral — with a tag chip
above its head and a top-centre target frame plus an arena clock to match the
combat HUD concept (image 4).

## Run it

- Open `ashes-of-albion/project.godot` in **Godot 4.3+** (GL Compatibility renderer, no extra assets required) and press **F5**.
- Boot scene: **`res://scenes/title_screen.tscn`** (already set as the project main scene) → **Enter World** (world with last committed class, Fighter by default) or **Character Select** → pick an archetype → **Enter World**. `Settings` is a Phase 6 stub; `Exit` quits.
- World scene: **`res://scenes/main.tscn`** (loads directly with the last committed class; useful for debugging, defaults to the Fighter).
- Standalone lineup view: run **`res://scenes/lineup.tscn`** (F6) for a clean concept view of the eight champions.
- Headless verification: `godot --headless --path ashes-of-albion res://tests/smoke.tscn`

## Controls

| Input | Action |
|---|---|
| `W A S D` | Move (camera-relative) — on the select screen: `W`/`S` or arrows cycle archetypes |
| Mouse | Orbit camera (over-the-shoulder, spring-arm collision) — on the select screen: click rows and buttons |
| `Shift` | Sprint (drains stamina) |
| `Space` | Jump |
| `Q` | Lock on / off nearest attackable target (reticle appears; ranger bolts auto-aim at it) |
| `LMB` | **Fighter:** weapon combo 25 → 25 → **40 finisher** (0.5 s cooldown; chain resets after 1.2 s) · **Ranger:** loose an arrow (25 dmg, ranged) |
| `1` | **Fighter:** **Cleave** — 45 dmg arc (4.5 m cone, hits every foe), 30 stamina, 6 s CD · **Ranger:** **Power Shot** — 50 dmg bolt, 25 stamina, 5 s CD |
| `2` | **Fighter:** **Second Wind** — heals 35 HP + 25 stamina, 18 s CD · **Ranger:** **Tumble** — evade dash with brief i-frames, 7 s CD |
| `3`–`5` | Locked slots (`–`, dimmed) until their classes exist |
| `Enter` | On the select screen: Enter World (with the highlighted playable class) |
| `LMB` | Title/select: click menu buttons · In world: release the mouse — click the world again to recapture (that click never swings) |
| `Esc` | Title: quit · Select: back to the title · In world: 1st press releases the mouse (camera look off), 2nd press returns to character select |

## The loop

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

## Combat flagging

Every combat actor carries a **combat flag** using the vocabulary from the
combat HUD concept (image 4): **Ally** (green), **Combatant** (purple),
**Corrupted** (crimson) and **Neutral** (grey). `scripts/combat_flags.gd` is the
single source of truth for the labels and colours, and the same flag is read in
two places:

- **World chip:** a billboarded tag above the actor's head — dark plate,
  flag-coloured border, flag label and the concept's downward chevron. It is a
  quad plus a flat triangle, so it needs no glyphs or textures. Arena foes are
  `Combatant`, the training dummy is `Neutral`, and all eight champions in
  Champions' Row are `Ally`. A fallen actor's chip drops with it and returns on
  reset.
- **HUD target frame:** lock-on (`Q`) brings up the top-centre panel with the
  target's flag (upper case, in its colour), the target's name and a
  six-segment health bar in the flag's colour with `hp / max hp` over it. It
  clears when lock-on drops or the target falls.

`main.gd` also feeds the arena clock to the HUD: the gold hourglass row under
the wave counter shows the run's `mm:ss` and hides again back in the square.

Flags are data — `foe.gd` and `training_dummy.gd` export `combat_flag`, so a
corrupted variant is one export away, and `CombatFlags.is_hostile()` already
treats `Corrupted` as hostile alongside `Combatant`.

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

## Title screen (concept image 1)

`res://scenes/title_screen.tscn` is the boot scene: a gold-trimmed dark panel
with **ASHES OF ALBION**, the tagline `Eight archetypes. One realm.`, a divider
and the four menu buttons from the concept — **Enter World** (gold, focused),
**Character Select**, **Settings**, **Exit** — over a 3D diorama (two torches,
a banner and a moonlit floor disc) with a slowly orbiting camera. Hints bottom
left, `Prototype 0.5 · Phase 5` bottom right.

- **Enter World** drops straight into the world with the last committed
  `ClassKit.selected` (Fighter by default).
- **Character Select** opens the archetype picker; its **Back** button (or
  `Esc`) returns here without committing anything.
- **Settings** is a stub that reports it lands in Phase 6; **Exit** and `Esc`
  quit the game.

## Character select (concept image 3)

`res://scenes/character_select.tscn` is the second screen of the front end,
laid out like the
concept: the **CHARACTERS** slot card on the left (`Rowan Vale · Level 12 ·
Albion` plus two empty slots), the **ARCHETYPES** picker on the right (all
eight with their concept flavor lines — "Master the blade.", "Strike from
afar.", …), the chosen champion on a **lit stone dais** in the centre
(SubViewport with its own camera, light and dusk environment; the figure is
the same `archetype_figure.tscn` builder used in Champions' Row, rotated to
face the camera), and the action bar below (`Enter World` live, `Create New` /
`Delete` / `Back` present but disabled, prototype version tag bottom-right).

- Mouse or `W`/`S`/arrows cycle the roster; every archetype can be **previewed**
  on the dais, but **Enter World** is only enabled for playable classes
  (Fighter, Ranger) — the status line explains the rest.
- `Enter` / **Enter World** commits the pick to `ClassKit.selected` and loads
  `main.tscn`, which applies it in `_ready` (so a directly launched world uses
  the last committed class, defaulting to the Fighter). **Back** / `Esc` return
  to the title screen.

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
│   ├── title_screen.tscn    # boot screen: gold-trim menu (Enter World / Select / Settings / Exit) over an orbiting torch+banner diorama
│   ├── character_select.tscn # slot card, dais preview (SubViewport), 8-archetype picker, action bar (Back → title)
│   ├── main.tscn            # world env (dusk sky+fog), moon light, ground, arena trigger, ArenaFoes, ChampionsRow instance
│   ├── player.tscn          # CharacterBody3D + SpringArm3D/Camera3D + sword (bow built at runtime for the ranger)
│   ├── training_dummy.tscn  # damageable + billboard health bar + defeat/reset
│   ├── arena_warden.tscn    # MELEE variant of foe.gd (Phase 1 behaviour)
│   ├── harrier.tscn         # RANGED variant: bow + nocked bolt, blue tabard, projectile_scene wired
│   ├── bulwark.tscn         # SHIELDED variant: shield mesh, green tabard, guard exports
│   ├── projectile.tscn      # cover-aware bolt; friendly mode (player-fired) vs foe-fired
│   ├── lineup.tscn          # Champions' Row: 8-figure lineup (standalone concept view)
│   ├── archetype_figure.tscn# one champion figure (built at runtime by archetype_figure.gd)
│   ├── hud.tscn             # bars, class label + 5 skill slots, class-aware controls hint, scoreboard, wave counter, arena clock, target frame with segmented flag bar, results panel, minimap, reticle, damage flash
│   └── props/               # market_stall, banner, torch, building (reused by town_layout)
├── scripts/                 # title_screen (front-end loop), character_select (select + commit ClassKit.selected), player (fighter+ranger kits + Esc/Back flow), class_kit (8 archetypes, skills, selection), combat_flags (flag table + billboarded tag chips), lineup + archetype_figure, training_dummy, foe (3 variants), projectile, hud (incl. target frame + arena clock), main (wave loop + apply_class), town_layout
└── tests/
    ├── smoke.tscn/.gd       # 157-check headless suite: loop + class kits + lineup + character select + title screen (exit code 0/1, 900 s watchdog)
    ├── probe_harrier.tscn/.gd  # ranged-duel diagnostic (state, distance, bolt count, HP trace)
    ├── probe.gd             # camera placement probe
    └── mesh_audit.gd        # null-mesh audit over title + main + character select (0 found of 285)
```

## Verification (headless, Godot 4.3-stable)

- `--import`: clean, no parse errors.
- `tests/mesh_audit.gd` (title + main + character select): **318 mesh instances, 0 null meshes**.
- `tests/smoke.tscn`: **SMOKE_RESULT: PASS — 180/180 checks**, exit code 0
  (900 s watchdog reports FAIL + exit 1 if the run ever stalls).
  - Phase 0/1 (42): spawn zone, camera behind + looking at player `(0, 2.64, 4.01)` / dot `1.0`, WASD movement, mouse camera yaw, arena transition + opponent resets, lock-on target + reticle, cleave damage/cooldown/stamina, basic attack damage/defeat/kill counter/scoreboard, warden strike damaging HP and poise, HUD damage flash, poise-break stagger and recovery, lock-on switching targets, player death, death counter, respawn in the square with full health, zone/opponent reset on return, score preserved, controls preserved after reset.
  - Phase 2 (40): loop restarts at wave 1 on re-entry; wave-clear results panel appears with the right title and run summary; wave 2 spawns exactly the harrier + bulwark and the panel clears; wave counter follows each spawn; bulwark blocks 75 % of frontal damage and drains guard; an attack from behind bypasses the shield; an empty guard breaks the stance (`GUARD_BREAK`) and takes full damage; guard recovers and refills; the bulwark topples on defeat; **the harrier's bolt damages the player from range**; wave 3 spawns three foes; clearing it reports `Arena Cleared`; no wave 4 spawns afterwards; leaving the arena clears spawned foes, resets the wave counter, closes the panel, hides the wave label and resets the placed opponents.
  - Phase 3 (32): the player enters as the fighter; HUD shows `FIGHTER` above the bar with slots named `Cleave`/`Second Wind` and `3–5` locked (`–`); **Cleave hits two foes in one arc** (45 dmg each), enters its 6 s cooldown, dims HUD slot 1, is blocked by stamina without starting its cooldown, and damages the warden on lock-on; **Second Wind** heals 35 HP, starts its 18 s cooldown, shows the countdown on slot 2 and is blocked while recharging; the **weapon combo** chains 25 → 25 → 40 and resets after the 1.2 s window; **Champions' Row** stages all eight champions in concept-image order with readable nameplates, built weapon props, distinct body colours, a collidable plinth, the fighter's greatsword, the summoner's spectral ally and the tank's tower shield; the standalone `lineup.tscn` stages the same eight with its own camera.
  - Phase 4 (34): the select screen lists all eight archetypes, opens on the Fighter with its dais figure and preview camera; the `Rowan Vale` slot card reads as in the concept; picking the Bard swaps the preview and gates Enter World with an explanatory status; picking the Ranger re-enables it and `commit_selection()` writes `ClassKit.selected`; **the world swaps to the ranger live** (HUD `RANGER`, slots `Power Shot`/`Tumble`, bow-controls hint, sword sheathed, bow equipped); **a 25 dmg arrow from 8 m — beyond the 3.2 m melee range — damages the warden**; **Power Shot** costs stamina, starts its 5 s cooldown, lands 50 dmg and dims slot 1; **Tumble** starts its cooldown, grants the evade window and dashes the ranger ≥1.5 m forward; switching back restores the fighter kit, sword and hint; **a freshly instanced world boots as the committed ranger** (class id, HUD label, skill names).
  - Phase 5 (9): the project boots to `title_screen.tscn`; the title carries the game title; the menu offers all four entries and every button is wired to its handler; the version tag names the phase; Settings is a stub promising Phase 6; the backdrop diorama slowly orbits; the select screen's **Back** button is enabled and wired to return to the title.
  - Combat flagging (23): the warden and harrier report `Combatant` with their scene names and purple chips, the training dummy reports `Neutral`, and all eight champions carry the `Ally` tag; combatants count as hostile while allies do not; a defeated foe's chip drops and returns on reset; locking on raises the top-centre target frame with the right flag, name, live health and a bar that drains on damage, then clears with the lock; the arena clock is hidden in the square, appears in the arena, reads `mm:ss` and counts up.
- Main scene `--quit-after 240` frames: no script errors or warnings.
- Title-screen scene `--quit-after 240` frames: no script errors or warnings.
- Character-select scene `--quit-after 240` frames: no script errors or warnings.

Headless-only noise: `Parameter "m" is null` lines from the dummy renderer when
runtime `Label3D` damage numbers are created — no scene node lacks a mesh; this
does not occur with a real renderer.

### Needs a manual run (visual, not verifiable headless)

1. Palette/lighting against the concept set: cool blue dusk vs warm gold torchlight,
   2–3 cel tones, soft shadows, distance fog.
2. HUD placement vs concept image 4 (bars bottom-left, hotbar bottom-center,
   minimap top-right, scoreboard top-center) and player framing ≈ 1/3 frame height.
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
11. Phase 5 look: **title screen vs concept image 1** — panel proportions and
    gold trim, title/tagline/divider typography, button hierarchy (gold
    `Enter World` vs dark secondaries), and the diorama behind it: torchlight
    flicker, banner, moonlit floor, orbit speed (too fast reads as a spin).
12. Phase 5 feel: the whole **front-end loop by mouse and keyboard** — title →
    select → world → `Esc` (mouse up) → `Esc` (back to select) → `Back` →
    title; clicking the world recaptures the mouse *without* swinging; `Esc`
    on the title quits; `Enter World` from the title enters with the last
    committed class.
13. Combat-flagging look: **flag chips vs the combat HUD concept (image 4)** —
    plate/border proportions, label colour at gameplay distance, the chevron,
    and the `Ally` tags over Champions' Row not crowding their nameplates; the
    **target frame** flag colour, segmented bar and `hp / max hp` text, plus
    the hourglass clock row under the wave counter.

## Next recommended milestone

**Phase 6 — Settings screen, a third class and in-world Esc-menu polish:**
the title's `Settings` button currently reports it arrives in Phase 6 — build
it as a real screen (audio volumes, keybind remap, camera sensitivity/fullscreen,
all persisted across sessions) reachable from the title and from an in-world
Esc menu (the world's two-stage Esc exists; it needs a panel, resume and
"return to title" alongside it). Third playable class after that: **Mage** —
`ClassKit` and `player.setup_class()` already branch by data (ranged flag +
skill names), and `projectile.tscn`'s friendly mode gives it an instant bolt;
its identity would come from an area skill (a ground-target nova reusing
`_arc_targets`) and the wide-hat figure already previewable on the dais.
Encounter groundwork stays open: `foe.gd` adds a variant by export values,
`_composition()` in `main.gd` is a plain wave table.
