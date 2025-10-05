extends Control

@export var max_sleep_hours: int = 12

const SLEEP_PERCENT_PER_HOUR: int = 10
const CALORIES_PER_SLEEP_HOUR: int = 100
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")

var selected_hours: int = 0
var time_system: TimeSystem
var _time_bound: bool = false
var _time_rebind_pending: bool = false

var _cached_minutes_remaining: int = 0
var _menu_open: bool = false

@onready var game_manager: GameManager = _resolve_game_manager()
@onready var hours_value_label: Label = $Panel/VBox/HourSelector/HoursValue
@onready var summary_label: Label = $Panel/VBox/SummaryLabel

func _ready():
    set_process_unhandled_input(true)
    _close_menu()
    summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

    if game_manager == null:
        push_warning("GameManager not found for TaskMenu")
        _refresh_display()
        return

    _bind_time_system(game_manager.get_time_system())

    if time_system == null:
        _schedule_time_rebind()

    if not _time_bound and not game_manager.systems_ready.is_connected(_on_game_manager_systems_ready):
        game_manager.systems_ready.connect(_on_game_manager_systems_ready)

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
    var minutes_remaining = _cached_minutes_remaining
    var max_hours_today = min(max_sleep_hours, int(floor(minutes_remaining / 60.0)))

    if selected_hours > max_hours_today:
        selected_hours = max(max_hours_today, 0)

    hours_value_label.text = str(selected_hours)

    if selected_hours == 0:
        var info_lines_zero: Array[String] = []
        info_lines_zero.append("Each hour: +%d%% rest / -%d cal" % [SLEEP_PERCENT_PER_HOUR, CALORIES_PER_SLEEP_HOUR])
        info_lines_zero.append("Time left: %s" % _format_duration(minutes_remaining))
        info_lines_zero.append("Range today: 0-%d hr" % max_hours_today)
        summary_label.text = "\n".join(info_lines_zero)
        return

    var rest_gain = selected_hours * SLEEP_PERCENT_PER_HOUR
    var calories = selected_hours * CALORIES_PER_SLEEP_HOUR
    var preview_minutes = selected_hours * 60
    var info_lines: Array[String] = []
    info_lines.append("Range today: 0-%d hr" % max_hours_today)
    info_lines.append("%d hr planned" % selected_hours)
    info_lines.append("Rest: +%d%%" % rest_gain)
    info_lines.append("Calories: -%d" % calories)

    if time_system and preview_minutes <= minutes_remaining and minutes_remaining > 0:
        info_lines.append("Ends: %s" % time_system.get_formatted_time_after(preview_minutes))

    summary_label.text = "\n".join(info_lines)

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

func _bind_time_system(new_time_system: TimeSystem):
    if new_time_system == null:
        return

    if time_system == new_time_system and time_system != null:
        _refresh_display()
        return

    if time_system and time_system.time_advanced.is_connected(_on_time_system_changed):
        time_system.time_advanced.disconnect(_on_time_system_changed)
    if time_system and time_system.day_rolled_over.is_connected(_on_time_system_changed):
        time_system.day_rolled_over.disconnect(_on_time_system_changed)

    time_system = new_time_system
    time_system.time_advanced.connect(_on_time_system_changed)
    time_system.day_rolled_over.connect(_on_time_system_changed)
    _time_bound = true
    _refresh_display()

func _on_game_manager_systems_ready():
    if game_manager:
        _bind_time_system(game_manager.get_time_system())
        if time_system == null:
            _schedule_time_rebind()

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

func _schedule_time_rebind():
    if _time_rebind_pending or game_manager == null:
        return

    _time_rebind_pending = true
    call_deferred("_deferred_bind_time_system")

func _deferred_bind_time_system():
    _time_rebind_pending = false
    if game_manager == null:
        return

    _bind_time_system(game_manager.get_time_system())

    if time_system == null:
        _schedule_time_rebind()
