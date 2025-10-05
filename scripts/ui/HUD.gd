extends Control

@onready var game_manager: GameManager = get_tree().get_current_scene().get_node("GameManager")
@onready var time_value_label: Label = $StatsPanel/Rows/TimeRow/TimeValue
@onready var day_value_label: Label = $StatsPanel/Rows/DayRow/DayValue
@onready var tired_value_label: Label = $StatsPanel/Rows/TiredRow/TiredValue
@onready var daily_cal_value_label: Label = $StatsPanel/Rows/DailyCalRow/DailyCalValue

func _ready():
    var value_labels = [time_value_label, day_value_label, tired_value_label, daily_cal_value_label]
    for label in value_labels:
        label.add_theme_color_override("font_color", Color.WHITE)
        label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))

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

    var time_system = game_manager.get_time_system()
    if time_system:
        game_manager.time_changed.connect(_on_time_changed)
        game_manager.day_changed.connect(_on_day_changed)
        _on_time_changed(game_manager.get_formatted_time())
        _on_day_changed(game_manager.current_day)
    else:
        push_warning("TimeSystem not available on GameManager")

func _on_sleep_percent_changed(value: float):
    tired_value_label.text = "%d%%" % int(round(value))

func _on_daily_calories_used_changed(value: int):
    daily_cal_value_label.text = "%d" % value

func _on_time_changed(formatted_time: String):
    time_value_label.text = formatted_time

func _on_day_changed(day_index: int):
    day_value_label.text = str(day_index)
