# WoodStovePanel.gd overview:
# - Purpose: present stove status, manage wood loading, and trigger fire-start attempts with available tools.
# - Sections: onready caches widgets, helpers resolve dependencies and rebuild buttons, public methods open/close panel and relay actions.
extends Control
class_name WoodStovePanel

const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const PANEL_GROUP := "wood_stove_panel"
const KINDLING_ID := "kindling"
const FIRE_STARTING_BOW_ID := "fire_starting_bow"
const FLINT_AND_STEEL_ID := "flint_and_steel"

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var fire_state_value: Label = $Panel/Margin/VBox/StateGrid/FireStateValue
@onready var wood_value: Label = $Panel/Margin/VBox/StateGrid/WoodValue
@onready var burn_value: Label = $Panel/Margin/VBox/StateGrid/BurnValue
@onready var kindling_value: Label = $Panel/Margin/VBox/StateGrid/KindlingValue
@onready var add_button: Button = $Panel/Margin/VBox/Controls/AddRow/AddWoodButton
@onready var capacity_label: Label = $Panel/Margin/VBox/Controls/AddRow/CapacityLabel
@onready var tool_header: Label = $Panel/Margin/VBox/Controls/ToolHeader
@onready var tool_container: HBoxContainer = $Panel/Margin/VBox/Controls/ToolContainer
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var close_button: Button = $Panel/Margin/VBox/ButtonRow/CloseButton

var game_manager: GameManager
var inventory_system: InventorySystem
var time_system: TimeSystem
var _tool_buttons: Dictionary = {}
var _last_state: Dictionary = {}

func _ready():
    visible = false
    set_process_unhandled_input(true)
    add_to_group(PANEL_GROUP)
    if add_button:
        add_button.pressed.connect(_on_add_wood_pressed)
    if close_button:
        close_button.pressed.connect(close_panel)
    _apply_theme_overrides()
    _resolve_dependencies()
    _refresh_state()

func _resolve_dependencies():
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
        time_system = game_manager.get_time_system()
        if inventory_system:
            inventory_system.item_added.connect(_on_inventory_changed)
            inventory_system.item_consumed.connect(_on_inventory_changed)
        if game_manager:
            game_manager.wood_stove_state_changed.connect(_on_stove_state_changed)
        if time_system:
            time_system.time_advanced.connect(_on_time_advanced)
    else:
        push_warning("GameManager not found for WoodStovePanel")

func open_panel():
    if !visible:
        visible = true
        status_label.text = ""
        _refresh_state()
    if add_button and !add_button.disabled:
        add_button.focus_mode = Control.FOCUS_ALL
        add_button.grab_focus()
    elif !_tool_buttons.is_empty():
        for button in _tool_buttons.values():
            if button is Button and !button.disabled:
                button.grab_focus()
                break

func close_panel():
    visible = false

func _unhandled_input(event):
    if !visible:
        return
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
        close_panel()
        get_viewport().set_input_as_handled()

func _apply_theme_overrides():
    if panel:
        var box := StyleBoxFlat.new()
        box.bg_color = Color(0.08, 0.08, 0.08, 1.0)
        box.set_corner_radius_all(8)
        box.set_border_width_all(2)
        box.border_color = Color(0.3, 0.3, 0.3, 1.0)
        panel.add_theme_stylebox_override("panel", box)
    if title_label:
        title_label.text = "Wood Stove"
        title_label.add_theme_color_override("font_color", Color.WHITE)
    if status_label:
        status_label.add_theme_color_override("font_color", Color.WHITE)
        status_label.text = ""

func _refresh_state():
    var state: Dictionary = {}
    if game_manager:
        state = game_manager.get_wood_stove_state()
    _last_state = state.duplicate(true)

    var lit = state.get("lit", false)
    var logs = int(state.get("logs_loaded", 0))
    var capacity = int(state.get("capacity_remaining", 0))
    var burn_minutes = float(state.get("burn_minutes_remaining", 0.0))
    var minutes_per_log = int(state.get("minutes_per_log", 240))

    if fire_state_value:
        if lit:
            fire_state_value.text = "Lit"
        elif logs > 0:
            fire_state_value.text = "Ready"
        else:
            fire_state_value.text = "Out"
    if wood_value:
        wood_value.text = "%d loaded" % max(logs, 0)
    if burn_value:
        burn_value.text = _format_burn_time(burn_minutes)
    var kindling_count = 0
    if inventory_system:
        kindling_count = inventory_system.get_item_count(KINDLING_ID)
    if kindling_value:
        kindling_value.text = "%d in pack" % max(kindling_count, 0)

    if capacity_label:
        capacity_label.text = "Capacity: %d free" % max(capacity, 0)
    if add_button:
        var wood_stock = inventory_system.get_item_count("wood") if inventory_system else 0
        add_button.disabled = capacity <= 0 or wood_stock <= 0
        var log_hours = float(minutes_per_log) / 60.0
        add_button.text = "Add Wood (+%dh)" % int(round(log_hours)) if log_hours >= 1.0 else "Add Wood"

    _rebuild_tool_buttons(lit, logs > 0, kindling_count)

func _rebuild_tool_buttons(is_lit: bool, has_fuel: bool, kindling_count: int):
    if tool_container == null:
        return
    for child in tool_container.get_children():
        child.queue_free()
    _tool_buttons.clear()

    if tool_header:
        tool_header.text = "Fire Starting Tools"

    if inventory_system == null:
        var offline = Label.new()
        offline.text = "Inventory offline"
        offline.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
        tool_container.add_child(offline)
        return

    var options: Array = []
    var bow_stock = inventory_system.get_item_count(FIRE_STARTING_BOW_ID)
    if bow_stock > 0:
        options.append({
            "id": FIRE_STARTING_BOW_ID,
            "label": "Bow Drill (75% chance)",
            "stock": bow_stock
        })
    var flint_stock = inventory_system.get_item_count(FLINT_AND_STEEL_ID)
    if flint_stock > 0:
        options.append({
            "id": FLINT_AND_STEEL_ID,
            "label": "Flint & Steel (90% | %d uses)" % flint_stock,
            "stock": flint_stock
        })

    if options.is_empty():
        var placeholder = Label.new()
        placeholder.text = "No fire tools available"
        placeholder.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
        tool_container.add_child(placeholder)
        return

    for option in options:
        var button = Button.new()
        button.text = String(option.get("label", "Fire Tool"))
        button.focus_mode = Control.FOCUS_ALL
        button.add_theme_color_override("font_color", Color.WHITE)
        var disabled = is_lit or !has_fuel or kindling_count <= 0
        button.disabled = disabled
        var id = String(option.get("id", ""))
        button.pressed.connect(Callable(self, "_on_fire_tool_pressed").bind(id))
        tool_container.add_child(button)
        _tool_buttons[id] = button

func _format_burn_time(minutes: float) -> String:
    var total_minutes = int(round(max(minutes, 0.0)))
    var hours = total_minutes / 60
    var mins = total_minutes % 60
    if hours > 0 and mins > 0:
        return "%dh %dm" % [hours, mins]
    if hours > 0:
        return "%dh" % hours
    return "%dm" % mins

func _on_add_wood_pressed():
    if game_manager == null:
        status_label.text = "Stove offline"
        return
    var result = game_manager.add_wood_to_stove(1)
    if !result.get("success", false):
        var reason = String(result.get("reason", "failed"))
        match reason:
            "systems_unavailable":
                status_label.text = "Stove offline"
            "no_capacity":
                status_label.text = "Firebox is full"
            "no_wood":
                status_label.text = "Need wood in pack"
            "consume_failed":
                status_label.text = "Wood spend failed"
            _:
                status_label.text = "Add wood failed"
    else:
        var added = int(result.get("added", 0))
        status_label.text = "Loaded %d wood" % max(added, 0)
    _refresh_state()

func _on_fire_tool_pressed(tool_id: String):
    if game_manager == null:
        status_label.text = "Stove offline"
        return
    var result = game_manager.light_wood_stove(tool_id)
    if !result.get("success", false):
        var reason = String(result.get("reason", "failed"))
        match reason:
            "no_kindling":
                status_label.text = "Need kindling"
            "no_fuel":
                status_label.text = "Load wood first"
            "already_lit":
                status_label.text = "Fire already lit"
            "failed_roll":
                var chance = int(round(result.get("chance", 0.0) * 100.0))
                status_label.text = "Spark missed (%d%% chance)" % clamp(chance, 0, 100)
            "flint_consume_failed":
                status_label.text = "Flint and steel wore out"
            "kindling_consume_failed":
                status_label.text = "Kindling missing"
            "missing_tool":
                status_label.text = "Tool missing"
            "unsupported_tool":
                status_label.text = "Tool unavailable"
            "systems_unavailable":
                status_label.text = "Stove offline"
            _:
                status_label.text = "Lighting failed"
    else:
        var state: Dictionary = result.get("state", {})
        var burn_minutes = float(state.get("burn_minutes_remaining", 0.0))
        status_label.text = "Fire lit (%s remaining)" % _format_burn_time(burn_minutes)
    _refresh_state()

func _on_inventory_changed(_item_id: String, _delta: int, _food: float, _total: float):
    if visible:
        _refresh_state()

func _on_stove_state_changed(_state: Dictionary):
    if visible:
        _refresh_state()

func _on_time_advanced(_minutes: int, _rolled: bool):
    if visible:
        _refresh_state()
