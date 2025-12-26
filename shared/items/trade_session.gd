class_name TradeSession
extends RefCounted
## Manages a trade session between two players.
## Both players must confirm before trade executes.


## Trade state
enum State {
	PENDING,     ## Waiting for both players to add items
	CONFIRMED,   ## Both players confirmed
	COMPLETED,   ## Trade executed
	CANCELLED,   ## Trade was cancelled
}


## Signal emitted when trade state changes
signal state_changed(new_state: State)

## Signal emitted when items are updated
signal items_updated(player_id: String)

## Signal emitted when trade completes
signal completed

## Signal emitted when trade is cancelled
signal cancelled(reason: String)


## Unique trade session ID
var id: String = ""

## Player A info
var player_a_id: String = ""
var player_a_name: String = ""
var player_a_items: Array[ItemStack] = []
var player_a_confirmed: bool = false

## Player B info
var player_b_id: String = ""
var player_b_name: String = ""
var player_b_items: Array[ItemStack] = []
var player_b_confirmed: bool = false

## Current state
var state: State = State.PENDING

## Timestamp when trade was initiated
var created_at: float = 0.0

## Timeout duration in seconds
var timeout_duration: float = 120.0  # 2 minutes

## Reference to item registry
var _item_registry: ItemRegistry


func _init(item_registry: ItemRegistry = null) -> void:
	_item_registry = item_registry
	id = _generate_id()


## Generate unique trade ID
func _generate_id() -> String:
	return "trade_%d_%d" % [Time.get_unix_time_from_system(), randi()]


## Initialize trade between two players
func init_trade(
	p_a_id: String,
	p_a_name: String,
	p_b_id: String,
	p_b_name: String,
	server_time: float
) -> void:
	player_a_id = p_a_id
	player_a_name = p_a_name
	player_b_id = p_b_id
	player_b_name = p_b_name
	created_at = server_time
	state = State.PENDING


## Check if a player is part of this trade
func has_player(player_id: String) -> bool:
	return player_id == player_a_id or player_id == player_b_id


## Get the other player's ID
func get_other_player(player_id: String) -> String:
	if player_id == player_a_id:
		return player_b_id
	elif player_id == player_b_id:
		return player_a_id
	return ""


## Add item to trade from a player
func add_item(player_id: String, stack: ItemStack) -> bool:
	if state != State.PENDING:
		return false

	if stack == null or stack.is_empty():
		return false

	# Reset confirmations when items change
	_reset_confirmations()

	if player_id == player_a_id:
		player_a_items.append(stack)
		items_updated.emit(player_id)
		return true
	elif player_id == player_b_id:
		player_b_items.append(stack)
		items_updated.emit(player_id)
		return true

	return false


## Remove item from trade
func remove_item(player_id: String, stack: ItemStack) -> bool:
	if state != State.PENDING:
		return false

	# Reset confirmations when items change
	_reset_confirmations()

	var items: Array[ItemStack]
	if player_id == player_a_id:
		items = player_a_items
	elif player_id == player_b_id:
		items = player_b_items
	else:
		return false

	var idx := items.find(stack)
	if idx >= 0:
		items.remove_at(idx)
		items_updated.emit(player_id)
		return true

	return false


## Clear all items from a player
func clear_items(player_id: String) -> void:
	if state != State.PENDING:
		return

	_reset_confirmations()

	if player_id == player_a_id:
		player_a_items.clear()
		items_updated.emit(player_id)
	elif player_id == player_b_id:
		player_b_items.clear()
		items_updated.emit(player_id)


## Get items offered by a player
func get_items(player_id: String) -> Array[ItemStack]:
	if player_id == player_a_id:
		return player_a_items
	elif player_id == player_b_id:
		return player_b_items
	return []


## Confirm trade from a player
func confirm(player_id: String) -> bool:
	if state != State.PENDING:
		return false

	if player_id == player_a_id:
		player_a_confirmed = true
	elif player_id == player_b_id:
		player_b_confirmed = true
	else:
		return false

	# Check if both confirmed
	if player_a_confirmed and player_b_confirmed:
		state = State.CONFIRMED
		state_changed.emit(state)

	return true


## Unconfirm (cancel confirmation)
func unconfirm(player_id: String) -> bool:
	if state != State.PENDING:
		return false

	if player_id == player_a_id:
		player_a_confirmed = false
		return true
	elif player_id == player_b_id:
		player_b_confirmed = false
		return true

	return false


## Check if player has confirmed
func is_confirmed(player_id: String) -> bool:
	if player_id == player_a_id:
		return player_a_confirmed
	elif player_id == player_b_id:
		return player_b_confirmed
	return false


## Reset all confirmations
func _reset_confirmations() -> void:
	player_a_confirmed = false
	player_b_confirmed = false


## Execute the trade (transfer items)
## Returns true if successful
func execute(
	inventory_a: Inventory,
	inventory_b: Inventory
) -> bool:
	if state != State.CONFIRMED:
		return false

	# Verify both players still have the items
	for stack in player_a_items:
		if not _inventory_has_stack(inventory_a, stack):
			cancel("Player A no longer has required items")
			return false

	for stack in player_b_items:
		if not _inventory_has_stack(inventory_b, stack):
			cancel("Player B no longer has required items")
			return false

	# Check weight capacity
	var weight_a := _get_total_weight(player_b_items) - _get_total_weight(player_a_items)
	var weight_b := _get_total_weight(player_a_items) - _get_total_weight(player_b_items)

	if not inventory_a.can_hold_weight(weight_a):
		cancel("Player A cannot carry traded items")
		return false

	if not inventory_b.can_hold_weight(weight_b):
		cancel("Player B cannot carry traded items")
		return false

	# Remove items from original owners
	for stack in player_a_items:
		_remove_stack_from_inventory(inventory_a, stack)

	for stack in player_b_items:
		_remove_stack_from_inventory(inventory_b, stack)

	# Add items to new owners
	for stack in player_a_items:
		inventory_b.add_stack(stack)

	for stack in player_b_items:
		inventory_a.add_stack(stack)

	state = State.COMPLETED
	state_changed.emit(state)
	completed.emit()

	return true


## Check if inventory has a matching stack
func _inventory_has_stack(inventory: Inventory, stack: ItemStack) -> bool:
	if stack.item == null or stack.item.definition == null:
		return false

	var item_id := stack.item.definition.id
	return inventory.has_item(item_id, stack.count)


## Remove a stack from inventory
func _remove_stack_from_inventory(inventory: Inventory, stack: ItemStack) -> void:
	if stack.item == null or stack.item.definition == null:
		return

	var item_id := stack.item.definition.id
	inventory.remove_items_by_id(item_id, stack.count)


## Get total weight of item array
func _get_total_weight(items: Array[ItemStack]) -> float:
	var total := 0.0
	for stack in items:
		total += stack.get_weight()
	return total


## Cancel the trade
func cancel(reason: String = "Trade cancelled") -> void:
	if state == State.COMPLETED:
		return

	state = State.CANCELLED
	state_changed.emit(state)
	cancelled.emit(reason)


## Check if trade has timed out
func is_timed_out(current_time: float) -> bool:
	return current_time >= created_at + timeout_duration


## Get time remaining
func get_time_remaining(current_time: float) -> float:
	var remaining := (created_at + timeout_duration) - current_time
	return maxf(0.0, remaining)


## Get trade summary for display
func get_summary(for_player_id: String) -> String:
	var lines: Array[String] = []

	var is_player_a := for_player_id == player_a_id
	var my_name := player_a_name if is_player_a else player_b_name
	var their_name := player_b_name if is_player_a else player_a_name
	var my_items := player_a_items if is_player_a else player_b_items
	var their_items := player_b_items if is_player_a else player_a_items
	var my_confirmed := player_a_confirmed if is_player_a else player_b_confirmed
	var their_confirmed := player_b_confirmed if is_player_a else player_a_confirmed

	lines.append("Trade with %s" % their_name)
	lines.append("")

	lines.append("You offer (%d items):" % my_items.size())
	for stack in my_items:
		lines.append("  - %s" % stack.get_display_text())
	if my_items.is_empty():
		lines.append("  (nothing)")

	lines.append("")
	lines.append("They offer (%d items):" % their_items.size())
	for stack in their_items:
		lines.append("  - %s" % stack.get_display_text())
	if their_items.is_empty():
		lines.append("  (nothing)")

	lines.append("")
	lines.append("Status:")
	lines.append("  You: %s" % ("Confirmed" if my_confirmed else "Not confirmed"))
	lines.append("  Them: %s" % ("Confirmed" if their_confirmed else "Not confirmed"))

	return "\n".join(lines)


## Serialize to dictionary
func to_dict() -> Dictionary:
	var a_items: Array = []
	for stack in player_a_items:
		a_items.append(stack.to_dict())

	var b_items: Array = []
	for stack in player_b_items:
		b_items.append(stack.to_dict())

	return {
		"id": id,
		"player_a_id": player_a_id,
		"player_a_name": player_a_name,
		"player_a_items": a_items,
		"player_a_confirmed": player_a_confirmed,
		"player_b_id": player_b_id,
		"player_b_name": player_b_name,
		"player_b_items": b_items,
		"player_b_confirmed": player_b_confirmed,
		"state": state,
		"created_at": created_at,
	}


## Deserialize from dictionary
func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	player_a_id = data.get("player_a_id", "")
	player_a_name = data.get("player_a_name", "")
	player_a_confirmed = data.get("player_a_confirmed", false)
	player_b_id = data.get("player_b_id", "")
	player_b_name = data.get("player_b_name", "")
	player_b_confirmed = data.get("player_b_confirmed", false)
	state = data.get("state", State.PENDING)
	created_at = data.get("created_at", 0.0)

	# Restore items (need item registry)
	if _item_registry != null:
		player_a_items = []
		var a_data: Array = data.get("player_a_items", [])
		for item_data in a_data:
			var stack := ItemStack.from_dict(item_data, _item_registry)
			if stack != null:
				player_a_items.append(stack)

		player_b_items = []
		var b_data: Array = data.get("player_b_items", [])
		for item_data in b_data:
			var stack := ItemStack.from_dict(item_data, _item_registry)
			if stack != null:
				player_b_items.append(stack)


## Trade Manager - tracks all active trades
class Manager extends RefCounted:
	## Active trades indexed by ID
	var _trades: Dictionary = {}

	## Trades indexed by player ID
	var _by_player: Dictionary = {}

	## Reference to item registry
	var _item_registry: ItemRegistry


	func _init(item_registry: ItemRegistry = null) -> void:
		_item_registry = item_registry


	## Create a new trade session
	func create_trade(
		player_a_id: String,
		player_a_name: String,
		player_b_id: String,
		player_b_name: String,
		server_time: float
	) -> TradeSession:
		# Check if either player is already in a trade
		if has_active_trade(player_a_id):
			return null
		if has_active_trade(player_b_id):
			return null

		var trade := TradeSession.new(_item_registry)
		trade.init_trade(player_a_id, player_a_name, player_b_id, player_b_name, server_time)

		_trades[trade.id] = trade
		_by_player[player_a_id] = trade.id
		_by_player[player_b_id] = trade.id

		return trade


	## Get trade by ID
	func get_trade(trade_id: String) -> TradeSession:
		return _trades.get(trade_id, null)


	## Get active trade for a player
	func get_player_trade(player_id: String) -> TradeSession:
		var trade_id: String = _by_player.get(player_id, "")
		if trade_id.is_empty():
			return null
		return get_trade(trade_id)


	## Check if player has an active trade
	func has_active_trade(player_id: String) -> bool:
		var trade := get_player_trade(player_id)
		return trade != null and trade.state == TradeSession.State.PENDING


	## Remove a trade
	func remove_trade(trade_id: String) -> void:
		var trade := get_trade(trade_id)
		if trade != null:
			_by_player.erase(trade.player_a_id)
			_by_player.erase(trade.player_b_id)
			_trades.erase(trade_id)


	## Cancel a player's active trade
	func cancel_player_trade(player_id: String, reason: String = "Cancelled") -> void:
		var trade := get_player_trade(player_id)
		if trade != null:
			trade.cancel(reason)
			remove_trade(trade.id)


	## Cleanup timed out and completed/cancelled trades
	func cleanup(current_time: float) -> Array[String]:
		var to_remove: Array[String] = []

		for trade_id in _trades.keys():
			var trade: TradeSession = _trades[trade_id]

			if trade.state == TradeSession.State.COMPLETED:
				to_remove.append(trade_id)
			elif trade.state == TradeSession.State.CANCELLED:
				to_remove.append(trade_id)
			elif trade.is_timed_out(current_time):
				trade.cancel("Trade timed out")
				to_remove.append(trade_id)

		for trade_id in to_remove:
			remove_trade(trade_id)

		return to_remove


	## Get count of active trades
	func get_count() -> int:
		return _trades.size()


	## Clear all trades
	func clear() -> void:
		_trades.clear()
		_by_player.clear()
