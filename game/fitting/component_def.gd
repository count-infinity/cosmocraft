class_name ComponentDef
extends RefCounted
## A ship part: its shape on the fitting grid, the power it draws, and what it
## does once fitted. The structure borrows from Stars Without Number's ship
## rules: power and space budgets, weapons that need hardpoints, and parts that
## need a big enough hull.

enum Category { WEAPON, DEFENSE, UTILITY, POWER }
enum Rarity { COMMON, UNCOMMON, RARE }

const RARITY_NAMES := {Rarity.COMMON: "Common", Rarity.UNCOMMON: "Uncommon", Rarity.RARE: "Rare"}
const MAX_MARK := 3

var id := ""
var display_name := ""
var description := ""
var category := Category.UTILITY
var rarity := Rarity.COMMON
## Cells at rotation 0, relative to the top-left. On the grid, y grows from the
## ship's nose toward its stern.
var shape: Array[Vector2i] = [Vector2i.ZERO]
## Power drawn. Reactors have negative power: they supply it.
var power := 0
var needs_hardpoint := false
var min_hull_class := 1
## Mk I bonuses such as {"max_shield": 30}; marks scale them up.
var stats: Dictionary = {}
## Bonuses given to weapons sharing an edge, such as {"damage": 0.3}.
var adjacency: Dictionary = {}
## Weapon parameters; empty for anything that isn't a weapon.
var weapon: Dictionary = {}
## Tint and two-letter label used on the fitting grid.
var color := Color.WHITE
var glyph := ""


func is_weapon() -> bool:
	return not weapon.is_empty()


func is_reactor() -> bool:
	return power < 0


## Cells for a rotation (0-3 quarter turns clockwise), shifted so the top-left
## cell sits at (0, 0).
func cells(rotation: int) -> Array[Vector2i]:
	var turned: Array[Vector2i] = []
	for cell in shape:
		var c := cell
		for _i in posmod(rotation, 4):
			c = Vector2i(-c.y, c.x)
		turned.append(c)
	var low := turned[0]
	for c in turned:
		low = Vector2i(mini(low.x, c.x), mini(low.y, c.y))
	var normalized: Array[Vector2i] = []
	for c in turned:
		normalized.append(c - low)
	return normalized


## How much a Mk II or III boosts this part's effects (1.0 at Mk I).
static func mark_scale(mark: int, per_mark: float) -> float:
	return 1.0 + per_mark * (clampi(mark, 1, MAX_MARK) - 1)
