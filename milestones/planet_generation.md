# Planet Generation - Requirements & Design

## Design Decisions (Confirmed)

| Question | Decision |
|----------|----------|
| Planet size | Large, hours to cross, variable sizes (moons to gas giants) |
| Tile size | 16x16 pixels |
| View style | Top-down overworld, side-scroll dungeons later |
| Biomes | Multiple biomes per planet |
| Change history | No undo needed |
| V1 features | Trees, rocks, bushes, water, elevation, villages |
| Liquid flow | Yes |
| Light propagation | Yes |
| Loading style | Background streaming, initial load on planet arrival acceptable |

---

## Architecture Overview

### Core Concept
```
Rendered World = Procedural(planet_seed, chunk_coords) + Delta(stored_changes)
```

Both server and client can generate identical terrain from the same seed. Only player modifications are stored and synced.

---

## Planet Specifications

### Size Categories
| Type | Dimensions (tiles) | Walk Time | Example |
|------|-------------------|-----------|---------|
| Moon | 2,000 x 2,000 | ~15 min | Small asteroid base |
| Small | 8,000 x 8,000 | ~1 hour | Rocky planetoid |
| Medium | 16,000 x 16,000 | ~2-3 hours | Earth-like world |
| Large | 32,000 x 32,000 | ~6+ hours | Gas giant moon |

*Walk time assumes 200 pixels/sec = 12.5 tiles/sec*

### Coordinate System
- Top-down 2D (x, y)
- Origin (0,0) at northwest corner
- Y increases downward (standard screen coords)
- Tiles addressed by integer coordinates

---

## Chunk System

### Chunk Specifications
- **Size**: 32x32 tiles (1,024 tiles per chunk)
- **Pixel size**: 512x512 pixels per chunk
- **Memory**: ~4KB raw, ~1KB compressed per chunk

### Chunk States
```
UNLOADED → GENERATING → LOADED → MODIFIED
				↓
		   (cached to disk)
```

### Loading Strategy
1. **Initial planet load**: Generate spawn area (5x5 chunks = 160x160 tiles)
2. **Streaming**: Pre-generate chunks 3 chunks ahead of player movement
3. **Unloading**: Unload chunks >10 chunks from any player
4. **Caching**: Keep modified chunks in memory, persist to disk periodically

### View Distance
- **Visible**: ~3x3 chunks around player (based on 1920x1080 viewport)
- **Active**: 5x5 chunks (for entity updates, liquid flow)
- **Loaded**: 9x9 chunks (buffer for smooth movement)

---

## Tile System

### Tile Data Structure
```gdscript
# Packed into 32 bits for efficiency
# Bits 0-11:  Tile type (4096 types max)
# Bits 12-15: Visual variant (16 variants)
# Bits 16-23: Light level (0-255)
# Bits 24-27: Liquid level (0-15)
# Bits 28-31: Flags (solid, mineable, etc.)
```

### Core Tile Types (V1)
| ID | Type | Solid | Notes |
|----|------|-------|-------|
| 0 | Air/Empty | No | Default empty |
| 1 | Grass | No | Walkable surface |
| 2 | Dirt | Yes | Mineable |
| 3 | Stone | Yes | Mineable, harder |
| 4 | Water | No | Liquid, flows |
| 5 | Sand | No | Near water |
| 6 | Tree Trunk | Yes | Obstacle |
| 7 | Tree Leaves | No | Decorative |
| 8 | Bush | No | Decorative |
| 9 | Rock | Yes | Small obstacle |
| 10 | Tall Grass | No | Decorative |
| 11 | Flower | No | Decorative |
| 12 | Path | No | Village paths |
| 13 | Wall | Yes | Village buildings |
| 14 | Floor | No | Indoor floor |

### Tile Properties
```gdscript
class TileProperties:
	var is_solid: bool        # Blocks movement
	var is_mineable: bool     # Can be harvested
	var is_liquid: bool       # Flows to adjacent tiles
	var light_emission: int   # 0-15 light output
	var light_blocking: int   # 0-15 light absorption
	var walk_speed_mult: float # Movement speed modifier
```

---

## Biome System

### Biome Determination
Uses layered noise functions:
1. **Temperature noise**: Hot ↔ Cold
2. **Moisture noise**: Wet ↔ Dry
3. **Elevation noise**: Low ↔ High

### Biome Map
```
				 WET                    DRY
		 ┌──────────────────────────────────┐
	HOT  │  Swamp  │  Jungle  │  Desert    │
		 ├─────────┼──────────┼────────────┤
	MILD │  Forest │  Plains  │  Savanna   │
		 ├─────────┼──────────┼────────────┤
	COLD │  Taiga  │  Tundra  │  Ice       │
		 └──────────────────────────────────┘
```

### V1 Biomes (4 to start)
1. **Forest** - Trees, bushes, grass, flowers
2. **Desert** - Sand, cacti, rocks, sparse vegetation
3. **Ice/Tundra** - Snow, ice, frozen lakes, sparse trees
4. **Ocean** - Water body with beaches, islands

### Biome Transitions
- 3-5 tile gradual blend between biomes
- Mixed tile types at boundaries
- Noise-based irregular edges (not straight lines)

---

## Terrain Generation

### Layer Stack
```
1. Base terrain (elevation noise)
   ↓
2. Biome selection (temperature + moisture noise)
   ↓
3. Feature placement (trees, rocks, bushes)
   ↓
4. Structure placement (villages)
   ↓
5. Detail pass (flowers, grass variants)
```

### Noise Functions
- **Simplex noise** for smooth terrain
- Multiple octaves for detail
- Planet seed ensures deterministic generation

### Elevation System (Top-Down)
Since we're top-down, "elevation" affects:
- Visual layering (hills appear "above")
- Movement speed (uphill slower)
- Water flow direction
- Cliff edges (impassable steep changes)

Represented as height values 0-255:
- 0-50: Water level (lakes, rivers)
- 51-100: Lowlands
- 101-150: Plains
- 151-200: Hills
- 201-255: Mountains (impassable cliffs)

---

## Water/Liquid System

### Flow Mechanics
- Liquids flow from higher to lower elevation
- Spread to adjacent tiles over time
- Liquid level 0-15 per tile
- Full tile = 15, can merge/split

### Update Rules
```
Every tick:
1. For each liquid tile:
   - Find lowest adjacent tile
   - If lower and not full: transfer liquid
   - If same level: spread evenly
2. Process in elevation order (high to low)
```

### Performance Optimization
- Only process "active" liquid (recently changed)
- Dirty flag system
- Limit updates per tick (e.g., 100 liquid tiles/tick)
- Server authoritative, client interpolates

---

## Light Propagation

### Light Sources
- Sun (ambient, based on time of day)
- Torches (placed by players)
- Lava, glowing ore, etc.

### Propagation Algorithm
Flood-fill with attenuation:
```
1. Set light sources to max brightness
2. For each lit tile, spread to neighbors:
   - New light = source light - 1 - tile_blocking
   - Update if brighter than current
3. Iterate until stable
```

### Performance Optimization
- Only recalculate when tiles change
- Chunk-level light caching
- 16 light levels (4 bits)
- Dirty rectangle tracking

### Day/Night Cycle
- Ambient light level changes over time
- Affects all outdoor tiles
- Indoor areas (under roof) use only placed lights

---

## Structure Generation

### Villages
```
Village Generation:
1. Pick valid location (flat area, not water)
2. Generate village center (well, plaza)
3. Place buildings around center
4. Connect with paths
5. Spawn NPCs
```

### Building Templates
- Small house (5x5 tiles)
- Large house (7x7 tiles)
- Shop (6x6 tiles)
- Farm plot (8x8 tiles)

### Abandoned Structures
Same as villages but:
- Partially destroyed walls
- No NPCs
- Loot containers
- Environmental storytelling

---

## Delta Storage

### Format (Chunk-Level Deltas)
```json
{
  "planet_id": "seed_12345",
  "modified_chunks": {
    "15,23": {
      "tiles": {
        "5,12": {"type": 0, "variant": 0},
        "5,13": {"type": 14, "variant": 2}
      },
      "entities": [...],
      "last_modified": 1703456789
    }
  }
}
```

### Storage Strategy
- In-memory: All loaded chunk deltas
- Periodic flush: Every 30 seconds or on chunk unload
- File format: One file per planet, JSON or binary

### Compression
- Run-length encoding for large modified areas
- Only store diff from procedural base
- Gzip for network transfer

---

## Network Protocol

### Chunk Messages
```
CLIENT → SERVER:
- request_chunks(chunk_coords[])
- tile_modified(chunk, x, y, new_type)

SERVER → CLIENT:
- chunk_data(chunk_coord, tiles[], deltas[])
- chunk_update(chunk_coord, changes[])
- chunk_unload(chunk_coord)
```

### Sync Strategy
1. Player moves → client requests nearby chunks
2. Server generates/loads chunks
3. Server applies deltas
4. Server sends chunk data to client
5. Client renders
6. Player modifies tile → client sends change
7. Server validates & broadcasts to nearby players

---

## Implementation Phases

### Phase 1: Core Chunk System
- [ ] Chunk data structure
- [ ] Chunk manager (load/unload)
- [ ] Basic tile types
- [ ] Simple noise terrain (grass/dirt/stone)
- [ ] Chunk rendering on client
- [ ] Basic chunk streaming

### Phase 2: Biomes & Features
- [ ] Temperature/moisture noise layers
- [ ] 4 biome types
- [ ] Biome-specific terrain
- [ ] Tree/rock/bush placement
- [ ] Biome transitions

### Phase 3: Water & Elevation
- [ ] Elevation layer
- [ ] Water body generation (lakes, rivers)
- [ ] Liquid flow simulation
- [ ] Movement speed on slopes

### Phase 4: Light System
- [ ] Tile light levels
- [ ] Light propagation algorithm
- [ ] Day/night ambient
- [ ] Placed light sources

### Phase 5: Structures
- [ ] Village generation
- [ ] Building templates
- [ ] Path generation
- [ ] Abandoned structures

### Phase 6: Persistence & Polish
- [ ] Delta save/load
- [ ] Chunk caching
- [ ] Network optimization
- [ ] Edge cases & bugs

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Chunk generation | < 10ms |
| Chunk render | < 5ms |
| Liquid tick (100 tiles) | < 2ms |
| Light recalc (1 chunk) | < 5ms |
| Memory per chunk | < 4KB |
| Network per chunk | < 2KB compressed |

---

## Open Questions (For Later)

1. Cave/dungeon entrance placement on overworld?
2. How do elevation "cliffs" render in top-down?
3. Weather effects on terrain?
4. Seasonal changes?
5. Ore vein generation patterns?
