# ForgingResultsPanel.gd overview:
# - Purpose: reveal forging loot, describe finds, and hold focus while the panel is open.
# - Sections: constants store flavor text, onready cache widgets, helpers populate messages and handle closing.
extends Control
class_name ForgingResultsPanel

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
    "nails_pack": "Five-count bundle for reinforcement and repairs.",
    "plastic_sheet": "Weathered tarp keeps rain off stored goods.",
    "batteries": "Fresh cells recharge portable gear instantly.",
    "car_battery": "Heavy-duty power core for large builds.",
    "flashlight": "Hand torch ready once batteries hold charge.",
    "bandage": "Sterile wrap heals 10% health when applied.",
    "medicated_bandage": "Herbal wrap restores 25 health on use.",
    "canned_food": "Shelf-stable meal worth 1.5 food units.",
    "feather": "Light fletching for arrows and padded gear.",
    "cloth_scraps": "Cut fabric pieces for packs and padding.",
    "backpack": "Expands carry capacity to 12 forging slots.",
    "ripped_cloth": "Torn fabric ideal for bandages or cords.",
    "rock": "Dense stone chunk for crafting weights or tools.",
    "rope": "Braided line handles hauling duties.",
    "string": "Thin cord for snares and fishing lines.",
    "animal_snare": "Reusable loop trap for catching small game.",
    "vines": "Tough vines twist into rope or lashings.",
    "walnuts": "Rich nuts feed 0.5 food per shell.",
    "wood": "Cut timber fuels fires and builds defenses."
}

# Cache UI nodes so we can rebuild the loot list quickly per result.
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var scroll: ScrollContainer = $Panel/Margin/VBox/ItemScroll
@onready var items_container: VBoxContainer = $Panel/Margin/VBox/ItemScroll/Items
@onready var placeholder_label: Label = $Panel/Margin/VBox/ItemScroll/Items/Placeholder
@onready var close_button: Button = $Panel/Margin/VBox/ButtonRow/CloseButton

func _ready():
    # Start hidden and wait for task results to feed content in.
    visible = false
    set_process_unhandled_input(true)
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
    # Only display when forging succeeded and produced tangible loot.
    if result.is_empty() or !result.get("success", false):
        hide_panel()
        return
    var loot: Array = result.get("loot", [])
    if loot.is_empty():
        hide_panel()
        return
    visible = true
    var action = String(result.get("action", "forging"))
    var carried = int(result.get("items_carried", loot.size()))
    var capacity = int(result.get("carry_capacity", 0))
    var dropped: Array = result.get("dropped_loot", [])
    _update_title(loot, action, carried, capacity)
    _populate_items(loot, dropped)
    if close_button:
        close_button.focus_mode = Control.FOCUS_ALL
        close_button.grab_focus()

func hide_panel():
    visible = false

func _update_title(loot: Array, action: String, carried: int, capacity: int):
    if !is_instance_valid(title_label):
        return
    var total_items := 0
    for entry in loot:
        var qty = int(entry.get("quantity_added", entry.get("quantity", 1)))
        if qty > 0:
            total_items += qty
    var prefix = "Forge Finds"
    if action == "camp_search":
        prefix = "Camp Finds"
    if total_items <= 0:
        title_label.text = prefix
        return
    var carry_fragment = ""
    if capacity > 0:
        var carry_used = max(min(carried, capacity), 0)
        carry_fragment = " | %d/%d slots" % [carry_used, capacity]
    title_label.text = "%s (%d%s)" % [prefix, total_items, carry_fragment]

func _populate_items(loot: Array, dropped: Array):
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
        row.add_theme_constant_override("separation", 2)
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
    if !dropped.is_empty():
        var drop_label = Label.new()
        var dropped_fragments: PackedStringArray = []
        for item in dropped:
            var label = item.get("display_name", item.get("item_id", "Drop"))
            var qty = int(item.get("quantity", 1))
            dropped_fragments.append("%s x%d" % [label, max(qty, 1)])
        drop_label.text = "Dropped (carry limit): %s" % ", ".join(dropped_fragments)
        drop_label.add_theme_color_override("font_color", Color(0.85, 0.5, 0.5))
        drop_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        items_container.add_child(drop_label)

func _describe_item(item_id: String, quantity: int) -> String:
    # Provide quick usage hints, scaling notes where quantity matters.
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
        backdrop.set_corner_radius_all(8)
        backdrop.set_border_width_all(2)
        backdrop.border_color = Color(0.3, 0.3, 0.3, 1.0)
        panel.add_theme_stylebox_override("panel", backdrop)
    if close_button:
        close_button.text = "Close"
        close_button.add_theme_color_override("font_color", Color.WHITE)
    if placeholder_label:
        placeholder_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
        placeholder_label.text = "No items collected."
    if title_label:
        title_label.text = "Forge Finds"
        title_label.add_theme_color_override("font_color", Color.WHITE)
