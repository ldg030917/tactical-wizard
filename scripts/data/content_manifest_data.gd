class_name ContentManifestData
extends Resource

## Statically referenced game content. Keeping the catalog in a Resource makes the
## same assets available to editor runs, debug exports, and release exports.

@export_category("Inventory")
@export var items: Array[Resource] = []

@export_category("Base Content")
@export var crafting_recipes: Array[Resource] = []
@export var quests: Array[Resource] = []
@export var base_upgrades: Array[Resource] = []
@export var skills: Array[Resource] = []

@export_category("Magic")
@export var base_spells: Array[Resource] = []
@export var spell_modifiers: Array[Resource] = []
@export var spellbooks: Array[Resource] = []
@export var foci: Array[Resource] = []
@export var starter_packages: Array[Resource] = []

@export_category("World and Characters")
@export var characters: Array[Resource] = []
@export var regions: Array[Resource] = []
@export var daggers: Array[Resource] = []
