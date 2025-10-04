extends Control

@onready var game_manager: GameManager = get_tree().get_current_scene().get_node("GameManager")
@onready var tired_bar: ProgressBar = $StatsBar/Metrics/TiredStat/TiredMeter/TiredBar
@onready var tired_value_label: Label = $StatsBar/Metrics/TiredStat/TiredMeter/TiredValue
@onready var daily_cal_value_label: Label = $StatsBar/Metrics/DailyCalStat/DailyCalValue

func _ready():
    daily_cal_value_label.add_theme_color_override("font_color", Color.WHITE)
    tired_value_label.add_theme_color_override("font_color", Color.WHITE)

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

func _on_sleep_percent_changed(value: float):
    tired_bar.value = value
    tired_value_label.text = "%d%%" % int(round(value))

func _on_daily_calories_used_changed(value: int):
    daily_cal_value_label.text = "%d" % value
