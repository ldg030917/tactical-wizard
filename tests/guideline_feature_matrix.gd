class_name GuidelineFeatureMatrix
extends RefCounted

## One entry for every numbered section in the refined 90-section UI guideline.
## Partial entries remain explicit so future work is never reported as complete.
var section_titles := PackedStringArray([
	"Game Concept",
	"Main Design Identity",
	"Overall UI Philosophy",
	"UI Visual Language",
	"Image-Based UI Components",
	"Universal Hover Behavior",
	"Tooltip Hierarchy",
	"Start Screen",
	"Base Philosophy",
	"Base Main Navigation",
	"Physical Base Interactions",
	"Base Inventory Screen",
	"Equipment Slots",
	"Combat Equipment Layout",
	"Item Slots",
	"Slot-Based Inventory",
	"Item Rarity Presentation",
	"Item Hover Information",
	"Tooltip Positioning",
	"Tooltip Comparison",
	"Element Icon System",
	"Primary Element Colors",
	"Spellbook Screen",
	"Spellbook Rules",
	"Blank Spellbooks",
	"Spell Customization Screen",
	"Spell Customization Drag and Drop",
	"Spell Preview",
	"Attachment Tooltip",
	"Storage UI",
	"Merchant UI",
	"Basic Equipment Packages",
	"Region Selection UI",
	"Region Hover Panel",
	"Raid Preparation Screen",
	"Raid HUD Philosophy",
	"Raid HUD Layout",
	"Health, Mana, and Stamina Gauges",
	"Health Gauge",
	"Mana Gauge",
	"Stamina Gauge",
	"Combat Hotbar",
	"Melee Interface",
	"Melee Visual Feedback",
	"Spell Targeting UI",
	"Straight Projectile UI",
	"Left-Turn Attachment UI",
	"Right-Turn Attachment UI",
	"High-Lob Attachment UI",
	"Deployable Magic UI",
	"Loot Interaction",
	"Raid Loot UI",
	"Raid Equipment Changes",
	"Spell Attachment Restriction During Raids",
	"Inventory Does Not Pause",
	"Extraction UI",
	"Raid Result Screen",
	"Notification System",
	"Element System",
	"Active Player Element",
	"Element Weakness Feedback",
	"Primary Element and Spell Family",
	"Fire Magic",
	"Water Magic",
	"Ice Family",
	"Lightning Family",
	"Grass Magic",
	"Neutral Magic",
	"Dagger Elements",
	"Dagger Attachments",
	"Armor and Magical Focus",
	"Elemental Regions",
	"Neutral Region",
	"Fire Region",
	"Water Region",
	"Grass Region",
	"Enemy Interface",
	"Melee Enemy AI",
	"Character Specialization",
	"Walpurgis Tickets",
	"UI Input Summary",
	"UI Layer Structure",
	"Required Reusable UI Components",
	"UI Asset Requirements",
	"UI Text Rules",
	"Development Priority",
	"UI Acceptance Criteria",
	"Final UI Rule",
	"Final Game Rules",
	"Overall UI Target"
])

var deferred := {}

var partial := {
	17:"Rarity borders and symbols are represented in data; final rarity-specific border art remains polish.",
	19:"Native tooltips stay on-screen, but cursor-adjacent four-direction placement is not custom-rendered yet.",
	20:"Side-by-side equipment comparison is optional in the guideline and remains future polish.",
	25:"Completed spell pages are playable; blank-page parchment crafting remains a progression expansion.",
	30:"Persistent stash uses the shared slot language; a separate two-grid storage transfer window remains expansion work.",
	44:"Element-colored dagger impacts exist; a bespoke directional slash mesh remains final combat art.",
	57:"Extraction results exist, but the recovered/lost result grid is not yet fully icon-driven.",
	58:"Compact messages and status flashes exist; a reusable stacked notification-toast queue remains partial.",
	61:"Visual weakness feedback exists; distinct weakness audio is pending.",
	70:"Four elemental daggers exist; the current expansion adds spell attachments, not a full dagger-rune system.",
	77:"Enemy health appears only after damage; final enemy element badge art remains polish.",
	80:"Ticket data and raid requirements exist; the dedicated ticket quantity card is still partial.",
	82:"Persistent, interaction, window, tooltip, and modal responsibilities are separated across CanvasLayers/scenes; named layer scenes remain partial.",
	83:"ItemSlot, icon generation, gauges, loot panels, element badges, and TrajectoryPreview are reusable; the full optional component catalog is not yet split into individual scenes.",
	87:"Core visual-recognition acceptance paths pass; optional comparison and final art/audio items remain partial."
}

var design_rules := PackedInt32Array([2, 3, 4, 7, 9, 24, 36, 59, 62, 72, 81, 85, 86, 88, 89, 90])

func status(section: int) -> String:
	if deferred.has(section):
		return "deferred"
	if partial.has(section):
		return "partial"
	if section in design_rules:
		return "design_rule"
	return "tested"

func note(section: int) -> String:
	if deferred.has(section):
		return str(deferred[section])
	if partial.has(section):
		return str(partial[section])
	return ""

