class_name SurvivalArsenal

# Survival weapons: what they do, what they cost, how levels change them, and the
# player's saved progress (coins + owned weapon levels live in Global.stats, so the
# armory carries over between runs).

const MAX_LEVEL := 5

# id -> definition. "cost" buys level 1; each next level costs up_cost * current level.
const WEAPONS := {
	"bolt": {"name": "Arcane Bolt", "icon": "✦", "cost": 0, "up_cost": 35,
		"cd": 0.30, "dmg": 1.0, "speed": 270.0, "color": Color(0.45, 0.95, 1.0),
		"desc": "Quick magic bolts. Reliable at any range."},
	"scatter": {"name": "Scatter Wand", "icon": "✸", "cost": 60, "up_cost": 40,
		"cd": 0.70, "dmg": 0.75, "speed": 240.0, "pellets": 5, "life": 0.5, "color": Color(1.0, 0.85, 0.45),
		"desc": "A burst of pellets. Shreds anything up close."},
	"flame": {"name": "Flame Staff", "icon": "🔥", "cost": 90, "up_cost": 45,
		"cd": 0.85, "dmg": 2.0, "speed": 170.0, "radius": 24.0, "color": Color(1.0, 0.5, 0.15),
		"desc": "Fireballs that explode and hit whole groups."},
	"spear": {"name": "Star Spear", "icon": "➶", "cost": 110, "up_cost": 50,
		"cd": 0.55, "dmg": 1.7, "speed": 400.0, "pierce": 3, "color": Color(1.0, 0.95, 0.6),
		"desc": "Very fast, flies through several enemies."},
	"moon": {"name": "Moon Boomerang", "icon": "☾", "cost": 120, "up_cost": 50,
		"cd": 0.75, "dmg": 1.6, "speed": 250.0, "color": Color(0.8, 0.85, 1.0),
		"desc": "Flies out and comes back, hitting everything twice."},
	"storm": {"name": "Storm Rod", "icon": "⚡", "cost": 150, "up_cost": 55,
		"cd": 0.60, "dmg": 1.3, "range": 170.0, "chains": 2, "color": Color(0.7, 0.85, 1.0),
		"desc": "Lightning that jumps from enemy to enemy. Never misses."},
}
const ORDER := ["bolt", "scatter", "flame", "spear", "moon", "storm"]


# Weapon numbers at a level (1..5).
static func at_level(id: String, lvl: int) -> Dictionary:
	var d: Dictionary = WEAPONS[id].duplicate()
	var k := maxi(lvl, 1) - 1
	d["dmg"] = float(d.dmg) * (1.0 + 0.25 * k)
	d["cd"] = float(d.cd) * (1.0 - 0.07 * k)
	match id:
		"scatter": d["pellets"] = int(d.pellets) + (k + 1) / 2
		"flame": d["radius"] = float(d.radius) + 4.0 * k
		"spear": d["pierce"] = int(d.pierce) + k
		"storm": d["chains"] = int(d.chains) + k
		"moon": d["size"] = 1.0 + 0.15 * k
	return d


# ------------------------------------------------------------------ saved progress
static func coins() -> int:
	return int(Global.stats.get("survival_coins", 0))


static func add_coins(n: int) -> void:
	Global.stats["survival_coins"] = maxi(0, coins() + n)


static func levels() -> Dictionary:
	var l = Global.stats.get("survival_arsenal", {})
	if typeof(l) != TYPE_DICTIONARY:
		l = {}
	if int(l.get("bolt", 0)) < 1:
		l["bolt"] = 1
	Global.stats["survival_arsenal"] = l
	return l


static func level(id: String) -> int:
	return int(levels().get(id, 0))


static func owned() -> Array:
	var out := []
	for id in ORDER:
		if level(id) > 0:
			out.append(id)
	return out


# Price of the next step for a weapon (buy or upgrade); -1 = maxed.
static func next_price(id: String) -> int:
	var lvl := level(id)
	if lvl >= MAX_LEVEL:
		return -1
	if lvl == 0:
		return int(WEAPONS[id].cost)
	return int(WEAPONS[id].up_cost) * lvl


static func buy_next(id: String) -> bool:
	var price := next_price(id)
	if price < 0 or coins() < price:
		return false
	add_coins(-price)
	var l := levels()
	l[id] = level(id) + 1
	Global.save_game()
	return true
