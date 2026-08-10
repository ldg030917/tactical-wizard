class_name CraftingRecipeData
extends Resource

@export_category("Recipe")
@export var recipe_id: String = "recipe"
@export var display_name: String = "Craft Item"
@export_multiline var description: String = ""
@export var ingredients: Array[CraftIngredientData] = []
@export var output_item: ItemData
@export_range(1, 99, 1) var output_quantity: int = 1
@export_range(1, 3, 1) var required_workbench_level: int = 1
@export_range(0, 5000, 1) var currency_cost: int = 0
