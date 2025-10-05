extends Control

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const BodyWeightSystem = preload("res://scripts/systems/BodyWeightSystem.gd")

@onready var game_manager: GameManager = _resolve_game_manager()
@onready var tired_bar: ProgressBar = $StatsBar/Metrics/TiredStat/TiredMeter/TiredBar
@onready var tired_value_label: Label = $StatsBar/Metrics/TiredStat/TiredMeter/TiredValue
@onready var daily_cal_value_label: Label = $StatsBar/Metrics/DailyCalStat/DailyCalValue
@onready var weight_value_label: Label = $StatsBar/Metrics/WeightStat/WeightValue
@onready var day_label: Label = $DayTimeHeader/DayLabel
@onready var clock_label: Label = $DayTimeHeader/ClockLabel

var sleep_system: SleepSystem
var time_system: TimeSystem
var body_weight_system: BodyWeightSystem
var _systems_rebind_pending: bool = false

func _ready():
    daily_cal_value_label.add_theme_color_override("font_color", Color.WHITE)
    tired_value_label.add_theme_color_override("font_color", Color.WHITE)
    weight_value_label.add_theme_color_override("font_color", Color.WHITE)
    day_label.add_theme_color_override("font_color", Color.WHITE)
    clock_label.add_theme_color_override("font_color", Color.WHITE)

    if game_manager == null:
        push_warning("GameManager not found for HUD")
        return

    _bind_game_systems()

    if game_manager and not game_manager.systems_ready.is_connected(_on_game_manager_systems_ready):
        game_manager.systems_ready.connect(_on_game_manager_systems_ready)

    if not _has_all_systems():
        _schedule_system_rebind()

    if not game_manager.day_changed.is_connected(_on_day_changed):
        game_manager.day_changed.connect(_on_day_changed)
    _update_day_label(game_manager.current_day)

func _bind_game_systems():
    _bind_sleep_system(game_manager.get_sleep_system())
    _bind_time_system(game_manager.get_time_system())
    _bind_body_weight_system(game_manager.get_body_weight_system())

func _bind_sleep_system(new_sleep_system: SleepSystem):
    if new_sleep_system == null:
        return

    if sleep_system == new_sleep_system and sleep_system != null:
        return

    if sleep_system and sleep_system.sleep_percent_changed.is_connected(_on_sleep_percent_changed):
        sleep_system.sleep_percent_changed.disconnect(_on_sleep_percent_changed)
    if sleep_system and sleep_system.daily_calories_used_changed.is_connected(_on_daily_calories_used_changed):
        sleep_system.daily_calories_used_changed.disconnect(_on_daily_calories_used_changed)

    sleep_system = new_sleep_system
    sleep_system.sleep_percent_changed.connect(_on_sleep_percent_changed)
    sleep_system.daily_calories_used_changed.connect(_on_daily_calories_used_changed)
    _on_sleep_percent_changed(sleep_system.get_sleep_percent())
    _on_daily_calories_used_changed(sleep_system.get_daily_calories_used())

func _bind_time_system(new_time_system: TimeSystem):
    if new_time_system == null:
        return

    if time_system == new_time_system and time_system != null:
        _update_clock_label()
        return

    if time_system and time_system.time_advanced.is_connected(_on_time_advanced):
        time_system.time_advanced.disconnect(_on_time_advanced)
    if time_system and time_system.day_rolled_over.is_connected(_on_day_rolled_over):
        time_system.day_rolled_over.disconnect(_on_day_rolled_over)

    time_system = new_time_system
    time_system.time_advanced.connect(_on_time_advanced)
    time_system.day_rolled_over.connect(_on_day_rolled_over)
    _update_clock_label()

func _bind_body_weight_system(new_body_weight_system: BodyWeightSystem):
    if new_body_weight_system == null:
        return

    if body_weight_system == new_body_weight_system and body_weight_system != null:
        _on_body_weight_changed(body_weight_system.get_weight_display_string())
        return

    var previous_system = body_weight_system
    if previous_system and previous_system.body_weight_changed.is_connected(_on_body_weight_changed):
        previous_system.body_weight_changed.disconnect(_on_body_weight_changed)

    body_weight_system = new_body_weight_system

    if body_weight_system and not body_weight_system.body_weight_changed.is_connected(_on_body_weight_changed):
        body_weight_system.body_weight_changed.connect(_on_body_weight_changed)

    _on_body_weight_changed(body_weight_system.get_weight_display_string())

func _has_all_systems() -> bool:
    return sleep_system != null and time_system != null and body_weight_system != null

func _on_game_manager_systems_ready():
    _bind_game_systems()
    if not _has_all_systems():
        _schedule_system_rebind()

func _on_sleep_percent_changed(value: float):
    tired_bar.value = value
    tired_value_label.text = "%d%%" % int(round(value))

func _on_daily_calories_used_changed(value: int):
    daily_cal_value_label.text = "%d" % value

func _on_time_advanced(_minutes: int, _rolled_over: bool):
    _update_clock_label()

func _on_day_rolled_over():
    _update_clock_label()

func _on_day_changed(new_day: int):
    _update_day_label(new_day)

func _update_clock_label():
    if time_system:
        clock_label.text = time_system.get_formatted_time()

func _update_day_label(day_index: int):
    day_label.text = "Day %d" % day_index

func _on_body_weight_changed(display_weight: String):
    weight_value_label.text = display_weight

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

func _schedule_system_rebind():
    if _systems_rebind_pending or game_manager == null:
        return

    _systems_rebind_pending = true
    call_deferred("_deferred_bind_systems")

func _deferred_bind_systems():
    _systems_rebind_pending = false
    if game_manager == null:
        return

    _bind_game_systems()

    if not _has_all_systems():
        _schedule_system_rebind()
