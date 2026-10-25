# Cosmocraft: Game Vision

*October 2026. Replaces the direction in [plan.md](../plan.md). Decided so far: single-player first, the Lamplighter theme, and a roguelite structure for the space game (see "Structure and goal"). Everything else is still open for debate.*

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

**Decided: a roguelite run structure with a persistent layer on top**, like a space Vampire Survivors.

- **A run is one sector.** You start in the basic ship, claim regions, and build the ship up from loot picks that last only for that run. The heart (the biggest region, deep in the dark) is sealed until you hold a few regions; burning it out wins the run.
- **Losing ends the run.** If you're destroyed with no spare sparks left, the run is over, but the sparks you collected bank either way.
- **Sparks buy permanent upgrades** between runs: stats, revives, rerolls, a bigger starting hull, and blueprints that add parts to the loot pool.
- **The persistent layer is the homeworld.** Hearthhold replaced the hangar menu in Milestone 2: sparks upgrades live in its Shipyard, research in its Lab, and kindled planets feed it as outposts (like the House in Hades, or the camp in Cult of the Lamb). Conquered sectors feeding the empire comes later.
- Each sector has a Gloom Heart. Later, clearing a set of sectors opens the Core, the biggest polygon in the game.
- Story stays light: your ship's AI (working name WICK) guides you, and logs found in the Depths reveal what the Dimming was.

## Ship fitting

**Decided: a fitting grid** with the structure of Stars Without Number's ship rules, using our own names.

- **Space:** the hull is a grid in the shape of the ship, and every part has a shape on it.
- **Power:** parts draw power, reactors supply it.
- **Hardpoints:** weapons must cover a hardpoint cell.
- **Hull class:** big parts need a bigger hull (Skiff, then Corvette, then more later).
- **Weapon qualities:** pierce, blasts, homing, and ammo weapons that only rearm inside your light.
- **Adjacency:** lenses and coils boost the weapons they touch.
- **Marks:** parts upgrade from Mk I to Mk III through loot picks.

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
1. **Runs, loot and the fitting grid** (built). Sector variety (merged regions, modifiers, the heart boss), the ship grid with 18 parts, pick-1-of-3 loot, permanent upgrades in a hangar, and saving. *Do builds emerge, and is one more run tempting?*
2. **Landfall** (built, simplified; see "Landfall as built" below). Planets by encirclement, landing, generated surfaces in the dark, on-foot combat, the pylon siege, outposts, and a walkable homeworld with a Hearth, Shipyard, Lab (real-time research) and Outpost Relay. *Does the base make you want to go back to space?*
3. **Ages and the frontier.** Age advancement, pylon sieges, planet-unique buildings, sector 2, survivors. *Is there a pull toward the next big milestone?*
4. **The Depths.** Platformer runs, the lantern, relics, traversal unlocks. *Does it add variety, or feel bolted on?*
5. **Content, polish, sound and onboarding**, with co-op as a stretch goal.

## Conquest and the three-phase planet (decided)

The user wanted beating a sector to mean something, and planets to feel like their own phase (ActRaiser's two modes, Thunder Force's stage variety), with No Man's Sky-style building and RPG-style pilot stats.

- **The galaxy is the campaign.** Seven systems of 4-6 sectors joined by lanes. A run invades a dark sector next to your territory; burning out its heart conquers it permanently. Then you push on into an adjacent sector with the same ship, or go home to bank with the victory bonus (dying keeps the conquests but loses the bonus). A sector's tier (lanes from home) scales its difficulty and rewards; systems have themes; a fallen system adds 10% to all rewards.
- **Planets in three phases.** Encircle the planet in space (as before), fly a side-scrolling assault over its horizon against Gloom ground defenses and the bastion (your space loadout is your weaponry), then land and kindle the vein on foot. Defenses destroyed in the assault thin out the surface.
- **Number go up on planets.** The pilot has their own level and stats (Vitality, Agility, Aim, Lanterncraft) from experience earned on foot, and kindled planets take extractors that raise their outpost's output for good.
- **Not yet:** revisiting outposts to keep building, a true side-view platformer for the Depths, planet-unique buildings.

## Difficulty and the endgame (decided)

The model is Diablo III and Path of Exile: a somewhat easy playthrough, then an optional endgame you climb for better rewards and can drop back down from at any time. The user specifically wants to raise or lower difficulty on the fly.

- **Within a run, distance is difficulty.** The first ring around home sends only mites and darts, weaker there too. Spitters, broods and Snuffers come a ring out, carapaces and lancers beyond that, and the deepest regions mix elites in. Big regions are longer sieges, not denser ones, and fewer Gloom can be alive at once near home.
- **The heart is a two-phase boss.** It sleeps in its shell while you hold its region against the waves. When the shell breaks, the waves stop and it fights back.
- **Darkness levels** (the Torment ladder): Twilight, Dusk (default), Nightfall, Midnight, Eclipse, then Void I, II and on. Darker means tougher Gloom that hit harder, arrive in greater numbers and bring tougher kinds closer to home. It also means bigger rewards: sparks, resources, rarer loot, and new parts that arrive at Mk II or III (gear levels). Relighting a sector on your darkest level unlocks the next. You pick the level at the Launch Pad or change it mid-run between fights.
- **Hearth levels** (paragon): every banked spark feeds the Hearth; each level is a point in small permanent bonuses, two of them uncapped, freely respecced.

## Landfall as built (Milestone 2)

Landfall had to fit the roguelite structure, where a run is one sector and nothing in it survives except what you bank. These are the calls made, all open to revisiting after play:

- **Planets wake by encirclement.** One or two per sector sit where three or more regions meet. Their orbit ring lights a segment per surrounding region you hold; hold them all and the planet wakes and can be landed on.
- **A surface is a self-contained mission, not a base site.** You land in the dark with a lantern, break resource deposits, raid caches, clear nests, and find the planet's Ember Vein. Planting a pylon on it starts the ground siege, which reuses Claim and WaveDirector. Winning kindles the whole planet in one wave of light. This is the vision's "Lamp Pylon" siege, used once per planet rather than to grow a territory.
- **Kindled planets become outposts.** These are the vision's extractors with the placement step cut: every outpost mines its planet's resource for the homeworld on the real clock, and they're kept even if the run is lost. Planet type decides the resource: ore (Ashen, Magma), biomass (Verdant, Fungal) or crystal (Frost, Crystal).
- **One base: Hearthhold, the homeworld.** It replaces the hangar menu. It's walkable (the same pilot and controls as planets), a pool of light around the Hearth with fixed buildings rather than grid placement, for now. The Shipyard holds the sparks upgrades and blueprints, the Lab (built once with sparks) researches with planet resources, and the Relay collects from outposts.
- **Research runs on real timers** of 3–8 minutes per project, one at a time, ticking during runs and while the game is closed. It's the "start something, then go out" hook. Finished projects give lasting bonuses (claim speed, hull, damage, pilot health, lantern, flares, planet haul, outpost output) or parts every run starts with.
- **Light hurts the Gloom on foot.** The charging pylon's light and flare light slow it. Like a claim in space, the pylon doesn't heal you; only the lander, flares and a kindled planet do.
- **Deferred:** grid placement of buildings, per-planet bases, Refinery/Armory/Observatory, Ages, survivors, and the Depths entrances on planets.

## Open questions

1. ~~Multiplayer~~: decided, single-player first.
2. ~~Theme~~: decided, Lamplighter.
3. **Does the dark push back?** The proposed default is that claimed space is permanent, with optional surge events that threaten a frontier region in exchange for bonus rewards. Base raids could be a setting.
4. ~~Offline progress~~: decided for now, capped. Outposts pile up at most 12 hours of mining between Relay visits; research timers run on the real clock.
5. **The Depths:** side-view platformer as described, or top-down rooms to save scope?
6. ~~Campaign or roguelite~~: decided, roguelite runs with a persistent layer.
7. **Passive income:** kindled planets now pay out between runs as outposts. Claimed regions still don't; should they?

## Alternate themes

Same mechanics, different skin.

- **Claim Rush (space western).** The Charter opens a sector for homesteading: hold a stake long enough and the deed is yours. Claim jumpers and wildlife contest every stake, bases are homesteads, and the Depths are old mine shafts with minecart levels. Funnier and more charming, but it needs more art.
- **Reclamation.** An alien overgrowth called the Bloom has swallowed the sector, and you fly a terraforming ship purging it. The hive defends its turf, surfaces are overgrown, and the Depths are hive tunnels. The most action-heavy option, but bug swarms are well-worn territory.
