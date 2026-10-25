# Cosmocraft: Conquest and Landfall

The playable slice of the [game vision](../design/game_vision.md). You're conquering a galaxy one sector at a time. A run invades a dark sector next to your territory: claim regions, build up your ship from loot picks, and burn out the heart to conquer the sector for good. Then push on into the next sector with the same ship, or go home and bank. Planets wake once you hold the space around them: fly the side-scrolling assault on their defenses, land, kindle them on foot, and build extractors so their outposts mine for your homeworld. Between runs you walk around Hearthhold, your home.

**Run it:** double-click `run_claim.bat`, or open `game/main.tscn` in the editor and press F6.

## The loop

1. **Hearthhold** (home). Walk between buildings with WASD and press **E** to use one. Enter launches a run from anywhere.
   - **Launch Pad:** the star map. Pick a dark sector next to your territory (or a conquered one to replay), pick the darkness, and launch.
   - **Quarters:** your pilot's level and stats (Vitality, Agility, Aim, Lanterncraft).
   - **Shipyard:** permanent upgrades and blueprints, paid in sparks.
   - **Lab:** build it once (150 sparks), then research one project at a time. Projects cost ore, crystal or biomass and take a few real minutes. They keep ticking during runs and while the game is closed.
   - **Outpost Relay:** collect what your kindled planets have mined (6 an hour each, up to 12 hours' worth).
   - **Hearth:** the last run's report, lifetime records, Hearth levels to spend, and a hint about what to do next.
2. **Claim.** Fly into a region bordering your light and press **E** to kindle it. Stay inside while the bar fills; bigger regions take longer.
   - Kills drop sparks. Each one shaves time off the claim and banks as currency.
   - Snuffers crawl toward your spark; if one reaches it you lose 15%. One arrives at 90% (an elite from the third ring out).
   - **The dark gets worse the further you go.** The first ring around home only sends mites and darts, which are weaker there too. Spitters, broods and Snuffers join a ring further out, and carapaces and lancers further still. The kindle prompt names newcomers the first time you reach them. The deepest regions mix elites into their waves. Big regions are longer sieges rather than denser ones, and fewer Gloom can be alive at once near home.
   - Carapaces wear a front plate: shots to their face chip it until it cracks, then they're open from every side (or flank them, or use piercing and blast weapons).
   - Leave the region and progress pauses, then drains. Shields only recharge in your own light.
3. **Loot.** Every ignition offers three picks: a new part, a Mk upgrade, a Corvette refit, or a spark cache. Press 1-3, or R to reroll.
4. **Refit.** Press **F** inside your territory to rearrange the ship.
5. **Planets.** A sector has a couple of grey, dormant planets where regions meet. Their orbit ring lights a segment for each surrounding region you hold. Hold them all and the planet wakes; fly over it and press **E** to start the assault (below).
6. **The heart.** It's sealed until you hold five regions. Kindle it and the boss awakens inside a shell. Hold the region against the waves until the shell breaks (40%); then the waves stop and it's a duel with the heart and the mites it spawns. Its region won't ignite until it dies.
7. **Conquest.** Burning out a heart conquers the sector permanently and offers a loot pick. Then choose: push on into an adjacent dark sector with this ship (harder, further from home), or return home and bank your sparks with the +25% victory bonus. If you're destroyed with no spare sparks left, the run is over: you lose the bonus but keep every sector you conquered, and your sparks, resources and kindled planets still come home.

## The galaxy

Seven star systems of 4-6 sectors each, joined by lanes. A sector's **tier** is how many lanes it is from home: further out, the Gloom is tougher and the rewards better. Each system has its own flavor (Hollow Expanse is full of nebulae, Verdant Tangle full of nests and green worlds, Shard Fields full of asteroid belts...). Conquer every sector of a system and it falls, adding 10% to all rewards from then on. Conquer them all and the galaxy is lit.

## Darkness and the Hearth: how hard, and how far you've come

Difficulty works like Diablo III's Torment levels: a ladder you can climb for better rewards and step back down whenever a run is going badly.

| Darkness | Gloom | Rewards |
|---|---|---|
| Twilight | Weaker, hits softer, fewer | ×0.6 |
| **Dusk** (default) | The standard | ×1 |
| Nightfall | ×1.5 health, hits +15%, +15% numbers | ×1.6, rarer loot, parts up to Mk II |
| Midnight | ×2.2 health, tougher kinds a ring sooner | ×2.4 |
| Eclipse | ×3.2 health | ×3.5, parts up to Mk III |
| Void I, II, ... | keeps climbing | keeps climbing |

- **Unlocking:** relighting a sector on your darkest unlocked level unlocks the next one. Twilight and Dusk are open from the start.
- **Changing it:** pick it at the Launch Pad, or mid-run from the pause menu (Esc, then **[** / **]**) whenever you're not in a fight. Rewards follow whatever level you're on when you earn them: sparks, planet resources, loot rarity, and the Mk level new parts arrive at.
- **Hearth levels** are the endless part, like paragon levels. Every spark you bank also feeds the Hearth, and each level is a point for Searing Light (+1% damage) or Warded Hull (+2 hull, +1 shield), which never cap, or Quick Flame (claim speed) or Steady Hands (pilot toughness). Reset them for free at the Hearth.

## The assault: taking a planet's defenses

Before you can land, you fly in along the planet's horizon in a side-scrolling stage. Your ship keeps its fitted loadout.

- **Ground defenses** grow out of the terrain: spore turrets aim at you, thorn batteries throw fans of bolts, hives release skimmers. Skimmer waves, mites and darts come in from the right.
- **Every defense you destroy thins out the surface:** the share you burned is how many nests and sleeping packs won't be waiting for you (up to half).
- **The bastion** stands on a plateau at the end, shielded by its pods. Break the pods, then the bastion, and you land.
- Losing your ship spends a spare spark (bouncing you back to orbit to try again) or ends the run. Esc, then Q pulls back to orbit. A planet whose bastion fell skips the assault next time.

## Landfall: a planet's surface

You set down at your lander in the dark. Your lantern shows a little of the ground at a time. Glints give away what's out there: Gloom eyes, deposit twinkles, cache blinks, and the ember glow of the vein.

- **Explore.** Shoot resource deposits to break them; the shards fly to you. Walk over supply caches for repairs, sparks or an extra flare. Gloom nests send packs when you come near (and drop sparks when destroyed). Sleeping packs wake if you get close or shoot them.
- **Hazards.** Every world type has its own pools (embers, lava, acid, spores, cryo frost, crystal shards). They burn and slow you; rolling through them is safe.
- **The siege.** At the Ember Vein, press **E** to plant the pylon. Stay inside its ring while it charges. The Gloom pours out of the dark, Snuffers go for the pylon, and the pressure builds toward the end. Like a claim in space, the pylon's light doesn't heal you, but it does slow the Gloom, and so does a flare's glow.
- **Kindled.** When the pylon ignites, light rolls across the whole planet and burns every Gloom creature on it. The planet's haul flies to you, it becomes an outpost, and back in orbit you get a better-than-usual loot pick. Press **E** to lift off whenever you're ready.
- **Building.** Once a planet is kindled, walk to any deposit site and press **E** to build an extractor (10 of the planet's resource from your haul). Each one makes that planet's outpost mine 3 more an hour, forever. It's a choice: spend the haul on extractors for long-term income, or bring it home for research now.
- **Leaving early.** Walk back to the lander and press **E** to lift off; the planet stays awake for another try. Losing the pilot spends a spare spark (back at the lander) or ends the run.
- **Pilot levels.** Kills, broken deposits, caches, kindling and building earn your pilot experience. Each level heals you on the spot and gives a stat point to spend at the Quarters.

**The pilot:** 100 health plus a 40-point barrier that recharges at the lander, in flare light, and on a kindled planet. Health only recovers at the lander. You carry a sidearm (left click), two flares (right click; they rearm at the lander), and a dodge roll with invulnerability (Space/Shift).

## The ship grid

Your hull is a grid in the shape of the ship. The structure is borrowed from Stars Without Number's ship rules:

- **Space:** each part has a shape. A pulse laser is 1×1, a shield generator 2×2, a lance 1×3.
- **Power:** parts draw power, reactors supply it. The Skiff has 4.
- **Hardpoints** (crosshair cells): weapons must cover one.
- **Hull class:** big parts like the lance need a Corvette.
- **Adjacency:** a focusing lens (+damage) or overclock coil (+fire rate) boosts the weapons it touches.

Parts that don't fit go to the hold until you make room.

## Sectors

Regions are merged from Voronoi cells, so sizes range from roughly 30-second skirmishes to 3-minute sieges. Some regions carry a modifier (shown on the map):

| Modifier | Effect |
|---|---|
| Nest | Twice the Gloom, more sparks |
| Rich | Better loot picks and a bonus spark shower |
| Asteroids | Rocks block shots and ships |
| Nebula | You can barely see until it's lit |

Planet types decide what an outpost mines: Ashen and Magma worlds give ore, Verdant and Fungal give biomass, Frost and Crystal give crystal. Deeper planets (surrounded by regions far from home) have more nests, tougher packs and longer sieges, with the same roster rules as space: no carapaces or lancers until the third ring.

## Research

| Project | Effect | Cost |
|---|---|---|
| Ember Coils | Claims and sieges fill 10% faster | 20 ore |
| Field Rations | Pilot +30 health, +20 barrier | 20 biomass |
| Lantern Lens | Lantern lights 30% farther | 15 crystal |
| Reinforced Hulls | +25 hull | 30 ore |
| Flare Satchel | One more flare on planets | 10 ore + 15 biomass |
| Lens Grinding | +10% damage, ship and sidearm | 25 crystal |
| Twin Mounts | Start every run with a Twin Laser | 25 ore + 10 crystal |
| Survey Drones | +50% resources when you kindle a planet | 15 ore + 25 crystal |
| Heavy Kindler | Start every run with a Kindler Array | 30 crystal |
| Outpost Refinery | Outposts produce 50% more | 30 ore + 20 biomass |

## Controls

| Input | In space | On foot |
|---|---|---|
| WASD | Move | Move |
| Mouse | Aim | Aim |
| Left click | Fire (hold) | Sidearm (hold) |
| Right click | Torpedo (if fitted) | Flare |
| Space / Shift | Dash | Roll |
| E | Kindle a region / land on a planet | Plant the pylon / lift off / use a building at home |
| F | Refit (inside your territory) | |
| Tab / M | Sector map | |
| Esc | Pause (Q abandons the run; [ and ] change the darkness between fights) | Pause (Q while paused lifts off) |
| F1 / F2 / F3 | Debug overlay / claim speed / god mode | God mode on F3 |
| F4 / F5 / F11 | New sector / mute / fullscreen | Mute / fullscreen |

## What to judge while playing

- Is a planet worth the detour? Does the surface feel different enough from space, and is the siege tense in the right way?
- Does the dark feel atmospheric or just annoying? (Lantern radius and veil strength are in `surface/surface_tuning.gd` and `surface/lantern_veil.gd`.)
- **The milestone question:** does the homeworld make you want to go back out, to start research before a run, or to kindle another planet for the resource you're short on?
- Do loot picks still create interesting builds, and does a run take the right amount of time?

## Tuning

- **Sector, claim, spark, wave and ship numbers:** `space/space_tuning.gd`. The difficulty curve by depth lives there too: `base_threat`, `threat_per_depth`, `health_per_depth`, `alive_base`/`alive_per_depth`, `pace_seconds` and `deep_elite_chance`. Which Gloom appear at which depth is the `depth` column of `space/wave_director.gd`'s cards.
- **Pilot, siege, haul and planet difficulty:** `surface/surface_tuning.gd`; map layout in `surface/surface_map.gd`.
- **Parts, hulls and loot odds:** `fitting/component_library.gd`, `fitting/hull_def.gd`, `run/loot_picks.gd`.
- **Permanent upgrades and blueprint prices:** `run/meta_upgrades.gd`. **Research:** `run/research.gd`. **Outpost rate and cap:** `run/meta_progress.gd`.
- **Darkness levels:** `run/difficulty.gd`. **Hearth levels and their tracks:** `run/hearth_ranks.gd`.
- **Progress** is saved to `%APPDATA%\Godot\app_userdata\Cosmocraft\cosmocraft_save.json`. Delete it to start over.
