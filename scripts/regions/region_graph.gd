class_name RegionGraph
extends RefCounted

const ENTRY_REGION_ID := "neutral_frontier"

const CONNECTIONS := {
	"neutral_frontier":["fire_region", "water_region", "grass_region"],
	"fire_region":["neutral_frontier", "water_region", "grass_region"],
	"water_region":["neutral_frontier", "fire_region", "grass_region"],
	"grass_region":["neutral_frontier", "fire_region", "water_region"]
}

static func connected_regions(region_id: String) -> Array[String]:
	var result: Array[String] = []
	for destination: Variant in CONNECTIONS.get(region_id, []):
		result.append(str(destination))
	return result

static func are_connected(from_region_id: String, to_region_id: String) -> bool:
	return to_region_id in connected_regions(from_region_id)

