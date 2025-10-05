extends Control

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const WeatherSystem = preload("res://scripts/systems/WeatherSystem.gd")

const LBS_PER_KG: float = 2.2

@onready var game_manager: GameManager = _resolve_game_manager()
@onready var tired_bar: ProgressBar = $StatsBar/Metrics/TiredStat/TiredMeter/TiredBar
@onready var tired_value_label: Label = $StatsBar/Metrics/TiredStat/TiredMeter/TiredValue
@onready var daily_cal_value_label: Label = $StatsBar/Metrics/DailyCalStat/DailyCalValue
@onready var weight_value_label: Label = $StatsBar/Metrics/WeightStat/WeightRow/WeightValue
@onready var weight_unit_button: Button = $StatsBar/Metrics/WeightStat/WeightRow/WeightUnitButton
@onready var weight_status_label: Label = $StatsBar/Metrics/WeightStat/WeightStatus
@onready var weight_header_label: Label = $WeightHeader
@onready var weather_label: Label = $DayTimeHeader/WeatherLabel
@onready var day_label: Label = $DayTimeHeader/DayLabel
@onready var clock_label: Label = $DayTimeHeader/ClockLabel

var time_system: TimeSystem
var sleep_system: SleepSystem
var weather_system: WeatherSystem
var _weight_unit: String = "lbs"
var _latest_weight_lbs: float = 0.0
var _latest_weight_category: String = "average"
var _latest_weather_state: String = WeatherSystem.WEATHER_CLEAR if WeatherSystem else "clear"
var _latest_weather_hours: int = 0

func _ready():
    daily_cal_value_label.add_theme_color_override("font_color", Color.WHITE)
    tired_value_label.add_theme_color_override("font_color", Color.WHITE)
    day_label.add_theme_color_override("font_color", Color.WHITE)
    clock_label.add_theme_color_override("font_color", Color.WHITE)
    weight_value_label.add_theme_color_override("font_color", Color.WHITE)
    weight_status_label.add_theme_color_override("font_color", Color.WHITE)
    weight_header_label.add_theme_color_override("font_color", Color.WHITE)
    weather_label.add_theme_color_override("font_color", Color.WHITE)

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

    weather_system = game_manager.get_weather_system()
    if weather_system:
        game_manager.weather_changed.connect(_on_weather_changed)
        _on_weather_changed(weather_system.get_state(), weather_system.get_state(), weather_system.get_hours_remaining())
    else:
        weather_label.text = "Weather Offline"

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
    _latest_weight_lbs = weight_lbs
    _update_weight_value_label()
    _update_weight_header_label()

func _on_weight_unit_changed(new_unit: String):
    _weight_unit = new_unit
    weight_unit_button.text = new_unit.to_upper()
    _update_weight_value_label()
    _update_weight_header_label()

func _on_weight_category_changed(category: String):
    _latest_weight_category = category
    var title = _format_weight_category_title(category)
    var multiplier = sleep_system.get_time_multiplier() if sleep_system else 1.0
    weight_status_label.text = "%s (x%.1f)" % [title, multiplier]
    _update_weight_header_label()

func _on_weather_changed(new_state: String, _previous_state: String, hours_remaining: int):
    _latest_weather_state = new_state
    _latest_weather_hours = max(hours_remaining, 0)
    _update_weather_label()

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

func _format_weight_value(weight_lbs: float) -> String:
    var display_weight = _convert_weight_for_display(weight_lbs)
    return "%.1f" % display_weight

func _format_weight_range(category: String) -> String:
    var unit_suffix = _weight_unit.to_upper()
    match category:
        "malnourished":
            return "<=%s %s" % [_format_threshold(SleepSystem.MALNOURISHED_MAX_LBS), unit_suffix]
        "overweight":
            return ">=%s %s" % [_format_threshold(SleepSystem.OVERWEIGHT_MIN_LBS), unit_suffix]
        _:
            var lower = _format_threshold(SleepSystem.NORMAL_MIN_LBS)
            var upper = _format_threshold(SleepSystem.NORMAL_MAX_LBS)
            return "%s-%s %s" % [lower, upper, unit_suffix]

func _format_threshold(value_lbs: float) -> String:
    var display_value = _convert_weight_for_display(value_lbs)
    if _weight_unit == SleepSystem.WEIGHT_UNIT_LBS:
        return "%.0f" % round(display_value)
    return "%.1f" % display_value

func _convert_weight_for_display(value_lbs: float) -> float:
    return value_lbs if _weight_unit == SleepSystem.WEIGHT_UNIT_LBS else value_lbs / LBS_PER_KG

func _update_weight_value_label():
    var display_weight = _convert_weight_for_display(_latest_weight_lbs)
    weight_value_label.text = "%.1f" % display_weight

func _update_weight_header_label():
    if !is_instance_valid(weight_header_label):
        return
    var display_weight = _convert_weight_for_display(_latest_weight_lbs)
    var unit_suffix = _weight_unit.to_upper()
    var category_text = _format_weight_category_title(_latest_weight_category)
    weight_header_label.text = "%.1f %s [%s]" % [display_weight, unit_suffix, category_text]

func _update_weather_label():
    if !is_instance_valid(weather_label):
        return

    if weather_system == null:
        weather_label.text = "Weather Offline"
        return

    var title = weather_system.get_state_display_name_for(_latest_weather_state)
    var multiplier = weather_system.get_multiplier_for_state(_latest_weather_state)
    var detail_parts: PackedStringArray = []
    detail_parts.append("x%.2f" % multiplier)
    if weather_system.is_precipitating_state(_latest_weather_state) and _latest_weather_hours > 0:
        detail_parts.append("%dh left" % _latest_weather_hours)

    if detail_parts.size() > 0:
        weather_label.text = "%s (%s)" % [title, " | ".join(detail_parts)]
    else:
        weather_label.text = title

func _format_weight_category_title(category: String) -> String:
    match category:
        "malnourished":
            return "Malnourished"
        "overweight":
            return "Overweight"
        _:
            return "Healthy"
