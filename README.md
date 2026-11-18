# Ashes of Albion — Phase 0–5 Prototype

A playable Godot 4.3 vertical slice of the AoC-mechanics MMO with Albion-style
art direction: it boots to a **title screen** (concept image 1 — gold-trim menu
over an orbiting torchlit diorama), then to the **character-select screen**
(concept image 3 — character slots, a dais preview of your champion, the
eight-archetype picker), a **Town Hall** screen for the **Citizenship &
Election** panel (concept image 5 — claim citizenship of Ashford and vote in
the mayoral ballot, whose sealed mandate then changes the world), and from
there into the dusk town square beside
**Champions' Row** (the lineup from concept image 2). Walk the market street into the arena and fight a
**three-wave encounter** against three foe archetypes (melee warden, ranged
harrier, shielded bulwark), with a results panel after each cleared wave.
Two classes are playable: the **Fighter** (three-hit combo, Cleave, Second
Wind) and the **Ranger** (bow shots, Power Shot, Tumble). Lock on, trade blows
on a poise/stagger system, die and respawn if you lose, then return to the
square with the loop reset and your score preserved.

## Run it

- Open `ashes-of-albion/project.godot` in **Godot 4.3+** (GL Compatibility renderer, no extra assets required) and press **F5**.
- Boot scene: **`res://scenes/title_screen.tscn`** (already set as the project main scene) → **Enter World** (world with last committed class, Fighter by default) or **Character Select** → pick an archetype → **Enter World**; **Town Hall** opens the citizenship & election panel. `Settings` is a Phase 6 stub; `Exit` quits.
- World scene: **`res://scenes/main.tscn`** (loads directly with the last committed class; useful for debugging, defaults to the Fighter).
- Standalone lineup view: run **`res://scenes/lineup.tscn`** (F6) for a clean concept view of the eight champions.
- Headless verification: `godot --headless --path ashes-of-albion res://tests/smoke.tscn`

## Controls

| Input | Action |
|---|---|
| `W A S D` | Move (camera-relative) — on the select screen: `W`/`S` or arrows cycle archetypes |
| Mouse | Orbit camera (over-the-shoulder, spring-arm collision) — on the select screen: click rows and buttons |
| `Shift` | Sprint (drains stamina) |
| `E` | At the Town Hall door (the building south of the spawn): open the Citizenship & Election panel. `Back`/`Esc` closes it back into the square |
| `Space` | Jump |
| `Q` | Lock on / off nearest attackable target (reticle appears; ranger bolts auto-aim at it) |
| `LMB` | **Fighter:** weapon combo 25 → 25 → **40 finisher** (0.5 s cooldown; chain resets after 1.2 s) · **Ranger:** loose an arrow (25 dmg, ranged) |
| `1` | **Fighter:** **Cleave** — 45 dmg arc (4.5 m cone, hits every foe), 30 stamina, 6 s CD · **Ranger:** **Power Shot** — 50 dmg bolt, 25 stamina, 5 s CD |
| `2` | **Fighter:** **Second Wind** — heals 35 HP + 25 stamina, 18 s CD · **Ranger:** **Tumble** — evade dash with brief i-frames, 7 s CD |
| `3`–`5` | Locked slots (`–`, dimmed) until their classes exist |
| `Enter` | On the select screen: Enter World (with the highlighted playable class) |
| `LMB` | Title/select: click menu buttons · Town Hall: click the tabs, claim/renounce citizenship, the housing tick, a ballot row, Cast ballot or a mandate · In world: attack |
| `Esc` | Title: quit · Select: back to the title · Town Hall: back to the title, or back to the square when opened in-world · In world: open the pause menu (Resume / Settings / Return to Title) · Pause menu: resume |

## The loop

1. Spawn in the town square (`z = +8`) facing north; HUD shows zone **Town Square**.
2. Walk the torch-lit path past 4 market stalls, 10 faction banners, 16 torches
   and 7 stone/timber buildings (all built from reusable prop scenes). The
   building south of the spawn is the **Town Hall**, marked by a gold floating
   sign; its door is an `E` interaction point that opens the Citizenship &
   Election panel over the running world.
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

## Title screen (concept image 1)

`res://scenes/title_screen.tscn` is the boot scene: a gold-trimmed dark panel
with **ASHES OF ALBION**, the tagline `Eight archetypes. One realm.`, a divider
and the concept's menu buttons plus **Town Hall** — **Enter World** (gold,
focused), **Character Select**, **Town Hall**, **Settings**, **Exit** — over a
3D diorama (two torches, a banner and a moonlit floor disc) with a slowly
orbiting camera. Hints bottom left, `Prototype 0.5 · Phase 5` bottom right.

- **Enter World** drops straight into the world with the last committed
  `ClassKit.selected` (Fighter by default).
- **Character Select** opens the archetype picker; its **Back** button (or
  `Esc`) returns here without committing anything.
- **Town Hall** opens the Citizenship & Election panel (its **Back** or `Esc`
  returns here).
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

## Town Hall (concept image 5)

`res://scenes/town_hall.tscn` (title → **Town Hall**, the town-hall door in the
world, or F6) is part of the Phase 5 front end and keeps the build's
`Prototype 0.5 · Phase 5` tag. It turns the Citizenship & Election concept into
a screen. The backdrop is the town hall at
night — a stone facade with a gilded arch and warm windows, four faction
banners (gold, blue, green, purple), flickering wall torches, a full moon and
distant rooftops — built from engine primitives in `town_hall.gd`, while
`ui_glyph.gd` draws the hourglass, sun, coin stack, crossed swords, flask,
scroll, hammer, house and check icons procedurally.

- **Citizenship** (left): the settlement card reads **Ashford** ·
  `SETTLEMENT · ALBION`. **Claim citizenship** is one per server and is the
  gateway to the whole hall: a claim registers the **ZOI house** (the housing
  tick comes on and only a citizen can toggle it), makes Ashford **home and
  respawn** — a citizen who falls returns to the hall forecourt instead of the
  birth spawn — and unlocks the **mayoral ballot**. **Renounce citizenship**
  takes all three away, hands the birth spawn back and starts the **14-day
  cooldown** (`Claim in 13d 23h` on the button) before Ashford can be claimed
  again. The cooldown box reads `14d 00h` as the rule and counts down while it
  runs; the footer reads `One citizenship per server`.
- **Election** (right): the **Mayoral Ballot** lists **Aveline** (Divine),
  **Merrin** (Economic), **Garrick** (Military) and **Ilyra** (Scientific),
  each with a portrait initial, mandate glyph and role chip, and the incumbent
  line above the list names the sitting mayor (or the empty seat). The
  **24:00:00** clock runs down in real time; clicking a row fills its radio and
  arms **Cast ballot** — only a citizen of Ashford may cast one. **Mayor's
  Mandate** holds
  **Propose policy**, **Adjust taxes** and **Issue commissions** — they report
  that the mandate unlocks for the winner once the ballot closes, and turn away
  anyone who isn't a citizen.
- **The election lifecycle** (`ElectionKit`): the ballot opens on a 24 h clock
  with Ashford's opening tallies (Aveline 4, Merrin 3, Garrick 2, Ilyra 1).
  **Cast ballot** (citizens only) adds your vote to the picked candidate's tally
  and **locks the ballot** — one vote per election, so the rows and the button stay disabled,
  and the lockout survives closing the hall and relaunching. When the clock
  reaches `00:00:00` the count opens on its own: the results panel replaces the
  ballot with every candidate's tally, the winner and the incumbent. A level top
  tally is a **tie** — nobody is elected, and the sitting mayor keeps office and
  their mandate. **Open the next election** starts the next cycle with a fresh
  24 h clock, an unlocked ballot and the incumbent one vote ahead in the opening
  tallies.
- **The mandate:** a winner's mandate is sealed into `MandateKit` and hits the
  world at once — **Divine** (Aveline) mends `+2 HP/s`; **Economic** (Merrin)
  pays triple crowns per defeat (10 → 30); **Military** (Garrick) adds a bulwark
  to every wave; **Scientific** (Ilyra) scales every skill cooldown to 60 %
  (Cleave 6 s → 3.6 s). The HUD gains a `MANDATE · <MAYOR> <role> — <effect>`
  line under the scoreboard and a `Crowns` purse, and a world entered after the
  vote boots under the same mandate.
- The two tabs raise the matching panel's gold border and focus its primary
  control; both halves stay visible as in the concept. **Back** / `Esc` returns
  to the title.
- **In the world:** walk to the Town Hall door south of the spawn (gold
  `TOWN HALL` sign, HUD prompt) and press `E`. The panel opens over the running
  world as an overlay — the tree pauses (foes, timers and the wave loop stop),
  the door prompt clears, the mouse is released and the score/run is untouched —
  and **Back** / `Esc` closes it back into the square.
- Saved state: citizenship, the ZOI house registration and the renounce cooldown
  live in `user://town_hall.json` (`TownHallSave`); the election — tallies, the cast
  ballot, the countdown's end, the incumbent and the cycle — lives in
  `user://election.json` (`ElectionKit`). Both countdowns are Unix stamps, so they
  keep running while the game is closed and resume at the right second on the
  next launch; closing the game mid-election resumes the same ballot. The
  housing toggle and an uncats row pick stay session-only.

## Pause menu (`Esc` in the world)

`res://scenes/pause_menu.tscn` opens over the running world on `Esc`: a dim
backdrop, a gold-trimmed `PAUSED` panel against the same dark parchment as the
Town Hall, and three entries.

- **Resume** (or `Esc` again) hands the world back and recaptures the mouse.
- **Settings** reports the same Phase 6 stub as the title screen's button.
- **Return to Title** closes the run and loads `title_screen.tscn`.

The pause menu and the Town Hall share one handoff: both are `OverlayPanel`s
opened through `main.open_overlay()`, so there is one overlay at a time, the
tree is paused while it is open and its `closed` signal is the only way back.
Neither screen carries freeze or resume code, and both roots are
`PROCESS_MODE_ALWAYS` so the overlay keeps running while the world does not.

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
├── project.godot            # 14 input actions (WASD/mouse + 5 hotbar + interact), GL Compatibility, boot scene = title screen
├── shaders/cel.gdshader     # 3-tone cel ramp + ambient floor (dusk-readable)
├── materials/               # 15 cel materials (slate, timber, 4 faction cloths, bars…)
├── scenes/
│   ├── title_screen.tscn    # boot screen: gold-trim menu (Enter World / Select / Town Hall / Settings / Exit) over an orbiting torch+banner diorama
│   ├── character_select.tscn # slot card, dais preview (SubViewport), 8-archetype picker, action bar (Back → title)
│   ├── town_hall.tscn       # Citizenship & Election panel: Ashford claim, 24 h mayoral ballot with cast/lockout/results/next cycle, mayor's mandate, night facade; title screen and in-world overlay
│   ├── main.tscn            # world env (dusk sky+fog), moon light, ground, arena trigger, Town Hall sign/door, ArenaFoes, ChampionsRow instance
│   ├── player.tscn          # CharacterBody3D + SpringArm3D/Camera3D + sword (bow built at runtime for the ranger)
│   ├── training_dummy.tscn  # damageable + billboard health bar + defeat/reset
│   ├── arena_warden.tscn    # MELEE variant of foe.gd (Phase 1 behaviour)
│   ├── harrier.tscn         # RANGED variant: bow + nocked bolt, blue tabard, projectile_scene wired
│   ├── bulwark.tscn         # SHIELDED variant: shield mesh, green tabard, guard exports
│   ├── projectile.tscn      # cover-aware bolt; friendly mode (player-fired) vs foe-fired
│   ├── lineup.tscn          # Champions' Row: 8-figure lineup (standalone concept view)
│   ├── archetype_figure.tscn# one champion figure (built at runtime by archetype_figure.gd)
│   ├── pause_menu.tscn      # in-world Esc overlay: PAUSED panel, Resume / Settings / Return to Title
│   ├── hud.tscn             # bars, class label + 5 skill slots, class-aware controls hint, town-hall prompt, scoreboard, wave counter, mandate + crowns line, results panel, minimap, reticle, damage flash
│   └── props/               # market_stall, banner, torch, building (reused by town_layout)
├── scripts/                 # ui_style (the gold/dark button boxes shared by title, select, hall and pause menu), overlay_panel (the `closed` contract every overlay shares), pause_menu (Esc menu: Resume/Settings/Return to Title), title_screen (front-end loop), character_select (select + commit ClassKit.selected), town_hall (citizenship + ballot panels + night diorama), election_kit (ballot lifecycle, tallies, ties, incumbent, cycles, save), town_hall_save (citizenship, ZOI house, renounce cooldown save), mandate_kit (sealed mayor's mandate + world modifiers), ui_glyph (drawn panel icons), player (fighter+ranger kits + Esc/Back flow + home respawn), class_kit (8 archetypes, skills, selection), lineup + archetype_figure, training_dummy, foe (3 variants), projectile, hud, main (wave loop + apply_class + citizenship perks + mandate + the shared overlay handoff), town_layout
└── tests/
    ├── smoke.tscn/.gd       # 300-check headless suite: loop + class kits + lineup + character select + title screen + town hall + election lifecycle + citizenship + pause menu (exit code 0/1, 900 s watchdog)
    ├── probe_harrier.tscn/.gd  # ranged-duel diagnostic (state, distance, bolt count, HP trace)
    ├── probe.gd             # camera placement probe
    └── mesh_audit.gd        # null-mesh audit over title + main + character select + town hall (0 found of 337)
```

## Verification (headless, Godot 4.3-stable)

- `--import`: clean, no parse errors.
- `tests/mesh_audit.gd` (title + main + character select + town hall): **337 mesh instances, 0 null meshes**.
- `tests/smoke.tscn`: **SMOKE_RESULT: PASS — 300/300 checks**, exit code 0
  (900 s watchdog reports FAIL + exit 1 if the run ever stalls).
  - Phase 0/1 (42): spawn zone, camera behind + looking at player `(0, 2.64, 4.01)` / dot `1.0`, WASD movement, mouse camera yaw, arena transition + opponent resets, lock-on target + reticle, cleave damage/cooldown/stamina, basic attack damage/defeat/kill counter/scoreboard, warden strike damaging HP and poise, HUD damage flash, poise-break stagger and recovery, lock-on switching targets, player death, death counter, respawn in the square with full health, zone/opponent reset on return, score preserved, controls preserved after reset.
  - Phase 2 (40): loop restarts at wave 1 on re-entry; wave-clear results panel appears with the right title and run summary; wave 2 spawns exactly the harrier + bulwark and the panel clears; wave counter follows each spawn; bulwark blocks 75 % of frontal damage and drains guard; an attack from behind bypasses the shield; an empty guard breaks the stance (`GUARD_BREAK`) and takes full damage; guard recovers and refills; the bulwark topples on defeat; **the harrier's bolt damages the player from range**; wave 3 spawns three foes; clearing it reports `Arena Cleared`; no wave 4 spawns afterwards; leaving the arena clears spawned foes, resets the wave counter, closes the panel, hides the wave label and resets the placed opponents.
  - Phase 3 (32): the player enters as the fighter; HUD shows `FIGHTER` above the bar with slots named `Cleave`/`Second Wind` and `3–5` locked (`–`); **Cleave hits two foes in one arc** (45 dmg each), enters its 6 s cooldown, dims HUD slot 1, is blocked by stamina without starting its cooldown, and damages the warden on lock-on; **Second Wind** heals 35 HP, starts its 18 s cooldown, shows the countdown on slot 2 and is blocked while recharging; the **weapon combo** chains 25 → 25 → 40 and resets after the 1.2 s window; **Champions' Row** stages all eight champions in concept-image order with readable nameplates, built weapon props, distinct body colours, a collidable plinth, the fighter's greatsword, the summoner's spectral ally and the tank's tower shield; the standalone `lineup.tscn` stages the same eight with its own camera.
  - Phase 4 (34): the select screen lists all eight archetypes, opens on the Fighter with its dais figure and preview camera; the `Rowan Vale` slot card reads as in the concept; picking the Bard swaps the preview and gates Enter World with an explanatory status; picking the Ranger re-enables it and `commit_selection()` writes `ClassKit.selected`; **the world swaps to the ranger live** (HUD `RANGER`, slots `Power Shot`/`Tumble`, bow-controls hint, sword sheathed, bow equipped); **a 25 dmg arrow from 8 m — beyond the 3.2 m melee range — damages the warden**; **Power Shot** costs stamina, starts its 5 s cooldown, lands 50 dmg and dims slot 1; **Tumble** starts its cooldown, grants the evade window and dashes the ranger ≥1.5 m forward; switching back restores the fighter kit, sword and hint; **a freshly instanced world boots as the committed ranger** (class id, HUD label, skill names).
  - Phase 5 (9): the project boots to `title_screen.tscn`; the title carries the game title; the menu offers its five entries and every button is wired to its handler; the version tag names the phase; Settings is a stub promising Phase 6; the backdrop diorama slowly orbits; the select screen's **Back** button is enabled and wired to return to the title.
  - Phase 5 · Town Hall (25): the Town Hall carries both halves of the panel; the tabs label and raise them, opening on Election; the ballot lists four candidates with Aveline (Divine), Merrin (Economic), Garrick (Military) and Ilyra (Scientific) in order, each with a mandate glyph; the clock starts at `24:00:00` and formats hours/minutes/seconds; the ballot opens unpicked and follows two different picks; housing in the ZOI is checked by default; the citizenship claim is available once, then disables and confirms; the renounce cooldown reads `14d 00h`; the mandate offers three actions that report to the ballot; Back is wired to the title.
  - World Town Hall entry (10): the southern building is the Town Hall door and the HUD prompts there; `E` opens the panel over the world, pausing the tree, clearing the door prompt and releasing the mouse; the overlay is live (a citizenship claim works); Back closes back into the world, resuming play, preserving the run and bringing the prompt back.
  - Phase 5 · pause menu (17): the world reports no overlay; `Esc` opens the pause menu, which is not the Town Hall, and pauses the tree; a second open keeps the one overlay; the menu offers Resume, Settings and Return to Title, and Return to Title is wired to the world; Settings reports the Phase 6 stub and stays inside the menu; Resume hands the world back and gives the player movement again; `Esc` resumes from the menu; the Town Hall then proves the same handoff — one overlay slot (a second overlay is refused while it is open), the shared freeze, and the shared resume path.
  - Phase 5 · election lifecycle (65): a fresh session opens election I with no incumbent and no cast ballot; the citizen casts one ballot (the tally grows) and a second is refused; the count waits for the clock, the expired clock opens it, the top tally is elected, becomes the incumbent and seals their mandate, and a counted ballot does not count twice; the count, the lockout and the incumbent survive a relaunch from `user://`; the next cycle clears the lockout, restarts the 24 h clock and opens the incumbent one vote ahead; a level tally resolves as a tie, names every leader, keeps the incumbent and their mandate in place and still rolls into the next cycle; in the hall the cast button arms only after a pick, casting locks every row and the button, a cast ballot cannot be changed or recast, the expired clock shows the results panel with all four tallies, the elected name, the incumbent and `00:00:00`, and **Open the next election** rolls the cycle over on a fresh 24 h clock; the in-world hall hands the counted mandate to the HUD live, restores the results and the lockout on reopen and can open the next cycle; the four mandates still change the world (Economic 30-crown defeats + purse, Divine healing, Scientific Cleave at 3.6 s) and a world entered afterwards boots under the sealed mayor; resetting restores the plain waves and HUD.
  - Phase 5 · citizenship (26): a fresh citizen sheet holds no claim and no ZOI house, and a visitor respawns at the birth spawn; the hall disables the housing tick and renounce for a visitor, and a non-citizen cannot arm or cast the ballot (the ballot line asks for citizenship); claiming writes the citizenship, registers the ZOI house, reports it in the panel, sets Ashford's hall as home/respawn, unlocks the ballot and lets the citizen vote; unchecking housing unregisters the house; renouncing removes citizenship, the house and the hall respawn, starts the 14-day cooldown, shows `Claim in …` and refuses an early re-claim; when the cooldown ends the claim unlocks, restores the house and home, and a citizen's respawn lands at Ashford's hall.
- Main scene `--quit-after 180` and `pause_menu.tscn` `--quit-after 120` frames: no script errors or warnings.
- Title-screen scene `--quit-after 240` frames: no script errors or warnings.
- Character-select scene `--quit-after 240` frames: no script errors or warnings.
- Town Hall scene `--quit-after 120` frames: no script errors or warnings.

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
    select → world → `Esc` (pause menu) → **Resume** with the mouse recaptured
    → `Esc` → **Return to Title** → `Enter World`; the pause menu's Settings
    reports the Phase 6 stub; `Esc` on the title quits; `Enter World` from the
    title enters with the last committed class.
13. World entry: walk south from the spawn to the Town Hall's gold sign, check the door prompt and `E`, then **Back** — the run, position and score should survive. Town Hall look: **Citizenship & Election vs concept image 5** — the panel
    split and proportions, gold trim on dark parchment, the night hall behind
    (banners, torches, moon), portrait/mandate glyph readability, role-chip
    colours, and the 24 h clock box. Feel: tab switching, claiming
    citizenship, the housing toggle, selecting all four candidates and reading
    the three mandate actions.

## Next recommended milestone

**Phase 6 — Settings screen and a third class:** the title's `Settings` button
and the pause menu's **Settings** entry both report that the screen arrives in
Phase 6 — build it as a real screen (audio volumes, keybind remap, camera
sensitivity/fullscreen, all persisted across sessions) reachable from both.
Third playable class after that: **Mage** —
`ClassKit` and `player.setup_class()` already branch by data (ranged flag +
skill names), and `projectile.tscn`'s friendly mode gives it an instant bolt;
its identity would come from an area skill (a ground-target nova reusing
`_arc_targets`) and the wide-hat figure already previewable on the dais.
Encounter groundwork stays open: `foe.gd` adds a variant by export values,
`_composition()` in `main.gd` is a plain wave table.
