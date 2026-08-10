class_name ElementSystem
extends RefCounted

const FIRE := "fire"
const WATER := "water"
const GRASS := "grass"
const NEUTRAL := "neutral"
const PRIMARY_ELEMENTS: Array[String] = [FIRE, WATER, GRASS, NEUTRAL]

const ELEMENT_COLORS := {
	FIRE: Color("ff6538"),
	WATER: Color("39bff5"),
	GRASS: Color("63c76a"),
	NEUTRAL: Color("f3df9b")
}

static func normalize_primary(element_or_family: String) -> String:
	var value := element_or_family.to_lower()
	match value:
		"fire", "magma", "smoke", "explosion": return FIRE
		"water", "ice", "lightning", "frost": return WATER
		"grass", "poison", "wood", "spore", "thorn", "restoration": return GRASS
		_: return NEUTRAL

static func beats(attacker: String, defender: String) -> bool:
	var attack := normalize_primary(attacker)
	var defense := normalize_primary(defender)
	return (attack == FIRE and defense == GRASS) \
		or (attack == GRASS and defense == WATER) \
		or (attack == WATER and defense == FIRE)

static func multiplier(attacker: String, defender: String, advantage: float = 1.35, disadvantage: float = 0.78) -> float:
	var attack := normalize_primary(attacker)
	var defense := normalize_primary(defender)
	if attack == NEUTRAL or defense == NEUTRAL or attack == defense:
		return 1.0
	if beats(attack, defense):
		return advantage
	if beats(defense, attack):
		return disadvantage
	return 1.0

static func damage_after_resistance(base_damage: float, attacker: String, defender: String, resistance: float) -> float:
	var relationship := multiplier(attacker, defender)
	var resisted := relationship * (1.0 - clampf(resistance, 0.0, 0.65))
	# A resistance build can soften a bad matchup, but never erase the weakness.
	if beats(attacker, defender):
		resisted = maxf(resisted, 1.08)
	return base_damage * resisted

static func color(element_or_family: String) -> Color:
	return ELEMENT_COLORS.get(normalize_primary(element_or_family), ELEMENT_COLORS[NEUTRAL])

