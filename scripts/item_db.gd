class_name ItemDB
extends RefCounted

const CONTENT_MANIFEST_PATH := "res://resources/content_manifest.tres"
const EXPANDED_CATALOG := preload("res://resources/expanded_catalog.tres")
static var _items: Dictionary = {}
static var _content_manifest: Resource

static func all_items() -> Dictionary:
	_ensure_loaded()
	return _items

static func resource(item_id: String) -> ItemData:
	_ensure_loaded()
	return _items.get(item_id) as ItemData

static func get_item(item_id: String) -> Dictionary:
	var item: ItemData = resource(item_id)
	if item == null:
		return {"name":item_id, "category":"unknown", "value":0, "weight":0.0, "slots":1, "stack":1, "color":"ffffff"}
	return item.to_runtime_dictionary()

static func display_name(item_id: String) -> String:
	var item: ItemData = resource(item_id)
	return item.display_name if item != null else item_id

static func color(item_id: String) -> Color:
	var item: ItemData = resource(item_id)
	return item.debug_color if item != null else Color.WHITE

static func weapon(item_id: String) -> WeaponData:
	var item: ItemData = resource(item_id)
	return item.weapon_data if item != null else null

static func spell(item_id: String) -> BaseSpellData:
	var item: ItemData = resource(item_id)
	return item.base_spell if item != null else null

static func modifier(item_id: String) -> SpellModifierData:
	var item: ItemData = resource(item_id)
	return item.spell_modifier if item != null else null

static func spellbook(item_id: String) -> SpellbookData:
	var item: ItemData = resource(item_id)
	return item.spellbook if item != null else null

static func focus(item_id: String) -> FocusData:
	var item: ItemData = resource(item_id)
	return item.focus if item != null else null

static func dagger(item_id: String) -> DaggerData:
	var item: ItemData = resource(item_id)
	return item.dagger if item != null else null

static func _ensure_loaded() -> void:
	if not _items.is_empty():
		return
	if _content_manifest == null:
		_content_manifest = load(CONTENT_MANIFEST_PATH)
	var catalog_items: Variant = _content_manifest.get("items")
	for resource: Resource in catalog_items:
		var item := resource as ItemData
		if item != null and not item.item_id.is_empty():
			_items[item.item_id] = item
	for resource: Resource in EXPANDED_CATALOG.items:
		var expanded_item := resource as ItemData
		if expanded_item != null and not expanded_item.item_id.is_empty():
			_items[expanded_item.item_id] = expanded_item
	for file_name: String in DirAccess.get_files_at("res://resources/items"):
		if file_name.get_extension() != "tres":
			continue
		var supplemental := load("res://resources/items".path_join(file_name)) as ItemData
		if supplemental != null and not supplemental.item_id.is_empty():
			_items[supplemental.item_id] = supplemental
