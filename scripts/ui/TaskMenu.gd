extends Control

@export var max_sleep_hours: int = 12

const SLEEP_PERCENT_PER_HOUR: int = 10
const CALORIES_PER_SLEEP_HOUR: int = 100

var selected_hours: int = 0
var time_system: TimeSystem

var _cached_minutes_remaining: int = 0
var _menu_open: bool = false

@onready var game_manager: GameManager = _resolve_game_manager()
@onready var hours_value_label: Label = $Panel/VBox/HourSelector/HoursValue
@onready var summary_label: Label = $Panel/VBox/SummaryLabel

func _ready():
    set_process_unhandled_input(true)
    _close_menu()

    if game_manager:
        time_system = game_manager.get_time_system()
        if time_system:
            time_system.time_advanced.connect(_on_time_system_changed)
            time_system.day_rolled_over.connect(_on_time_system_changed)

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
    var max_hours_today = min(max_sleep_hours, int(floor(_cached_minutes_remaining / 60.0)))
    if selected_hours > max_hours_today:
        selected_hours = max(max_hours_today, 0)
    hours_value_label.text = str(selected_hours)
    var minutes_remaining = _get_minutes_left_today()
    var max_hours_today = min(max_sleep_hours, int(floor(minutes_remaining / 60.0)))
    if selected_hours > max_hours_today:
        selected_hours = max(max_hours_today, 0)
        hours_value_label.text = str(selected_hours)

    if selected_hours == 0:
        var time_hint = " (Time left: %s)" % _format_duration(minutes_remaining)
        summary_label.text = "Each hour: +10% rest / -100 cal%s" % time_hint
        return

    var rest_gain = selected_hours * SLEEP_PERCENT_PER_HOUR
    var calories = selected_hours * CALORIES_PER_SLEEP_HOUR
    var preview_minutes = selected_hours * 60
    var end_text = ""
    if time_system and preview_minutes <= minutes_remaining and minutes_remaining > 0:
        end_text = " (Ends %s)" % time_system.get_formatted_time_after(preview_minutes)
    summary_label.text = "%d hr -> +%d%% rest / -%d cal%s" % [selected_hours, rest_gain, calories, end_text]

func _on_decrease_button_pressed():
    selected_hours = max(selected_hours - 1, 0)
    _refresh_display()

func _on_increase_button_pressed():
    var hours_available = min(max_sleep_hours, int(floor(_get_minutes_left_today() / 60.0)))
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
            summary_label.text = "Not enough time (left: %s)" % _format_duration(minutes_left)
            print("⚠️ Sleep rejected: %s" % result)

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
