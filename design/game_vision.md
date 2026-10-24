# Cosmocraft: Game Vision

*Brainstorm draft, October 2026. If adopted, this replaces the direction in [plan.md](../plan.md). Everything here is open for debate.*

## The pitch

**A top-down arcade shooter where you take space by surviving inside it, and everything you take builds an empire that makes you stronger.**

The stars have gone dim. Something called the Gloom swallowed the light of this arm of the galaxy, and the creatures that thrive in darkness spread through it. You fly a Kindler, a small ship carrying a spark of the old light.

Space is carved into irregular regions. Fly into a dark one, kindle your spark, and hold your ground; the bigger the region, the longer it takes. Light draws the Gloom like moths to a flame, so every claim is a siege. Survive to ignition and the region floods with your color, its yields start flowing to you, and the map is permanently a little brighter.

Encircle a planet with your light and it wakes up. Land, plant a Hearth, and build a base that mines and researches on its own while you're out fighting. Dive into the dark places beneath the surface for relics. Spend it all on tech that makes your ship, your pilot and your colonies stronger, then push the light further.

**Touchstones:** Risk of Rain's teleporter event, Geometry Wars, an Age of Empires tech tree ticking in the background, and Dave the Diver's structure of simple games that feed each other.

Working title stays Cosmocraft; *Starkindler* or *Afterglow* would fit the theme if you want one.

## Pillars

1. **Hold the light.** The signature verb is a siege: pick a zone, commit to it, survive escalating pressure until it's yours. It appears in every mode.
2. **Paint the galaxy.** Every win changes the map permanently, and progress is visible at a glance.
3. **Everything you own works for you.** Claimed regions and bases produce while you play elsewhere, and research runs on real timers, so there's always something new when you come back.
4. **Bite-sized arcade runs.** Every activity is 3–15 minutes with a clear goal and payoff. No long walks, no inventory Tetris ("do tedious things once").
5. **One economy, many games.** Space, surface and depths each give something the others can't, and it all feeds one tech tree. Cross-mode unlocks are what make this one game instead of three minigames.

## How it fits together

```
SPACE (shooter) ──── claim regions ────▶ Lumen (research fuel) + planets wake up
      │
      ▼ land on a planet you've encircled
SURFACE (ARPG) ───── extractors, pylon sieges ────▶ ore, crystal, biomass, survivors
      │
      ▼ caves, ruins, derelicts
DEPTHS (platformer) ── descend, survive the vault ──▶ relics, rare materials
      │
      ▼ all of it flows into
BASE & RESEARCH ──── buildings research on timers, Ages ────▶ better ship, gear, abilities
      │
      └────▶ back to SPACE: claim bigger, darker regions
```

The same verbs and ideas run through every mode:

| | Space | Surface | Depths |
|---|---|---|---|
| Movement | Thrust with drift | Walk | Run and jump |
| Aim and fire | Mouse | Mouse | Mouse |
| Dash | Yes | Yes | Yes |
| The siege | Claim a region | Defend a Lamp Pylon | Hold the relic vault until it opens |
| Light | Claimed regions | Your Hearth's radius | Your lantern |
| Main reward | Lumen, new planets | Materials, survivors | Relics |

The rhythm: seconds of shooting and dodging; minutes-long runs with a target and a payoff; a few minutes at the base between runs collecting production, queueing research and swapping loadouts; and over hours, advancing Ages, opening sectors and pushing toward the galactic Core.

## The Claim

Everything hangs off this mechanic, so it gets prototyped first.

**Regions.** A sector is 20–40 irregular polygons: Voronoi cells from Poisson-disc points with varying density (so sizes vary), one relaxation pass to remove slivers, edges roughened with noise. Each region shows its area, threat, modifier and yields on the map before you commit.

**Frontier rule.** You can only claim regions that border your territory, so the direction you expand is a strategic choice.

**Kindling.** Fly into a frontier region and press E to drop your spark. (A deliberate start lets you scout or pass through without triggering anything.) Progress then fills while your ship is inside the polygon.

- Claim time scales with area: roughly 45 seconds for a small region, 90 for medium, 2–3 minutes for large, 4+ for a boss region.
- Kills drop sparks that add a little progress, so aggressive play beats turtling.
- Leave the polygon and progress pauses, then drains after a short grace period.

**Light heals.** Inside your own territory your shields recharge; in the dark they don't. Because of the frontier rule, your light is always right across the border, so retreating to recharge is always possible. It just costs progress. That decision comes up in every siege.

**Pressure.** The Gloom pours in from the dark beyond the region's edges. A wave director (a credit budget, as in Risk of Rain) ramps intensity with progress, and around 90% a Snuffer elite arrives and goes straight for your spark. The shape matters: narrow regions are corridor fights, wide ones are kiting arenas.

**Ignition.** At 100% the region ignites: a color wave rolls from your ship to every edge, every Gloom creature inside burns away, loot vacuums to you, and the stars and nebula fade in. Hitstop, screen shake, a swell in the music. This is the moment the whole game exists to deliver, so it gets the most polish.

**Modifiers** keep claims from repeating:

| Modifier | Effect |
|---|---|
| Asteroid field | Cover and collision hazards; asteroids can be mined |
| Nebula | Low visibility, shields offline |
| Ion storm | Periodic EMP |
| Gravity well | Pulls ships toward the center |
| Debris field | Extra salvage |
| Nest | Double enemies, double reward |
| Rich vein | Double yield once claimed |

**Planets by encirclement.** Planets sit where several regions meet. Each surrounding region you claim lights a segment of the planet's orbit ring, and completing the ring wakes the planet. Every planet becomes a small campaign of 3–5 claims you can see coming.

**Failure is cheap.** Die and you respawn at your nearest beacon. The region stays dark and you lose any unbanked scrap. You set your own difficulty by which region you pick.

## Space

- **Controls:** twin-stick. WASD thrust with a little drift, mouse aim, left click primary, right click secondary, Space to dash with i-frames. The same scheme carries into the other modes.
- **Weapons:** Blaster → Twin → Spread, Lance (beam), Seekers, Flak, Mines, orbiting Drones, and a Nova burst charged by kills.
- **Hulls grow with the Ages:** Skiff → Corvette → Frigate → Cruiser. You start as a fragile dodger and finish as a capital ship with auto-turrets plowing through swarms. That arc is the power fantasy.
- **Other content:** asteroid mining, derelict hulks to board (a short Depths run), a wandering trader, roaming elites, and a Gloom Heart boss guarding each sector's largest region.
- **Getting around:** claimed regions link up with warp lanes, so you can jump to any of your beacons.

## Planets: ARPG and base

- **Landfall.** Pick a site and plant your Hearth (think Town Center in Age of Empires). It lights a radius you can build in.
- **Extractors** go on resource nodes inside your light and produce on their own.
- **Expanding the light is the Claim on foot.** Plant a Lamp Pylon at your border and defend it while the Gloom comes out of the dark; this is Risk of Rain's teleporter almost literally. Win and your territory grows to reach new nodes.
- **The wilds:** ARPG combat on foot (sidearm, melee, two abilities), ruins, chests, rare materials, survivors to rescue, and entrances to the Depths.
- **Planet types matter.** Each biome (volcanic, ice, jungle, desert, ocean, fungal, crystal, ashen) has a unique resource and one unique building, such as a Geothermal Forge or a Cryo Lab that speeds research. Variety is about what a planet lets you do, not just how it looks.
- **Nights** make the dark more dangerous. Raids on your base can be a setting.

## The Depths: side-view platformer

The fiction justifies the perspective switch: on the surface you see from above, and once you go down, gravity takes over.

- Entrances are caves and ruins on planets, plus derelicts in space.
- Short descents of 3–5 floors built from hand-made room templates, Spelunky-style.
- **The lantern is the core mechanic:** you see only what your light reaches. Upgrades widen it, add flares and reveal the map.
- **The vault:** grabbing a relic seals the chamber, and you hold out until it opens. The siege again.
- **Rewards:** relics (unique ship and pilot mods, Age keystones), rare materials, survivors, lore.
- **Research opens paths.** Grav boots (double jump), grapple, wall-cling and a drill for soft rock come from the Armory, and each opens new routes in old dungeons.
- **Scope warning:** this is the most expensive mode (new controller, level generation, enemy behaviors). It comes last, and everything before it works without it.

## Base and research

Not an RTS: no units to command. You place buildings on a grid inside your light, and they work.

| Building | Job |
|---|---|
| Hearth | Base core; researching here advances your Age |
| Extractor | Sits on a node and produces its resource |
| Refinery | Ore → Alloy, Crystal → Lenses |
| Shipyard | Researches and fits hulls, weapons and modules |
| Armory | Researches pilot weapons, armor and traversal gear |
| Lab | Industry and science: extraction rates, warp lanes, scanners |
| Observatory | Reveals region contents and relic signals on the star map |
| Habitat | Houses rescued survivors, each giving a small passive bonus |
| Lamp Tower | Defense; also extends your light |

**Age of Empires-style research.** Each building has its own tech list and queue, so building more kinds of buildings opens more research. Research runs on real timers while you're out ("Seeker Missiles complete" mid-siege is a great feeling). Timers start short (30 seconds to 2 minutes) and grow. You can queue research from your ship, but placing buildings means being on the planet.

**Ages** are the big milestones. Advancing needs something from every mode, which is the glue holding the game together: a large resource cost, a sector boss's Gloom Heart, a relic, and research time at the Hearth.

| Age | Unlocks |
|---|---|
| Ember | Skiff, blaster, extractors, your first planet |
| Kindled | Refining, missiles, drones, Lamp Pylons, sector 2 |
| Radiant | Warp lanes, beam weapons, planet-unique buildings, Corvette |
| Stellar | Frigate and Cruiser, multi-planet synergies |
| Nova | The road to the Core |

## Economy

Keep the resource count small.

| Resource | Comes from | Spent on |
|---|---|---|
| Lumen | Claimed regions, passively | Research fuel: more territory means faster tech |
| Scrap | Kills and debris in space | Repairs, cheap builds |
| Ore → Alloy | Planet extractors, asteroids | Buildings, hulls |
| Crystal → Lenses | Planets, nebula regions | Weapons, energy tech |
| Biomass | Organic planets | Habitats, healing, bio tech |
| Relics | The Depths, bosses | Age keystones, unique mods |

One global stockpile shared by every base, with no hauling logistics.

## The Gloom

Creatures that evolved in the dark. They aren't evil; they're drawn to light. That explains every siege and gives all three modes one consistent look: black silhouettes with glowing cores, which reads clearly and is cheap to make look good.

- **Space:** mites (swarm), lurkers (ambush from the dark), weavers (mines and webs), snuffers (go for your spark), leviathans (bosses).
- **Surface:** shades, crawlers, and things that only come out at night.
- **Depths:** nests, burrowers, ceiling-droppers.
- Each sector's biome reskins the roster and adds affixes.
- Later, for variety: a human scavenger faction that wants your light for itself.

## Structure and goal

- A persistent campaign on a seeded galaxy; your empire stays.
- Each sector has a Gloom Heart. Clearing the sectors opens the Core, the biggest polygon in the game.
- After that: New Game+ on a fresh seed, or endless deep-dark sectors.
- Story stays light: your ship's AI (working name WICK) guides you, and logs found in the Depths reveal what the Dimming was.

## Look and feel

- **Neon on dark**, in the style of Geometry Wars and Nova Drift: shapes drawn with Polygon2D and Line2D, 2D glow, GPU particles, 2D lights and occluders. It looks good with programmer art and fits the theme for free.
- **Unclaimed space** is desaturated, with a murky fog shader and dim stars. **Claimed space** shows your color, bright stars and visible nebulae.
- **Polish priorities:** ignition, ship feel, hits and kills, and research-complete moments.

## Engineering direction

**Recommendation: build single-player first, and structure the game state so co-op can be added later.** Co-op fits the design well (sieges are better with friends), but it shouldn't be the foundation.

The current architecture (WebSocket server, client prediction, interpolation) is solid work, but it taxes every feature. The networking layer is about 5,000 of the roughly 21,000 lines of game code, and each new system needs a message type, serialization, and handlers on both server and client; the uncommitted admin-command work had to touch all of those for one feature. For this game:

- Arcade feel (dash i-frames, dense bullets, platformer jumps) wants a local, frame-perfect simulation.
- There would be three modes to sync instead of one.
- Finding the fun means changing things fast.

Co-op can return later as host-authoritative Godot high-level multiplayer, or as couch co-op in space. A browser build is still possible for single-player (on itch.io, for example); web export uses the Compatibility renderer, so check the glow look there early if the browser matters.

**Proposed shape:**

- A `GameState` autoload holds territory, stockpile, buildings, research, Age and loadouts. It saves to `user://`, and offline progress is computed from timestamps.
- An economy/research clock autoload ticks production and research whichever mode you're in.
- One scene tree per mode (`space/`, `surface/`, `depths/`) plus the base UI.
- Content as data, via Godot Resources (`.tres`): RegionDef, EnemyDef, WeaponDef, BuildingDef, ResearchDef, tunable in the inspector.
- Godot's built-in physics (CharacterBody2D, Area2D) instead of hand-rolled collision, and `Geometry2D` for polygon work (`is_point_in_polygon`, `clip_polygons`, `triangulate_delaunay`).
- GUT for the pure logic: region generation, claim timing, the economy, research timers, the wave director.

**What carries over:**

| Port | Shelve (stays in git history) |
|---|---|
| Terrain generator, chunks, biomes, tile types → planet surfaces (moving from the deprecated `TileMap` to `TileMapLayer`) | Server/client split, serialization, prediction, interpolation |
| Health and combat components, combat calculator, melee/ranged resolution → on-foot combat | Slot inventory, durability, enchanting, trading |
| Enemy AI state machine → Gloom behaviors | Corpse runs (too punishing for an arcade loop) |
| Loot tables → drops and claim rewards | Melvor-style skills (maybe pilot mastery later) |
| Recipe definitions → building fabrication | |
| Minimap, damage numbers, hit effects, health bars | |
| GUT setup and testing habits | |

**Suggested approach:** tag the current state (for example `v0-networked-rpg`), start a clean `game/` tree in the same repo, and port pieces as each milestone needs them.

## Roadmap: find the fun first

Each milestone ends with a question you can only answer by playing.

0. **The Claim prototype.** One sector of about 15 regions; a ship with a blaster and dash; kindling, waves that scale with progress, ignition, the frontier rule, light heals, and a progress HUD. Nothing else. *Is holding a polygon under pressure fun on its own?* Tune claim time, wave pacing and ship feel until the answer is yes.
1. **Territory pays.** Lumen income, a simple research menu with about ten ship upgrades, save/load, region modifiers, a sector boss. *Is claim → upgrade → claim harder fun for 30 minutes?*
2. **Landfall.** Planets by encirclement, landing, surfaces from the terrain generator, on-foot combat, Hearth, extractors, Lab and Shipyard, per-building research queues. *Does the base make you want to go back to space?*
3. **Ages and the frontier.** Age advancement, pylon sieges, planet-unique buildings, sector 2, survivors. *Is there a pull toward the next big milestone?*
4. **The Depths.** Platformer runs, the lantern, relics, traversal unlocks. *Does it add variety, or feel bolted on?*
5. **Content, polish, sound and onboarding**, with co-op as a stretch goal.

## Open questions

1. **Multiplayer:** single-player first (recommended), or is networked co-op a hard requirement?
2. **Theme:** Lamplighter, as written here, or one of the alternates below?
3. **Does the dark push back?** The proposed default is that claimed space is permanent, with optional surge events that threaten a frontier region in exchange for bonus rewards. Base raids could be a setting.
4. **Offline progress:** none, capped (say 8 hours), or full idle?
5. **The Depths:** side-view platformer as described, or top-down rooms to save scope?
6. **Campaign or roguelite:** a persistent empire (recommended), or each galaxy as a run with meta-progression?

## Alternate themes

Same mechanics, different skin.

- **Claim Rush (space western).** The Charter opens a sector for homesteading: hold a stake long enough and the deed is yours. Claim jumpers and wildlife contest every stake, bases are homesteads, and the Depths are old mine shafts with minecart levels. Funnier and more charming, but it needs more art.
- **Reclamation.** An alien overgrowth called the Bloom has swallowed the sector, and you fly a terraforming ship purging it. The hive defends its turf, surfaces are overgrown, and the Depths are hive tunnels. The most action-heavy option, but bug swarms are well-worn territory.
