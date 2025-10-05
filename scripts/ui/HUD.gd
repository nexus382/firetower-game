extends Control

const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")

@onready var game_manager: GameManager = _resolve_game_manager()
@onready var tired_bar: ProgressBar = $StatsBar/Metrics/TiredStat/TiredMeter/TiredBar
@onready var tired_value_label: Label = $StatsBar/Metrics/TiredStat/TiredMeter/TiredValue
@onready var daily_cal_value_label: Label = $StatsBar/Metrics/DailyCalStat/DailyCalValue
@onready var day_label: Label = $DayTimeHeader/DayLabel
@onready var clock_label: Label = $DayTimeHeader/ClockLabel

var time_system: TimeSystem

func _ready():
    daily_cal_value_label.add_theme_color_override("font_color", Color.WHITE)
    tired_value_label.add_theme_color_override("font_color", Color.WHITE)
    day_label.add_theme_color_override("font_color", Color.WHITE)
    clock_label.add_theme_color_override("font_color", Color.WHITE)

    if game_manager == null:
        push_warning("GameManager not found for HUD")
        return

    var sleep_system = game_manager.get_sleep_system()
    if sleep_system:
        sleep_system.sleep_percent_changed.connect(_on_sleep_percent_changed)
        sleep_system.daily_calories_used_changed.connect(_on_daily_calories_used_changed)
        _on_sleep_percent_changed(sleep_system.get_sleep_percent())
        _on_daily_calories_used_changed(sleep_system.get_daily_calories_used())
    else:
        push_warning("SleepSystem not available on GameManager")

    time_system = game_manager.get_time_system()
    if time_system:
        time_system.time_advanced.connect(_on_time_advanced)
        time_system.day_rolled_over.connect(_on_day_rolled_over)
        _update_clock_label()
    else:
        push_warning("TimeSystem not available on GameManager")

    game_manager.day_changed.connect(_on_day_changed)
    _update_day_label(game_manager.current_day)

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
