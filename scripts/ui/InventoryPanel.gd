# InventoryPanel.gd overview:
# - Purpose: present the player's inventory, react to inventory system signals, and manage focus while open.
# - Sections: preloads fetch systems, onready caches widgets, helpers resolve GameManager, refresh lists, and handle toggles.
extends Control
class_name InventoryPanel

const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")

# Cache panel pieces for quick refresh without repeated lookups.
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var items_scroll: ScrollContainer = $Panel/Margin/VBox/ItemScroll
@onready var items_container: VBoxContainer = $Panel/Margin/VBox/ItemScroll/Items
@onready var placeholder_label: Label = $Panel/Margin/VBox/ItemScroll/Items/Placeholder
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var close_button: Button = $Panel/Margin/VBox/ButtonRow/CloseButton

var game_manager: GameManager
var inventory_system: InventorySystem

func _ready():
    # Prepare listeners and render the initial inventory snapshot.
    visible = false
    set_process_unhandled_input(true)
    _resolve_game_manager()
    _apply_theme_overrides()
    if close_button:
        close_button.pressed.connect(_close_panel)
    _refresh_items()

func _unhandled_input(event):
    if event.is_action_pressed("inventory_toggle") and !event.is_echo():
        if visible:
            _close_panel()
        else:
            _open_panel()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("ui_cancel") and visible and !event.is_echo():
        _close_panel()
        get_viewport().set_input_as_handled()

func _open_panel():
    # Refresh when opening so newly gained loot appears instantly.
    if !visible:
        visible = true
        _refresh_items()
        if game_manager:
            game_manager.request_tutorial("inventory_intro")
    if items_scroll:
        items_scroll.scroll_vertical = 0
    if close_button:
        close_button.focus_mode = Control.FOCUS_ALL
        close_button.grab_focus()

func _close_panel():
    visible = false

func _resolve_game_manager():
    var tree = get_tree()
    if tree == null:
        return
    var root = tree.get_root()
    if root == null:
        return
    var candidate: Node = root.get_node_or_null("Main/GameManager")
    if candidate is GameManager:
        game_manager = candidate
        inventory_system = game_manager.get_inventory_system()
        if inventory_system:
            inventory_system.item_added.connect(_on_inventory_changed)
            inventory_system.item_consumed.connect(_on_inventory_changed)
    else:
        push_warning("GameManager not found for InventoryPanel")

func _on_inventory_changed(_item_id: String, _quantity_delta: int, _food_delta: float, _total_food: float):
    _refresh_items()

func _refresh_items():
    # Build the visible list sorted by display name for quick scanning.
    if !is_instance_valid(items_container):
        return
    for child in items_container.get_children():
        if child != placeholder_label:
            child.queue_free()
    if inventory_system == null:
        _show_placeholder("Inventory offline")
        return
    var counts: Dictionary = inventory_system.get_item_counts()
    var entries: Array = []
    for item_id in counts.keys():
        var quantity = int(counts.get(item_id, 0))
        if quantity <= 0:
            continue
        entries.append({
            "item_id": String(item_id),
            "display_name": inventory_system.get_item_display_name(item_id),
            "quantity": quantity
        })
    entries.sort_custom(func(a, b): return String(a.get("display_name", "")).nocasecmp_to(String(b.get("display_name", ""))) < 0)
    if entries.is_empty():
        _show_placeholder("Empty pack")
        return
    if is_instance_valid(placeholder_label):
        placeholder_label.hide()
    for entry in entries:
        var item_id = String(entry.get("item_id", ""))
        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)

        var name_label = Label.new()
        name_label.text = _format_item_label(item_id, entry)
        name_label.add_theme_color_override("font_color", Color.WHITE)
        row.add_child(name_label)

        var qty_label = Label.new()
        qty_label.text = "x%d" % int(entry.get("quantity", 0))
        qty_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
        if item_id == "flint_and_steel":
            qty_label.visible = false
        row.add_child(qty_label)

        var actions = _get_item_actions(item_id)
        if actions.size() > 0:
            var spacer = Control.new()
            spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.add_child(spacer)
            for action in actions:
                var button = Button.new()
                button.text = String(action.get("label", "Use"))
                button.focus_mode = Control.FOCUS_ALL
                button.add_theme_color_override("font_color", Color.WHITE)
                var action_key = String(action.get("action", "use"))
                var disabled = bool(action.get("disabled", false))
                var required_item = String(action.get("requires_item", ""))
                if required_item != "" and inventory_system:
                    disabled = disabled or inventory_system.get_item_count(required_item) <= 0
                if action.get("requires_charge", false):
                    var status = game_manager.get_flashlight_status() if game_manager else {}
                    disabled = disabled or int(round(status.get("battery_percent", 0.0))) <= 0
                if action.has("requires_below_percent"):
                    var status_below = game_manager.get_flashlight_status() if game_manager else {}
                    var limit = int(action.get("requires_below_percent", 0))
                    disabled = disabled or int(round(status_below.get("battery_percent", 0.0))) >= limit
                button.disabled = disabled
                button.pressed.connect(Callable(self, "_on_item_action_pressed").bind(item_id, action_key))
                row.add_child(button)

        items_container.add_child(row)

func _show_placeholder(text: String):
    if !is_instance_valid(placeholder_label):
        return
    placeholder_label.text = text
    placeholder_label.show()

func _set_status(text: String):
    if !is_instance_valid(status_label):
        return
    status_label.text = text

func _apply_theme_overrides():
    if panel:
        var backdrop := StyleBoxFlat.new()
        backdrop.bg_color = Color(0.08, 0.08, 0.08, 1.0)
        backdrop.set_corner_radius_all(8)
        backdrop.set_border_width_all(2)
        backdrop.border_color = Color(0.3, 0.3, 0.3, 1.0)
        panel.add_theme_stylebox_override("panel", backdrop)
    if title_label:
        title_label.text = "Inventory"
        title_label.add_theme_color_override("font_color", Color.WHITE)
    if placeholder_label:
        placeholder_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
    if close_button:
        close_button.text = "Close"
        close_button.add_theme_color_override("font_color", Color.WHITE)
    if status_label:
        status_label.add_theme_color_override("font_color", Color.WHITE)
        status_label.text = ""

func _format_item_label(item_id: String, entry: Dictionary) -> String:
    var label = entry.get("display_name", entry.get("item_id", "Item"))
    if item_id == "flashlight" and game_manager:
        var status = game_manager.get_flashlight_status()
        if status.get("has_flashlight", false):
            var percent = int(round(status.get("battery_percent", 0.0)))
            var fragments: PackedStringArray = []
            fragments.append("Battery %d%%" % percent)
            if status.get("active", false):
                fragments.append("Active")
            label = "%s (%s)" % [label, " | ".join(fragments)]
    elif item_id == "flint_and_steel":
        var uses = int(entry.get("quantity", 0))
        label = "%s (%d uses)" % [label, max(uses, 0)]
    return label

func _get_item_actions(item_id: String) -> Array:
    var key = item_id.to_lower()
    match key:
        "flashlight":
            return [
                {
                    "label": "Use",
                    "action": "use",
                    "requires_charge": true
                },
                {
                    "label": "Change Batteries",
                    "action": "change_batteries",
                    "requires_item": "batteries",
                    "requires_below_percent": 100
                }
            ]
        "medicinal_herbs":
            return [{"label": "Use", "action": "use"}]
        "herbal_first_aid_kit":
            return [{"label": "Use", "action": "use"}]
        "bandage":
            return [{"label": "Use", "action": "use"}]
        "medicated_bandage":
            return [{"label": "Use", "action": "use"}]
        _:
            return []

func _on_item_action_pressed(item_id: String, action: String):
    if game_manager == null:
        _set_status("Inventory offline")
        return
    var result = game_manager.perform_inventory_action(item_id, action)
    if !result.get("success", false):
        var reason = String(result.get("reason", "failed"))
        var label = inventory_system.get_item_display_name(item_id) if inventory_system else item_id.capitalize()
        match reason:
            "insufficient_stock":
                _set_status("No %s left" % label)
            "consume_failed":
                _set_status("Use failed")
            "systems_unavailable":
                _set_status("Systems unavailable")
            "unsupported_item":
                _set_status("Can't use that")
            "no_batteries":
                _set_status("Need batteries")
            "no_battery":
                _set_status("Battery empty")
            "missing_flashlight":
                _set_status("Flashlight missing")
            "battery_full":
                _set_status("Battery already full")
            _:
                _set_status("Use failed")
        _refresh_items()
        return

    var display_name = result.get("display_name", inventory_system.get_item_display_name(item_id) if inventory_system else item_id.capitalize())
    var healed = float(result.get("heal_applied", 0.0))
    var health_after = float(result.get("health_after", 0.0))
    if healed > 0.0:
        _set_status("Used %s (+%d health -> %d%%)" % [display_name, int(round(healed)), int(round(health_after))])
    elif result.get("action", "") == "flashlight_toggle":
        var active = result.get("flashlight_active", false)
        var percent = int(round(result.get("flashlight_battery", 0.0)))
        _set_status("Flashlight %s (%d%%)" % ["ready" if active else "stowed", percent])
    elif result.get("action", "") == "flashlight_batteries":
        var percent = int(round(result.get("flashlight_battery", 0.0)))
        _set_status("Batteries swapped (%d%%)" % percent)
    else:
        _set_status("Used %s (already full)" % display_name)
    _refresh_items()

