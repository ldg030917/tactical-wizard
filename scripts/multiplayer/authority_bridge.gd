class_name AuthorityBridge
extends Node

## Local raids use this same validation boundary that an online server can own later.
## Persistence-critical mutations remain in GameState and are never accepted from a
## client without validating ownership, capacity, and current raid state.

signal validated_inventory_transaction(peer_id: int, transaction: Dictionary)
signal rejected_inventory_transaction(peer_id: int, reason: String)

@export var server_authoritative_combat: bool = true
@export var server_authoritative_inventory: bool = true
@export var reject_duplicate_transaction_ids: bool = true

var processed_transaction_ids: Dictionary = {}

func validate_local_transaction(transaction: Dictionary) -> bool:
	return _validate_transaction(multiplayer.get_unique_id(), transaction)

@rpc("any_peer", "call_remote", "reliable")
func request_inventory_transaction(transaction: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_validate_transaction(multiplayer.get_remote_sender_id(), transaction)

func _validate_transaction(peer_id: int, transaction: Dictionary) -> bool:
	var transaction_id: String = str(transaction.get("transaction_id", ""))
	if transaction_id.is_empty():
		rejected_inventory_transaction.emit(peer_id, "Missing transaction identity.")
		return false
	if reject_duplicate_transaction_ids and processed_transaction_ids.has(transaction_id):
		rejected_inventory_transaction.emit(peer_id, "Duplicate transaction rejected.")
		return false
	var operation: String = str(transaction.get("operation", ""))
	if operation not in ["loot_pickup", "equipment_swap", "consume_item", "extract", "player_loot"]:
		rejected_inventory_transaction.emit(peer_id, "Unsupported inventory operation.")
		return false
	processed_transaction_ids[transaction_id] = Time.get_unix_time_from_system()
	validated_inventory_transaction.emit(peer_id, transaction)
	return true
