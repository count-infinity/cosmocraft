class_name Difficulty
extends RefCounted
## How dark it gets: a ladder of levels you can step up or down between runs
## (at the Launch Pad) or between fights mid-run (from the pause menu).
## Darker levels make the Gloom tougher, hit harder, come in greater numbers
## and arrive closer to home, and pay more: sparks, planet resources and Hearth
## experience, rarer loot picks, and new parts that arrive already upgraded.
## Relighting a sector on your darkest unlocked level unlocks the next one;
## past Eclipse the Void levels keep climbing.
##
## Each level: health and damage multiply the Gloom's; threat multiplies wave
## pressure; roster shifts which Gloom appear by that many rings; reward
## multiplies sparks and resources; quality improves loot rarity; gear makes
## new parts arrive at a higher Mk.

const DEFAULT := 1
const MAX_LEVEL := 24
## How much harder (and better paying) each lane further from home makes a
## sector, on top of the darkness.
const TIER_HEALTH := 0.12
const TIER_DAMAGE := 0.05
const TIER_THREAT := 0.08
const TIER_REWARD := 0.1
const NAMED: Array[Dictionary] = [
	{"name": "Twilight", "health": 0.65, "damage": 0.7, "threat": 0.8, "roster": 0, "reward": 0.6, "quality": 0, "gear": 0},
	{"name": "Dusk", "health": 1.0, "damage": 1.0, "threat": 1.0, "roster": 0, "reward": 1.0, "quality": 0, "gear": 0},
	{"name": "Nightfall", "health": 1.5, "damage": 1.15, "threat": 1.15, "roster": 0, "reward": 1.6, "quality": 1, "gear": 1},
	{"name": "Midnight", "health": 2.2, "damage": 1.3, "threat": 1.3, "roster": 1, "reward": 2.4, "quality": 1, "gear": 1},
	{"name": "Eclipse", "health": 3.2, "damage": 1.45, "threat": 1.45, "roster": 1, "reward": 3.5, "quality": 2, "gear": 2},
]
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
	"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]


static func level(index: int) -> Dictionary:
	index = clampi(index, 0, MAX_LEVEL)
	if index < NAMED.size():
		return NAMED[index]
	var step := index - NAMED.size() + 1
	var last: Dictionary = NAMED[-1]
	return {
		"name": "Void %s" % ROMAN[mini(step, ROMAN.size()) - 1],
		"health": float(last["health"]) * pow(1.4, step),
		"damage": float(last["damage"]) + 0.12 * step,
		"threat": minf(float(last["threat"]) + 0.08 * step, 2.2),
		"roster": 2,
		"reward": float(last["reward"]) * pow(1.35, step),
		"quality": 2 + mini(step, 2),
		"gear": 3,
	}


## A darkness level with a sector's tier (lanes from home) folded in, plus any
## reward bonus from conquered systems.
static func for_sector(darkness: int, tier: int, reward_bonus := 0.0) -> Dictionary:
	var info := level(darkness).duplicate()
	var steps := maxi(tier - 1, 0)
	info["health"] = float(info["health"]) * (1.0 + TIER_HEALTH * steps)
	info["damage"] = float(info["damage"]) * (1.0 + TIER_DAMAGE * steps)
	info["threat"] = float(info["threat"]) * (1.0 + TIER_THREAT * steps)
	info["reward"] = float(info["reward"]) * (1.0 + TIER_REWARD * steps) * (1.0 + reward_bonus)
	info["roster"] = int(info["roster"]) + steps / 3
	return info


## "Gloom health ×1.24 · rewards ×1.2" for a sector's tier.
static func tier_text(tier: int) -> String:
	var steps := maxi(tier - 1, 0)
	if steps == 0:
		return "The easiest the dark gets"
	return "Gloom health ×%s  ·  rewards ×%s" % [_number(1.0 + TIER_HEALTH * steps), _number(1.0 + TIER_REWARD * steps)]


static func name_of(index: int) -> String:
	return String(level(index)["name"])


## "Gloom health ×1.5 · hits +15% · numbers +15%" (changes from Dusk).
static func summary(index: int) -> String:
	var info := level(index)
	var parts: Array[String] = []
	if not is_equal_approx(float(info["health"]), 1.0):
		parts.append("Gloom health ×%s" % _number(float(info["health"])))
	if not is_equal_approx(float(info["damage"]), 1.0):
		parts.append("hits %s" % _percent(float(info["damage"])))
	if not is_equal_approx(float(info["threat"]), 1.0):
		parts.append("numbers %s" % _percent(float(info["threat"])))
	if int(info["roster"]) > 0:
		parts.append("tougher kinds %d ring%s sooner" % [int(info["roster"]), "" if int(info["roster"]) == 1 else "s"])
	if parts.is_empty():
		return "The standard darkness every sector starts at"
	return "  ·  ".join(parts)


## "rewards ×1.6, rarer loot, parts up to Mk II"
static func reward_text(index: int) -> String:
	var info := level(index)
	var text := "rewards ×%s" % _number(float(info["reward"]))
	if int(info["quality"]) > 0:
		text += ", rarer loot"
	var gear := int(info["gear"])
	if gear > 0:
		text += ", parts up to Mk %s" % ("I".repeat(mini(gear + 1, ComponentDef.MAX_MARK)))
	return text


static func _number(value: float) -> String:
	var text := "%.2f" % value
	text = text.rstrip("0").rstrip(".")
	return text


static func _percent(value: float) -> String:
	var change := roundi((value - 1.0) * 100.0)
	return ("+%d%%" % change) if change >= 0 else ("%d%%" % change)
