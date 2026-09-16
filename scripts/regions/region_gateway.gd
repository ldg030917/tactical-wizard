@tool
class_name RegionGateway
extends Node3D

const REGION_GRAPH := preload("res://scripts/regions/region_graph.gd")

@export_category("Connected Region")
@export var destination_region_id: String = "neutral_frontier"
@export var gateway_name: String = "중립 관문"
@export var gateway_color: Color = Color("f3df9b")

@export_category("Travel")
@export_range(0.5, 8.0, 0.1, "suffix:s") var channel_duration: float = 0.75

var travelling: bool = false

func _ready() -> void:
	add_to_group("interactable")
	%GatewayLabel.text = gateway_name
	%GatewayCore.material_override = VisualFactory.material(gateway_color, 2.8, true)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and is_node_ready():
		%GatewayLabel.text = gateway_name

func get_interaction_text(_player: PlayerController) -> String:
	if travelling:
		return "%s 여는 중..." % gateway_name
	var current_id: String = GameState.current_raid_region_id
	if not REGION_GRAPH.are_connected(current_id, destination_region_id):
		return "%s (연결 안 됨)" % gateway_name
	var region := ContentRegistry.regions().get(destination_region_id) as RegionData
	if region != null and not GameState.can_enter_raid_region(destination_region_id):
		return "%s (필요: %s)" % [gateway_name, ItemDB.display_name(region.required_ticket_id) if not region.required_ticket_id.is_empty() else "%d 크라운" % region.entry_cost]
	return "%s으로 이동" % gateway_name

func interact(player: PlayerController) -> void:
	if travelling or not REGION_GRAPH.are_connected(GameState.current_raid_region_id, destination_region_id):
		return
	if not GameState.can_enter_raid_region(destination_region_id):
		var raid: Node = _raid_scene()
		if raid != null and raid.has_method("show_message"):
			raid.show_message("관문이 입장 비용을 거부했습니다.")
		return
	travelling = true
	player.set_physics_process(false)
	%GatewayLabel.text = "집중 중..."
	await get_tree().create_timer(channel_duration).timeout
	if not is_inside_tree():
		return
	var network_raid := _raid_scene()
	if NetworkManager.is_connected_to_server() and network_raid != null and network_raid.has_method("request_network_region_travel"):
		network_raid.request_network_region_travel(destination_region_id)
		return
	var main: Node = get_tree().current_scene
	if main.has_method("travel_to_region"):
		main.travel_to_region(destination_region_id)

func _raid_scene() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is RaidScene:
			return node
		node = node.get_parent()
	return null
