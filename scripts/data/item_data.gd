class_name ItemData
extends Resource

@export_category("Identity")
@export var item_id: String = "item_id"
@export var display_name: String = "Item"
@export_multiline var description: String = "Placeholder item."
@export_enum("spellbook", "spell", "spell_modifier", "dagger", "focus", "medical", "mana_consumable", "armor_head", "armor_chest", "accessory", "backpack", "material", "parchment", "valuable", "quest", "ticket", "food", "drink", "weapon", "melee", "ammo", "attachment", "armor", "key") var category: String = "material"
@export_enum("common", "uncommon", "rare", "epic") var rarity: String = "common"

@export_category("Inventory")
@export_range(1, 99, 1) var stack_size: int = 1
@export_range(1, 12, 1) var inventory_slots: int = 1
@export_range(0.0, 20.0, 0.01, "suffix:kg") var weight_kg: float = 0.1
@export_range(0, 5000, 1) var value_crowns: int = 10

@export_category("Equipment and Effects")
@export var weapon_data: WeaponData
@export var base_spell: BaseSpellData
@export var spell_modifier: SpellModifierData
@export var spellbook: SpellbookData
@export var focus: FocusData
@export var dagger: DaggerData
@export var armor_data: ArmorData
@export_enum("fire", "water", "grass", "neutral") var primary_element: String = "neutral"
@export var item_family: String = "arcane"
@export_range(0.0, 200.0, 1.0) var healing_amount: float = 0.0
@export_range(0.0, 200.0, 1.0) var mana_restore_amount: float = 0.0
@export var stops_bleeding: bool = false
@export_range(0.0, 100.0, 1.0) var armor_points: float = 0.0
@export_range(0.0, 1.0, 0.01) var fire_resistance: float = 0.0
@export_range(0.0, 1.0, 0.01) var ice_resistance: float = 0.0
@export_range(0.25, 2.0, 0.01) var mana_regeneration_multiplier: float = 1.0
@export_range(0, 40, 1) var capacity_slots: int = 0
@export var secure_storage_eligible: bool = true

@export_group("Attachment Modifiers")
@export_enum("none", "sight", "muzzle", "magazine", "grip") var attachment_type: String = "none"
@export_range(0.25, 2.0, 0.01) var spread_multiplier: float = 1.0
@export_range(0.25, 2.0, 0.01) var recoil_multiplier: float = 1.0
@export_range(0.25, 2.0, 0.01) var damage_multiplier: float = 1.0
@export_range(0, 30, 1) var magazine_capacity_bonus: int = 0
@export_range(0.25, 2.0, 0.01) var reload_time_multiplier: float = 1.0
@export_range(0.25, 2.0, 0.01) var range_multiplier: float = 1.0

@export_category("Replaceable Visuals")
@export var placeholder_icon: Texture2D
@export var placeholder_world_model: PackedScene
@export var debug_color: Color = Color.WHITE

func to_runtime_dictionary() -> Dictionary:
	return {
		"name":display_name, "description":description, "category":category, "rarity":rarity,
		"value":value_crowns, "weight":weight_kg, "slots":inventory_slots, "stack":stack_size,
		"weapon_data":weapon_data, "base_spell":base_spell, "spell_modifier":spell_modifier,
		"spellbook":spellbook, "focus":focus, "dagger":dagger, "armor_data":armor_data,
		"primary_element":primary_element, "family":item_family, "heal":healing_amount, "mana_restore":mana_restore_amount,
		"stops_bleed":stops_bleeding, "armor":armor_points, "fire_resist":fire_resistance,
		"ice_resist":ice_resistance, "mana_regen_mult":mana_regeneration_multiplier,
		"capacity":capacity_slots, "secure_eligible":secure_storage_eligible, "attachment_type":attachment_type,
		"spread_mult":spread_multiplier, "recoil_mult":recoil_multiplier,
		"damage_mult":damage_multiplier, "magazine_add":magazine_capacity_bonus,
		"reload_mult":reload_time_multiplier, "range_mult":range_multiplier,
		"color":debug_color.to_html(false), "resource":self
	}
