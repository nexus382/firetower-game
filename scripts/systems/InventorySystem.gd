extends RefCounted
class_name InventorySystem

signal food_total_changed(new_total: float)
signal item_added(item_id: String, quantity_added: int, food_gained: float, total_food_units: float)

const KEY_DISPLAY_NAME := "display_name"
const KEY_FOOD_UNITS := "food_units"
const KEY_STACK_LIMIT := "stack_limit"

var _item_definitions: Dictionary = {}
var _item_counts: Dictionary = {}
var _total_food_units: float = 0.0

func _init():
    print("📦 InventorySystem ready")

func bootstrap_defaults():
    register_item_definition("mushrooms", {
        KEY_DISPLAY_NAME: "Mushrooms",
        KEY_FOOD_UNITS: 1.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("berries", {
        KEY_DISPLAY_NAME: "Berries",
        KEY_FOOD_UNITS: 1.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("walnuts", {
        KEY_DISPLAY_NAME: "Walnuts",
        KEY_FOOD_UNITS: 0.5,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("grubs", {
        KEY_DISPLAY_NAME: "Grubs",
        KEY_FOOD_UNITS: 0.5,
        KEY_STACK_LIMIT: 99
    })

func register_item_definition(item_id: String, definition: Dictionary) -> Dictionary:
    if item_id.is_empty():
        return {}
    var normalized := {
        KEY_DISPLAY_NAME: String(definition.get(KEY_DISPLAY_NAME, item_id.capitalize())),
        KEY_FOOD_UNITS: float(definition.get(KEY_FOOD_UNITS, 0.0)),
        KEY_STACK_LIMIT: int(definition.get(KEY_STACK_LIMIT, 99))
    }
    _item_definitions[item_id] = normalized
    print("🆕 Item registered: %s (food %.2f)" % [item_id, normalized[KEY_FOOD_UNITS]])
    return normalized

func ensure_item_definition(item_id: String) -> Dictionary:
    if _item_definitions.has(item_id):
        return _item_definitions[item_id]
    return register_item_definition(item_id, {})

func get_item_definition(item_id: String) -> Dictionary:
    return _item_definitions.get(item_id, {})

func get_item_display_name(item_id: String) -> String:
    var definition = get_item_definition(item_id)
    if definition.is_empty():
        return item_id.capitalize()
    return String(definition.get(KEY_DISPLAY_NAME, item_id.capitalize()))

func get_item_count(item_id: String) -> int:
    return _item_counts.get(item_id, 0)

func get_total_food_units() -> float:
    return _total_food_units

func set_total_food_units(amount: float) -> float:
    amount = max(amount, 0.0)
    if is_equal_approx(amount, _total_food_units):
        return _total_food_units
    _total_food_units = amount
    food_total_changed.emit(_total_food_units)
    print("🥫 Food total set -> %.1f" % _total_food_units)
    return _total_food_units

func add_food_units(delta: float) -> float:
    if is_zero_approx(delta):
        return _total_food_units
    return _apply_food_delta(delta)

func has_food_units(amount: float) -> bool:
    amount = max(amount, 0.0)
    return _total_food_units >= amount - 0.0001

func consume_food_units(amount: float) -> Dictionary:
    amount = max(amount, 0.0)
    if amount <= 0.0:
        return {
            "success": false,
            "reason": "no_amount",
            "amount_consumed": 0.0,
            "total_food_units": _total_food_units
        }

    if amount > _total_food_units + 0.0001:
        return {
            "success": false,
            "reason": "insufficient_food",
            "required_food": amount,
            "total_food_units": _total_food_units
        }

    _apply_food_delta(-amount)
    return {
        "success": true,
        "amount_consumed": amount,
        "total_food_units": _total_food_units
    }

func add_item(item_id: String, quantity: int = 1) -> Dictionary:
    if item_id.is_empty() or quantity == 0:
        return {
            "item_id": item_id,
            "quantity_added": 0,
            "new_quantity": get_item_count(item_id),
            "food_gained": 0.0,
            "total_food_units": _total_food_units
        }

    var definition = ensure_item_definition(item_id)
    var current_quantity = get_item_count(item_id)
    var new_quantity = current_quantity + quantity
    _item_counts[item_id] = new_quantity

    var food_per_item = float(definition.get(KEY_FOOD_UNITS, 0.0))
    var food_gained = food_per_item * quantity
    if !is_zero_approx(food_gained):
        _apply_food_delta(food_gained)

    var report := {
        "item_id": item_id,
        "display_name": get_item_display_name(item_id),
        "quantity_added": quantity,
        "new_quantity": new_quantity,
        "food_gained": food_gained,
        "total_food_units": _total_food_units
    }

    item_added.emit(item_id, quantity, food_gained, _total_food_units)
    print("➕ Added %d x %s (food +%.1f -> %.1f)" % [quantity, report["display_name"], food_gained, _total_food_units])

    return report

func clear():
    _item_counts.clear()
    _total_food_units = 0.0
    food_total_changed.emit(_total_food_units)
    print("🧹 Inventory cleared")

func _apply_food_delta(delta: float) -> float:
    _total_food_units = max(_total_food_units + delta, 0.0)
    food_total_changed.emit(_total_food_units)
    return _total_food_units
