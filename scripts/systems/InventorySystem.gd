# InventorySystem.gd overview:
# - Purpose: register resource definitions, track counts, and surface food totals for UI.
# - Sections: signals report changes, dictionaries store items, CRUD helpers register/spend/restock entries.
extends RefCounted
class_name InventorySystem

signal food_total_changed(new_total: float)
signal item_added(item_id: String, quantity_added: int, food_gained: float, total_food_units: float)
signal item_consumed(item_id: String, quantity_removed: int, food_lost: float, total_food_units: float)

const KEY_DISPLAY_NAME := "display_name"
const KEY_FOOD_UNITS := "food_units"
const KEY_STACK_LIMIT := "stack_limit"

const BACKPACK_ITEM_ID := "backpack"
const DEFAULT_CARRY_CAPACITY: int = 5
const BACKPACK_CARRY_CAPACITY: int = 12

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
    register_item_definition("apples", {
        KEY_DISPLAY_NAME: "Apples",
        KEY_FOOD_UNITS: 0.5,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("oranges", {
        KEY_DISPLAY_NAME: "Oranges",
        KEY_FOOD_UNITS: 0.5,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("raspberries", {
        KEY_DISPLAY_NAME: "Raspberries",
        KEY_FOOD_UNITS: 0.5,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("blueberries", {
        KEY_DISPLAY_NAME: "Blueberries",
        KEY_FOOD_UNITS: 0.5,
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
    register_item_definition("fishing_bait", {
        KEY_DISPLAY_NAME: "Fishing Bait",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("fishing_rod", {
        KEY_DISPLAY_NAME: "Fishing Rod",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 1
    })
    register_item_definition("wood", {
        KEY_DISPLAY_NAME: "Wood",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 999
    })
    register_item_definition("kindling", {
        KEY_DISPLAY_NAME: "Kindling",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 999
    })
    register_item_definition("spear", {
        KEY_DISPLAY_NAME: "The Spear",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 1
    })
    register_item_definition("spike_trap", {
        KEY_DISPLAY_NAME: "Spike Trap",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 10
    })
    register_item_definition("ripped_cloth", {
        KEY_DISPLAY_NAME: "Ripped Cloth",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("string", {
        KEY_DISPLAY_NAME: "String",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("rock", {
        KEY_DISPLAY_NAME: "Stone",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("vines", {
        KEY_DISPLAY_NAME: "Vines",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("rope", {
        KEY_DISPLAY_NAME: "Rope",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("cloth_scraps", {
        KEY_DISPLAY_NAME: "Cloth Scraps",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("plastic_sheet", {
        KEY_DISPLAY_NAME: "Plastic Sheet",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("metal_scrap", {
        KEY_DISPLAY_NAME: "Metal Scrap",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("nails", {
        KEY_DISPLAY_NAME: "Nails",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 999
    })
    register_item_definition("duct_tape", {
        KEY_DISPLAY_NAME: "Duct Tape",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("medicinal_herbs", {
        KEY_DISPLAY_NAME: "Medicinal Herbs",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("crafted_knife", {
        KEY_DISPLAY_NAME: "Crafted Knife",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 10
    })
    register_item_definition("fire_starting_bow", {
        KEY_DISPLAY_NAME: "Fire Starting Bow",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 10
    })
    register_item_definition("bow", {
        KEY_DISPLAY_NAME: "Bow",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 1
    })
    register_item_definition("arrow", {
        KEY_DISPLAY_NAME: "Arrow",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("animal_snare", {
        KEY_DISPLAY_NAME: "Animal Snare",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 20
    })
    register_item_definition("flint_and_steel", {
        KEY_DISPLAY_NAME: "Flint and Steel",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("portable_craft_station", {
        KEY_DISPLAY_NAME: "Portable Craft Station",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 1
    })
    register_item_definition("herbal_first_aid_kit", {
        KEY_DISPLAY_NAME: "Herbal First Aid Kit",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 10
    })
    register_item_definition("fuel", {
        KEY_DISPLAY_NAME: "Fuel",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("mechanical_parts", {
        KEY_DISPLAY_NAME: "Mechanical Parts",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("electrical_parts", {
        KEY_DISPLAY_NAME: "Electrical Parts",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("canned_food", {
        KEY_DISPLAY_NAME: "Canned Food",
        KEY_FOOD_UNITS: 1.5,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("nails_pack", {
        KEY_DISPLAY_NAME: "Nails (5 Pack)",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("feather", {
        KEY_DISPLAY_NAME: "Feather",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition(BACKPACK_ITEM_ID, {
        KEY_DISPLAY_NAME: "Backpack",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 1
    })
    register_item_definition("batteries", {
        KEY_DISPLAY_NAME: "Batteries",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 99
    })
    register_item_definition("car_battery", {
        KEY_DISPLAY_NAME: "Car Battery",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 1
    })
    register_item_definition("flashlight", {
        KEY_DISPLAY_NAME: "Flashlight",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 1
    })
    register_item_definition("bandage", {
        KEY_DISPLAY_NAME: "Bandage",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 25
    })
    register_item_definition("medicated_bandage", {
        KEY_DISPLAY_NAME: "Medicated Bandage",
        KEY_FOOD_UNITS: 0.0,
        KEY_STACK_LIMIT: 10
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

func get_item_counts() -> Dictionary:
    return _item_counts.duplicate(true)

func get_total_food_units() -> float:
    return _total_food_units

func get_carry_capacity() -> int:
    var has_pack = get_item_count(BACKPACK_ITEM_ID) > 0
    return BACKPACK_CARRY_CAPACITY if has_pack else DEFAULT_CARRY_CAPACITY

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

func consume_item(item_id: String, quantity: int = 1) -> Dictionary:
    quantity = max(quantity, 0)
    if item_id.is_empty() or quantity <= 0:
        return {
            "success": false,
            "reason": "invalid_request",
            "item_id": item_id,
            "quantity_requested": quantity,
            "quantity_remaining": get_item_count(item_id),
            "total_food_units": _total_food_units
        }

    var current_quantity = get_item_count(item_id)
    if current_quantity < quantity:
        return {
            "success": false,
            "reason": "insufficient_items",
            "item_id": item_id,
            "quantity_requested": quantity,
            "quantity_remaining": current_quantity,
            "total_food_units": _total_food_units
        }

    var definition = ensure_item_definition(item_id)
    var new_quantity = current_quantity - quantity
    _item_counts[item_id] = new_quantity

    var food_per_item = float(definition.get(KEY_FOOD_UNITS, 0.0))
    var food_lost = food_per_item * quantity
    if !is_zero_approx(food_lost):
        _apply_food_delta(-food_lost)

    var report := {
        "success": true,
        "item_id": item_id,
        "display_name": get_item_display_name(item_id),
        "quantity_removed": quantity,
        "quantity_remaining": new_quantity,
        "food_lost": food_lost,
        "total_food_units": _total_food_units
    }

    item_consumed.emit(item_id, quantity, food_lost, _total_food_units)
    print("➖ Removed %d x %s (food -%.1f -> %.1f)" % [quantity, report["display_name"], food_lost, _total_food_units])

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
