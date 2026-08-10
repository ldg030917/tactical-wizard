class_name SpellbookData
extends Resource

@export_category("Spellbook Identity")
@export var spellbook_id: String = "spellbook"
@export var display_name: String = "Field Grimoire"
@export_multiline var description: String = "A reusable platform for prepared spell pages."
@export_enum("common", "uncommon", "rare", "epic") var rarity: String = "common"

@export_category("Page Rules")
@export_range(1, 6, 1) var number_of_pages: int = 3
@export_range(0, 4, 1) var maximum_modifiers_per_page: int = 2
@export var compatible_spell_forms: Array[String] = ["projectile", "area"]

@export_category("Casting Bonuses")
@export_range(0.5, 2.0, 0.01) var casting_speed_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var mana_efficiency_multiplier: float = 1.0

@export_category("Inventory")
@export_range(1, 12, 1) var inventory_slots: int = 3
@export_range(0.0, 20.0, 0.01, "suffix:kg") var weight_kg: float = 1.4

@export_category("Replaceable Presentation")
@export var placeholder_visual_scene: PackedScene
@export var placeholder_icon: Texture2D
@export var debug_color: Color = Color("7251a6")
