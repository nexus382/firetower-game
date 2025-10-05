extends Control

@export var max_sleep_hours: int = 12

const SLEEP_PERCENT_PER_HOUR: int = 10
const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")

var selected_hours: int = 0
var time_system: TimeSystem

var _cached_minutes_remaining: int = 0
var _menu_open: bool = false
var inventory_system: InventorySystem

@onready var game_manager: GameManager = _resolve_game_manager()
@onready var hours_value_label: Label = $Panel/VBox/HourSelector/HoursValue
@onready var summary_label: Label = $Panel/VBox/SummaryLabel
@onready var forging_result_label: Label = $Panel/VBox/ForgingResult

func _ready():
    set_process_unhandled_input(true)
    _close_menu()

    if game_manager:
        time_system = game_manager.get_time_system()
        inventory_system = game_manager.get_inventory_system()
        if time_system:
            time_system.time_advanced.connect(_on_time_system_changed)
            time_system.day_rolled_over.connect(_on_time_system_changed)
        if inventory_system:
            forging_result_label.text = _format_forging_ready(inventory_system.get_total_food_units())
        else:
            forging_result_label.text = "Forging offline"
    else:
        forging_result_label.text = "Forging unavailable"

    _refresh_display()

func _input(event):
    if event.is_action_pressed("action_menu") and !event.is_echo():
        if visible:
            _close_menu()
        else:
            _open_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("ui_cancel") and visible and !event.is_echo():
        _close_menu()
        get_viewport().set_input_as_handled()

func _refresh_display():
    _cached_minutes_remaining = _get_minutes_left_today()
    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var max_hours_today = min(max_sleep_hours, int(floor(_cached_minutes_remaining / (60.0 * multiplier))))
    if selected_hours > max_hours_today:
        selected_hours = max(max_hours_today, 0)
    hours_value_label.text = str(selected_hours)
    var minutes_remaining = _get_minutes_left_today()
    max_hours_today = min(max_sleep_hours, int(floor(minutes_remaining / (60.0 * multiplier))))
    if selected_hours > max_hours_today:
        selected_hours = max(max_hours_today, 0)
        hours_value_label.text = str(selected_hours)

    if selected_hours == 0:
        var lines: PackedStringArray = []
        lines.append("Each hour: +10%% rest / -%d cal" % SleepSystem.CALORIES_PER_SLEEP_HOUR)
        lines.append("Forging: 25%% 🍄 / 25%% 🍓 / 25%% 🌰 / 20%% 🐛")
        lines.append("Time x%.1f | Left %s" % [multiplier, _format_duration(minutes_remaining)])
        summary_label.text = "\n".join(lines)
        return

    var rest_gain = selected_hours * SLEEP_PERCENT_PER_HOUR
    var calories = selected_hours * SleepSystem.CALORIES_PER_SLEEP_HOUR
    var preview_minutes = int(ceil(selected_hours * 60.0 * multiplier))
    var detail_parts: PackedStringArray = []
    detail_parts.append("Takes %s" % _format_duration(preview_minutes))
    if time_system and preview_minutes <= minutes_remaining and minutes_remaining > 0:
        detail_parts.append("Ends %s" % time_system.get_formatted_time_after(preview_minutes))
    summary_label.text = "%d hr -> +%d%% rest / -%d cal\n%s" % [selected_hours, rest_gain, calories, " | ".join(detail_parts)]

func _on_decrease_button_pressed():
    selected_hours = max(selected_hours - 1, 0)
    _refresh_display()

func _on_increase_button_pressed():
    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var hours_available = min(max_sleep_hours, int(floor(_get_minutes_left_today() / (60.0 * multiplier))))
    if selected_hours >= hours_available:
        print("⚠️ Cannot schedule beyond remaining daily time")
        return
    selected_hours = min(selected_hours + 1, hours_available)
    _refresh_display()

func _on_sleep_button_pressed():
    if game_manager and selected_hours > 0:
        var result = game_manager.schedule_sleep(selected_hours)
        if result.get("accepted", false):
            print("✅ Sleep applied: %s" % result)
            selected_hours = 0
            _refresh_display()
            _close_menu()
        else:
            var minutes_left = result.get("minutes_available", _get_minutes_left_today())
            var fallback_multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
            var rejection_multiplier = result.get("time_multiplier", fallback_multiplier)
            summary_label.text = "Not enough time (x%.1f, left: %s)" % [rejection_multiplier, _format_duration(minutes_left)]
            print("⚠️ Sleep rejected: %s" % result)

func _on_forging_button_pressed():
    if game_manager == null:
        forging_result_label.text = "Forging unavailable"
        return

    var result = game_manager.perform_forging()
    forging_result_label.text = _format_forging_result(result)

func _format_forging_ready(total_food: float) -> String:
    return "Forging ready (Food %.1f)" % total_food

func _format_forging_result(result: Dictionary) -> String:
    if result.get("success", false):
        var name = result.get("display_name", "Find")
        var food = result.get("food_gained", 0.0)
        var total = result.get("total_food_units", 0.0)
        return "%s +%.1f food (Total %.1f)" % [name, food, total]

    var reason = result.get("reason", "")
    match reason:
        "inventory_unavailable":
            return "Forging offline"
        "nothing_found":
            return "Found nothing (%.0f%%)" % (result.get("chance_roll", 0.0) * 100.0)
        _:
            return "Forging failed"

func _get_minutes_left_today() -> int:
    if time_system:
        return time_system.get_minutes_until_daybreak()
    return max_sleep_hours * 60

func _on_time_system_changed(_a = null, _b = null):
    _refresh_display()

func _format_duration(minutes: int) -> String:
    minutes = max(minutes, 0)
    var hours = minutes / 60
    var mins = minutes % 60
    if hours > 0 and mins > 0:
        return "%dh %02dm" % [hours, mins]
    elif hours > 0:
        return "%dh" % hours
    else:
        return "%dm" % mins

func _open_menu():
    if _menu_open:
        return
    _menu_open = true
    visible = true

func _close_menu():
    if !_menu_open and !visible:
        return
    _menu_open = false
    visible = false

func _resolve_game_manager() -> GameManager:
    var tree = get_tree()
    if tree == null:
        push_warning("SceneTree unavailable, cannot resolve GameManager")
        return null

    var root = tree.get_root()
    if root == null:
        push_warning("Root node unavailable, cannot resolve GameManager")
        return null

    var candidate: Node = root.get_node_or_null("Main/GameManager")
    if candidate == null:
        var group_matches = tree.get_nodes_in_group("game_manager") if tree.has_group("game_manager") else []
        if group_matches.size() > 0:
            candidate = group_matches[0]

    if candidate is GameManager:
        return candidate

    if candidate:
        push_warning("GameManager node found but type mismatch: %s" % candidate.name)
    else:
        push_warning("GameManager node not found in scene tree")

    return null
