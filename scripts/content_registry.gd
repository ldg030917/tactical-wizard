class_name ContentRegistry
extends RefCounted

const CONTENT_MANIFEST_PATH := "res://resources/content_manifest.tres"
const EXPANDED_CATALOG := preload("res://resources/expanded_catalog.tres")

static var _recipes: Dictionary = {}
static var _quests: Array[QuestData] = []
static var _upgrades: Dictionary = {}
static var _skills: Dictionary = {}
static var _spells: Dictionary = {}
static var _modifiers: Dictionary = {}
static var _spellbooks: Dictionary = {}
static var _foci: Dictionary = {}
static var _starter_packages: Dictionary = {}
static var _characters: Dictionary = {}
static var _regions: Dictionary = {}
static var _daggers: Dictionary = {}
static var _content_manifest: Resource

static func recipes() -> Dictionary:
	if _recipes.is_empty():
		for resource: Resource in _manifest_resources("crafting_recipes"):
			var recipe := resource as CraftingRecipeData
			if recipe != null:
				_recipes[recipe.recipe_id] = recipe
	return _recipes

static func quests() -> Array[QuestData]:
	if _quests.is_empty():
		for resource: Resource in _manifest_resources("quests"):
			var quest := resource as QuestData
			if quest != null:
				_quests.append(quest)
		_quests.sort_custom(func(a: QuestData, b: QuestData) -> bool: return a.sort_order < b.sort_order)
	return _quests

static func upgrades() -> Dictionary:
	if _upgrades.is_empty():
		for resource: Resource in _manifest_resources("base_upgrades"):
			var upgrade := resource as BaseUpgradeData
			if upgrade != null:
				_upgrades[upgrade.upgrade_id] = upgrade
	return _upgrades

static func skills() -> Dictionary:
	if _skills.is_empty():
		for resource: Resource in _manifest_resources("skills"):
			var skill := resource as SkillData
			if skill != null:
				_skills[skill.skill_id] = skill
	return _skills

static func spells() -> Dictionary:
	if _spells.is_empty():
		for resource: Resource in _manifest_resources("base_spells"):
			var spell := resource as BaseSpellData
			if spell != null:
				_spells[spell.spell_id] = spell
		for resource: Resource in EXPANDED_CATALOG.spells:
			var expanded_spell := resource as BaseSpellData
			if expanded_spell != null:
				_spells[expanded_spell.spell_id] = expanded_spell
	return _spells

static func modifiers() -> Dictionary:
	if _modifiers.is_empty():
		for resource: Resource in _manifest_resources("spell_modifiers"):
			var modifier := resource as SpellModifierData
			if modifier != null:
				_modifiers[modifier.modifier_id] = modifier
		for resource: Resource in EXPANDED_CATALOG.modifiers:
			var expanded_modifier := resource as SpellModifierData
			if expanded_modifier != null:
				_modifiers[expanded_modifier.modifier_id] = expanded_modifier
	return _modifiers

static func spellbooks() -> Dictionary:
	if _spellbooks.is_empty():
		for resource: Resource in _manifest_resources("spellbooks"):
			var book := resource as SpellbookData
			if book != null:
				_spellbooks[book.spellbook_id] = book
	return _spellbooks

static func foci() -> Dictionary:
	if _foci.is_empty():
		for resource: Resource in _manifest_resources("foci"):
			var focus := resource as FocusData
			if focus != null:
				_foci[focus.focus_id] = focus
	return _foci

static func starter_packages() -> Dictionary:
	if _starter_packages.is_empty():
		for resource: Resource in _manifest_resources("starter_packages"):
			var package := resource as StarterPackageData
			if package != null:
				_starter_packages[package.package_id] = package
	return _starter_packages

static func characters() -> Dictionary:
	if _characters.is_empty():
		for resource: Resource in _manifest_resources("characters"):
			var character := resource as CharacterData
			if character != null:
				_characters[character.character_id] = character
	return _characters

static func regions() -> Dictionary:
	if _regions.is_empty():
		for resource: Resource in _manifest_resources("regions"):
			var region := resource as RegionData
			if region != null:
				_regions[region.region_id] = region
	return _regions

static func daggers() -> Dictionary:
	if _daggers.is_empty():
		for resource: Resource in _manifest_resources("daggers"):
			var dagger := resource as DaggerData
			if dagger != null:
				_daggers[dagger.dagger_id] = dagger
	return _daggers

static func _manifest_resources(property_name: StringName) -> Variant:
	if _content_manifest == null:
		_content_manifest = load(CONTENT_MANIFEST_PATH)
	var result: Array[Resource] = []
	var manifest_value: Variant = _content_manifest.get(property_name)
	if manifest_value is Array:
		for resource: Resource in manifest_value:
			if resource != null:
				result.append(resource)
	var folders := {
		"base_spells":"res://resources/spells",
		"spell_modifiers":"res://resources/modifiers",
		"spellbooks":"res://resources/spellbooks",
		"foci":"res://resources/equipment",
		"starter_packages":"res://resources/starter_packages",
		"characters":"res://resources/characters",
		"regions":"res://resources/regions",
		"daggers":"res://resources/daggers"
	}
	var folder: String = str(folders.get(str(property_name), ""))
	if not folder.is_empty():
		for file_name: String in DirAccess.get_files_at(folder):
			if file_name.get_extension() != "tres":
				continue
			var resource := load(folder.path_join(file_name)) as Resource
			if resource != null and resource not in result:
				result.append(resource)
	return result
