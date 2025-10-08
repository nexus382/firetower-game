extends Control
class_name ForgingResultsPanel

const BASIC_FIND_MESSAGES := [
    "Looking thru the woods you find",
    "Luckily you were able to locate",
    "You have found",
    "You came across"
]

const ADVANCED_FIND_MESSAGES := [
    "You come across an abandoned vehicle",
    "You came across a Camp Site",
    "You found a torn up Backpack",
    "You found some abandoned items"
]

const ITEM_DETAILS := {
    "berries": "Bright berries bump food by 1.0 unit.",
    "duct_tape": "Adhesive fix-all for quick structural patches.",
    "electrical_parts": "Leads and circuits for powered projects.",
    "fuel": "Sealed cans offer 3-5 units for generators or heaters.",
    "grubs": "Protein rich insects add 0.5 food.",
    "mechanical_parts": "Gears and springs ready for trap repairs.",
    "medicinal_herbs": "Fragrant herbs for basic salves and teas.",
    "metal_scrap": "Bent plating suited for armor or tools.",
    "mushrooms": "Earthy caps restore 1.0 food unit.",
    "nails": "Loose nails arrive in packs for rapid construction.",
    "plastic_sheet": "Weathered tarp keeps rain off stored goods.",
    "ripped_cloth": "Torn fabric ideal for bandages or cords.",
    "rock": "Dense stone chunk for crafting weights or tools.",
    "rope": "Braided line handles hauling duties.",
    "string": "Thin cord for snares and fishing lines.",
    "vines": "Tough vines twist into rope or lashings.",
    "walnuts": "Rich nuts feed 0.5 food per shell.",
    "wood": "Cut timber fuels fires and builds defenses."
}

@onready var panel: Panel = $Panel
@onready var message_label: Label = $Panel/Margin/VBox/MessageLabel
@onready var scroll: ScrollContainer = $Panel/Margin/VBox/ItemScroll
@onready var items_container: VBoxContainer = $Panel/Margin/VBox/ItemScroll/Items
@onready var placeholder_label: Label = $Panel/Margin/VBox/ItemScroll/Items/Placeholder
@onready var close_button: Button = $Panel/Margin/VBox/ButtonRow/CloseButton

var _rng := RandomNumberGenerator.new()

func _ready():
    visible = false
    set_process_unhandled_input(true)
    _rng.randomize()
    _apply_theme_overrides()
    if close_button:
        close_button.pressed.connect(hide_panel)

func _unhandled_input(event):
    if !visible:
        return
    if event.is_action_pressed("ui_cancel") and !event.is_echo():
        hide_panel()
        get_viewport().set_input_as_handled()

func show_result(result: Dictionary):
    if result.is_empty() or !result.get("success", false):
        hide_panel()
        return
    var loot: Array = result.get("loot", [])
    if loot.is_empty():
        hide_panel()
        return
    visible = true
    _populate_message(loot)
    _populate_items(loot)
    if close_button:
        close_button.focus_mode = Control.FOCUS_ALL
        close_button.grab_focus()

func hide_panel():
    visible = false

func _populate_message(loot: Array):
    if !is_instance_valid(message_label):
        return
    var advanced_found = false
    var summary: PackedStringArray = []
    for entry in loot:
        var label = String(entry.get("display_name", entry.get("item_id", "")))
        var qty = int(entry.get("quantity_added", entry.get("quantity", 1)))
        if qty <= 0:
            continue
        summary.append("%s x%d" % [label, qty])
        if String(entry.get("tier", "basic")) == "advanced":
            advanced_found = true
    if summary.is_empty():
        message_label.text = "Nothing new surfaced."
        return
    var pool = advanced_found ? ADVANCED_FIND_MESSAGES : BASIC_FIND_MESSAGES
    var prefix = pool[_rng.randi_range(0, pool.size() - 1)] if pool.size() > 0 else "Found"
    message_label.text = "%s %s." % [prefix, ", ".join(summary)]

func _populate_items(loot: Array):
    if !is_instance_valid(items_container):
        return
    for child in items_container.get_children():
        if child != placeholder_label:
            child.queue_free()
    var entries: Array = []
    for entry in loot:
        var qty = int(entry.get("quantity_added", entry.get("quantity", 1)))
        if qty <= 0:
            continue
        entries.append({
            "item_id": String(entry.get("item_id", "")),
            "display_name": String(entry.get("display_name", entry.get("item_id", "Item"))),
            "quantity": qty,
            "tier": String(entry.get("tier", "basic"))
        })
    if entries.is_empty():
        if is_instance_valid(placeholder_label):
            placeholder_label.text = "No items collected."
            placeholder_label.show()
        return
    if is_instance_valid(placeholder_label):
        placeholder_label.hide()
    for entry in entries:
        var row = VBoxContainer.new()
        row.theme_override_constants["separation"] = 2
        var name_label = Label.new()
        name_label.text = "%s x%d" % [entry.get("display_name", entry.get("item_id", "Item")), int(entry.get("quantity", 0))]
        name_label.add_theme_color_override("font_color", Color.WHITE)
        row.add_child(name_label)
        var detail_label = Label.new()
        detail_label.text = _describe_item(entry.get("item_id", ""), int(entry.get("quantity", 0)))
        detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        detail_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
        row.add_child(detail_label)
        items_container.add_child(row)

func _describe_item(item_id: String, quantity: int) -> String:
    var base = ITEM_DETAILS.get(item_id, "Useful supply ready for storage.")
    if item_id == "nails":
        return "%s Each bundle carries %d pieces." % [base, max(quantity, 0)]
    if item_id == "fuel":
        return "%s This haul totals %d units." % [base, max(quantity, 0)]
    return base

func _apply_theme_overrides():
    if panel:
        var backdrop := StyleBoxFlat.new()
        backdrop.bg_color = Color(0.08, 0.08, 0.08, 1.0)
        backdrop.corner_radius_all = 8
        backdrop.border_width_all = 2
        backdrop.border_color = Color(0.3, 0.3, 0.3, 1.0)
        panel.add_theme_stylebox_override("panel", backdrop)
    if close_button:
        close_button.text = "Close"
        close_button.add_theme_color_override("font_color", Color.WHITE)
    if placeholder_label:
        placeholder_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
        placeholder_label.text = "No items collected."
    if message_label:
        message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        message_label.add_theme_color_override("font_color", Color.WHITE)
