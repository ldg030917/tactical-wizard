class_name UIIconFactory
extends RefCounted

static var _cache: Dictionary = {}

const ELEMENT_COLORS := {
	"fire":"f04418", "water":"1688f8", "grass":"22b653", "neutral":"f2cc62"
}

static func item_icon(item_id: String, size: int = 96) -> Texture2D:
	var item: ItemData = ItemDB.resource(item_id)
	if item == null:
		return icon("empty", "neutral", size)
	if item.base_spell != null:
		return spell_icon(item.base_spell, size)
	if item.spell_modifier != null:
		return icon(_initials(item.display_name), "neutral", size, "rune", item.spell_modifier.modifier_id.hash())
	var key: String = {
		"spellbook":"BK", "dagger":"DG", "focus":"WD", "medical":"HP", "mana_consumable":"MP",
		"armor_head":"HM", "armor_chest":"AR", "accessory":"RG", "backpack":"BP", "material":"◇",
		"ticket":"TK", "quest":"!", "valuable":"◆"
	}.get(item.category, _initials(item.display_name))
	return icon(key, item.primary_element, size, item.category, item.item_id.hash())

static func spell_icon(spell: BaseSpellData, size: int = 96) -> Texture2D:
	var motif: String = {
		"projectile":"bolt", "cone":"spray", "damage_zone":"field", "slow_zone":"mist",
		"root_field":"roots", "puddle":"pool", "wall":"wall", "barrier":"shield", "mine":"mine",
		"chain":"chain", "beam":"beam", "teleport":"blink", "mana_restore":"spring",
		"cleanse":"cleanse", "shield":"shield", "knockback":"wave", "explosion":"explosion"
	}.get(spell.behavior_type, spell.spell_family)
	return icon(_initials(spell.display_name), spell.primary_element, size, motif, spell.spell_id.hash())

static func navigation_icon(key: String, size: int = 72) -> Texture2D:
	var glyph: String = {
		"inventory":"BP", "character":"CH", "loadout":"EQ", "spellbook":"BK", "workshop":"RN",
		"storage":"ST", "merchant":"CR", "map":"MP", "craft":"AN", "upgrades":"UP", "skills":"SK",
		"quests":"!", "settings":"⚙", "deploy":"GO", "exit":"X", "start":"▶"
	}.get(key, _initials(key))
	return icon(glyph, "neutral", size, key, key.hash())

static func clear_cache() -> void:
	_cache.clear()

static func icon(glyph: String, element: String = "neutral", size: int = 96, motif: String = "arcane", seed: int = 0) -> Texture2D:
	var cache_key: String = "%s:%s:%s:%d:%d" % [glyph, element, motif, size, seed]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var color: String = str(ELEMENT_COLORS.get(ElementSystem.normalize_primary(element), ELEMENT_COLORS.neutral))
	var accent: String = {"fire":"ff9a28", "water":"63e8ff", "grass":"9cff73", "neutral":"fff4be"}.get(ElementSystem.normalize_primary(element), "ffffff")
	var hash_value: int = absi(seed)
	var x1: int = 18 + posmod(hash_value, 18)
	var x2: int = 60 + posmod(hash_value / 7, 18)
	var y1: int = 18 + posmod(hash_value / 13, 16)
	var y2: int = 63 + posmod(hash_value / 19, 15)
	var safe_glyph: String = glyph.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
	var motif_art: String = _motif_svg(motif, accent)
	var svg: String = """<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 96 96'>
<defs><radialGradient id='g'><stop stop-color='#%s' stop-opacity='.48'/><stop offset='1' stop-color='#080a12' stop-opacity='.96'/></radialGradient></defs>
<rect x='3' y='3' width='90' height='90' rx='15' fill='url(#g)' stroke='#%s' stroke-width='4'/>
<circle cx='48' cy='48' r='34' fill='none' stroke='#%s' stroke-opacity='.18' stroke-width='2'/>
<path d='M%d %d L48 17 L%d %d M17 48 L79 48 M28 76 L68 20' fill='none' stroke='#%s' stroke-opacity='.14' stroke-width='2'/>
%s
<rect x='26' y='72' width='44' height='17' rx='7' fill='#060910' fill-opacity='.88' stroke='#%s' stroke-opacity='.65'/>
<text x='48' y='85' text-anchor='middle' font-family='Arial,sans-serif' font-size='13' font-weight='900' fill='#fff'>%s</text>
<circle cx='80' cy='16' r='10' fill='#%s'/><text x='80' y='20' text-anchor='middle' font-family='Arial' font-size='10' font-weight='bold' fill='#081018'>%s</text>
</svg>""" % [size, size, color, color, accent, x1, y1, x2, y2, accent, motif_art, accent, safe_glyph, accent, element.left(1).to_upper()]
	var image := Image.new()
	var error: Error = image.load_svg_from_string(svg, float(size) / 96.0)
	if error != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_cache[cache_key] = texture
	return texture

static func _motif_svg(motif: String, color: String) -> String:
	var stroke := "stroke='#%s' stroke-width='6' stroke-linecap='round' stroke-linejoin='round' fill='none'" % color
	var fill := "fill='#%s'" % color
	match motif:
		"start", "deploy": return "<polygon points='34,23 72,48 34,70' %s/><circle cx='48' cy='48' r='31' %s stroke-width='3'/>" % [fill, stroke]
		"settings": return "<circle cx='48' cy='46' r='13' %s/><path d='M48 19V27 M48 65V73 M21 46H29 M67 46H75 M29 27L35 33 M61 59L67 65 M67 27L61 33 M35 59L29 65' %s/>" % [stroke, stroke]
		"exit": return "<path d='M29 27L67 66 M67 27L29 66' %s/>" % stroke
		"inventory", "storage": return "<path d='M29 37H67V69H29Z M36 37V29Q48 20 60 29V37 M29 48H67' %s/>" % stroke
		"dagger", "melee": return "<path d='M27 68L58 37 M52 24L70 42L59 48L46 35Z M22 62L34 74' %s/>" % stroke
		"focus": return "<path d='M27 70L55 33 M49 27L61 39 M59 25L70 19L66 32' %s/><circle cx='68' cy='23' r='8' %s/>" % [stroke, fill]
		"armor_head": return "<path d='M25 52Q25 24 48 21Q71 24 71 52V69H58V49H38V69H25Z' %s/>" % stroke
		"armor_chest", "armor": return "<path d='M31 24L42 20H54L65 24L73 40L63 47V71H33V47L23 40Z' %s/>" % stroke
		"accessory": return "<circle cx='48' cy='50' r='19' %s/><path d='M37 31L42 20H54L59 31' %s/><circle cx='48' cy='50' r='7' %s/>" % [stroke, stroke, fill]
		"backpack": return "<path d='M29 38H67V70H29Z M36 38V29Q48 20 60 29V38 M29 51H67 M23 45V62 M73 45V62' %s/>" % stroke
		"medical": return "<rect x='23' y='28' width='50' height='40' rx='8' %s/><path d='M48 35V61 M35 48H61' %s/>" % [stroke, stroke]
		"mana_consumable": return "<path d='M39 22H57 M42 22V33Q30 43 32 59Q34 72 48 72Q62 72 64 59Q66 43 54 33V22 M37 53Q48 45 60 53' %s/>" % stroke
		"character", "portrait": return "<circle cx='48' cy='33' r='12' %s/><path d='M27 69Q30 49 48 49Q66 49 69 69' %s/>" % [stroke, stroke]
		"loadout": return "<path d='M48 19L69 29V47Q68 63 48 72Q28 63 27 47V29Z M37 46L45 54L61 36' %s/>" % stroke
		"spellbook": return "<path d='M22 26Q35 22 47 31V69Q35 60 22 65Z M74 26Q61 22 49 31V69Q61 60 74 65Z M48 31V69' %s/>" % stroke
		"workshop", "rune": return "<polygon points='48,19 72,46 48,70 24,46' %s/><circle cx='48' cy='46' r='9' %s/>" % [stroke, stroke]
		"craft": return "<path d='M25 66L58 33 M51 25L70 44 M20 68H74 M33 27H59' %s/>" % stroke
		"upgrades": return "<path d='M28 66V48 M48 66V36 M68 66V24 M20 66H76 M61 31L68 23L75 31' %s/>" % stroke
		"skills": return "<path d='M48 18L56 37L76 39L61 52L66 72L48 61L30 72L35 52L20 39L40 37Z' %s/>" % fill
		"quests": return "<path d='M32 22H64V70H32Z M40 36H56 M40 47H56 M40 58H50' %s/>" % stroke
		"merchant": return "<circle cx='48' cy='47' r='25' %s/><path d='M58 34Q48 26 39 35Q32 44 50 48Q67 52 57 62Q47 69 37 60 M48 25V69' %s/>" % [stroke, stroke]
		"map": return "<path d='M21 30L37 22L58 30L75 22V64L58 72L37 64L21 72Z M37 22V64 M58 30V72' %s/>" % stroke
		"bolt", "projectile": return "<path d='M24 50L69 27L56 68L47 53Z M24 50L47 53' %s/>" % fill
		"spray", "cone": return "<path d='M24 48L66 24 M24 48L74 48 M24 48L66 72' %s/><circle cx='23' cy='48' r='6' %s/>" % [stroke, fill]
		"field", "damage_zone": return "<ellipse cx='48' cy='55' rx='29' ry='15' %s/><ellipse cx='48' cy='55' rx='15' ry='7' %s/><path d='M35 43L42 25L49 43L57 22L63 44' %s/>" % [stroke, stroke, stroke]
		"mist", "slow_zone": return "<path d='M22 57Q29 45 38 55Q46 34 57 51Q69 45 74 58Q69 68 57 66H34Q23 68 22 57Z' %s/>" % stroke
		"roots", "root_field": return "<path d='M48 68V25 M48 43L31 32 M48 51L66 37 M48 56L33 69 M48 57L65 70' %s/><path d='M31 32Q27 24 21 27 M66 37Q71 28 77 31' %s/>" % [stroke, stroke]
		"pool", "puddle": return "<path d='M48 19Q64 39 68 48Q72 68 48 72Q24 68 28 48Q32 38 48 19Z' %s/><path d='M36 56Q48 63 61 54' %s/>" % [fill, stroke]
		"wall": return "<path d='M20 28H76V69H20Z M20 46H76 M38 28V46 M59 28V46 M29 46V69 M53 46V69' %s/>" % stroke
		"shield", "barrier": return "<path d='M48 18L72 29V46Q71 64 48 74Q25 64 24 46V29Z' %s/><path d='M35 47L44 56L62 36' %s/>" % [stroke, stroke]
		"mine": return "<path d='M48 19V31 M48 63V75 M19 47H31 M65 47H77 M28 27L37 36 M59 58L68 67 M68 27L59 36 M37 58L28 67' %s/><circle cx='48' cy='47' r='16' %s/>" % [stroke, fill]
		"chain": return "<path d='M23 55L37 39L48 52L61 35L74 48' %s/><circle cx='23' cy='55' r='7' %s/><circle cx='74' cy='48' r='7' %s/>" % [stroke, fill, fill]
		"beam": return "<path d='M19 40H67L77 48L67 56H19L30 48Z' %s/><path d='M28 48H72' %s/>" % [fill, stroke]
		"blink": return "<ellipse cx='31' cy='47' rx='10' ry='24' %s/><ellipse cx='66' cy='47' rx='10' ry='24' %s/><path d='M39 47H57 M51 39L59 47L51 55' %s/>" % [stroke, stroke, stroke]
		"spring": return "<path d='M20 58Q31 46 42 58Q53 70 76 48 M48 22V45 M38 32H58' %s/>" % stroke
		"cleanse": return "<path d='M48 20V70 M23 45H73 M31 28L66 63 M66 28L31 63' %s/><circle cx='48' cy='45' r='23' %s stroke-width='3'/>" % [stroke, stroke]
		"wave": return "<path d='M25 30Q48 47 71 30 M19 45Q48 68 77 45 M25 60Q48 76 71 60' %s/>" % stroke
		"explosion": return "<path d='M48 16L56 35L75 25L65 45L82 53L61 58L65 79L48 65L31 79L35 58L14 53L31 45L21 25L40 35Z' %s/><circle cx='48' cy='51' r='13' fill='#fff4b0'/><circle cx='48' cy='51' r='6' %s/>" % [fill, fill]
		_:
			var shape: int = posmod(motif.hash(), 4)
			if shape == 0: return "<polygon points='48,19 72,47 48,70 24,47' %s/><circle cx='48' cy='47' r='10' %s/>" % [stroke, fill]
			if shape == 1: return "<path d='M23 62Q35 20 48 48Q61 75 73 30 M25 31Q48 68 71 32' %s/>" % stroke
			if shape == 2: return "<circle cx='48' cy='46' r='25' %s/><path d='M48 21L61 66L24 39H72L35 66Z' %s/>" % [stroke, stroke]
			return "<path d='M24 55L37 25L48 65L59 29L73 55' %s/><circle cx='48' cy='47' r='8' %s/>" % [stroke, fill]

static func _initials(value: String) -> String:
	var words: PackedStringArray = value.replace("-", " ").split(" ", false)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].left(2).to_upper()
	return (words[0].left(1) + words[1].left(1)).to_upper()
