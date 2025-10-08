extends Control
class_name InventoryPanel

const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var items_scroll: ScrollContainer = $Panel/Margin/VBox/ItemScroll
@onready var items_container: VBoxContainer = $Panel/Margin/VBox/ItemScroll/Items
@onready var placeholder_label: Label = $Panel/Margin/VBox/ItemScroll/Items/Placeholder
@onready var close_button: Button = $Panel/Margin/VBox/ButtonRow/CloseButton

var game_manager: GameManager
var inventory_system: InventorySystem

func _ready():
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
    if !visible:
        visible = true
        _refresh_items()
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
        var row = HBoxContainer.new()
        row.theme_override_constants["separation"] = 8
        var name_label = Label.new()
        name_label.text = entry.get("display_name", entry.get("item_id", "Item"))
        name_label.add_theme_color_override("font_color", Color.WHITE)
        row.add_child(name_label)
        var qty_label = Label.new()
        qty_label.text = "x%d" % int(entry.get("quantity", 0))
        qty_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
        row.add_child(qty_label)
        items_container.add_child(row)

func _show_placeholder(text: String):
    if !is_instance_valid(placeholder_label):
        return
    placeholder_label.text = text
    placeholder_label.show()

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
