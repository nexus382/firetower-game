extends Control

const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")

@onready var game_manager: GameManager = _resolve_game_manager()
@onready var tired_bar: ProgressBar = $StatsBar/Metrics/TiredStat/TiredMeter/TiredBar
@onready var tired_value_label: Label = $StatsBar/Metrics/TiredStat/TiredMeter/TiredValue
@onready var daily_cal_value_label: Label = $StatsBar/Metrics/DailyCalStat/DailyCalValue
@onready var weight_value_label: Label = $StatsBar/Metrics/WeightStat/WeightRow/WeightValue
@onready var weight_unit_button: Button = $StatsBar/Metrics/WeightStat/WeightRow/WeightUnitButton
@onready var weight_status_label: Label = $StatsBar/Metrics/WeightStat/WeightStatus
@onready var day_label: Label = $DayTimeHeader/DayLabel
@onready var clock_label: Label = $DayTimeHeader/ClockLabel

var time_system: TimeSystem
var sleep_system: SleepSystem
var _weight_unit: String = "lbs"

func _ready():
    daily_cal_value_label.add_theme_color_override("font_color", Color.WHITE)
    tired_value_label.add_theme_color_override("font_color", Color.WHITE)
    day_label.add_theme_color_override("font_color", Color.WHITE)
    clock_label.add_theme_color_override("font_color", Color.WHITE)
    weight_value_label.add_theme_color_override("font_color", Color.WHITE)
    weight_status_label.add_theme_color_override("font_color", Color.WHITE)

    if game_manager == null:
        push_warning("GameManager not found for HUD")
        return

    sleep_system = game_manager.get_sleep_system()
    if sleep_system:
        sleep_system.sleep_percent_changed.connect(_on_sleep_percent_changed)
        sleep_system.daily_calories_used_changed.connect(_on_daily_calories_used_changed)
        sleep_system.weight_changed.connect(_on_weight_changed)
        sleep_system.weight_unit_changed.connect(_on_weight_unit_changed)
        sleep_system.weight_category_changed.connect(_on_weight_category_changed)
        _on_sleep_percent_changed(sleep_system.get_sleep_percent())
        _on_daily_calories_used_changed(sleep_system.get_daily_calories_used())
        _on_weight_unit_changed(sleep_system.get_weight_unit())
        _on_weight_changed(sleep_system.get_player_weight_lbs())
        _on_weight_category_changed(sleep_system.get_weight_category())
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

func _on_daily_calories_used_changed(value: float):
    daily_cal_value_label.text = "%d" % int(round(value))

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

func _on_weight_changed(weight_lbs: float):
    var display_weight = weight_lbs
    if _weight_unit == "kg":
        display_weight = weight_lbs / 2.2
    weight_value_label.text = "%.1f" % display_weight

func _on_weight_unit_changed(new_unit: String):
    _weight_unit = new_unit
    weight_unit_button.text = new_unit.to_upper()
    if sleep_system:
        _on_weight_changed(sleep_system.get_player_weight_lbs())

func _on_weight_category_changed(category: String):
    var title = category.capitalize()
    var multiplier = sleep_system.get_time_multiplier() if sleep_system else 1.0
    weight_status_label.text = "%s (x%.1f)" % [title, multiplier]

func _on_weight_unit_button_pressed():
    if sleep_system:
        sleep_system.toggle_weight_unit()

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
