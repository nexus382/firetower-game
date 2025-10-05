extends Control

@export var max_sleep_hours: int = 12

const SLEEP_PERCENT_PER_HOUR: int = 10
const CALORIES_PER_SLEEP_HOUR: int = 100

var selected_hours: int = 0

@onready var game_manager: GameManager = get_tree().get_current_scene().get_node("GameManager")
@onready var hours_value_label: Label = $Panel/VBox/HourSelector/HoursValue
@onready var summary_label: Label = $Panel/VBox/SummaryLabel

func _ready():
    visible = false
    set_process_unhandled_input(true)
    summary_label.add_theme_color_override("font_color", Color.WHITE)
    summary_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
    _refresh_display()

func _unhandled_input(event):
    if event.is_action_pressed("action_menu") and !event.is_echo():
        visible = !visible
        if visible:
            grab_focus()
        get_viewport().set_input_as_handled()

func _refresh_display():
    hours_value_label.text = str(selected_hours)
    if selected_hours == 0:
        summary_label.text = "Each hour: +10% rest / -100 cal"
    else:
        var rest_gain = selected_hours * SLEEP_PERCENT_PER_HOUR
        var calories = selected_hours * CALORIES_PER_SLEEP_HOUR
        var preview := _get_preview_for_hours(selected_hours)
        var duration_text := _format_minutes(preview.get("effective_minutes", selected_hours * 60))
        var finish_time := preview.get("result_time", "--:--")
        summary_label.text = "%d hr -> +%d%% rest / -%d cal\nTakes %s • Ends %s" % [
            selected_hours,
            rest_gain,
            calories,
            duration_text,
            finish_time
        ]

func _on_decrease_button_pressed():
    selected_hours = max(selected_hours - 1, 0)
    _refresh_display()

func _on_increase_button_pressed():
    selected_hours = min(selected_hours + 1, max_sleep_hours)
    _refresh_display()

func _on_sleep_button_pressed():
    if game_manager and selected_hours > 0:
        var result = game_manager.schedule_sleep(selected_hours)
        if result.has("new_percent"):
            print("✅ Sleep applied: %s" % result)
    selected_hours = 0
    _refresh_display()
    visible = false

func _get_preview_for_hours(hours: int) -> Dictionary:
    if not game_manager:
        return {}
    return game_manager.get_effective_minutes_for_hours(hours)

func _format_minutes(total_minutes: int) -> String:
    total_minutes = max(total_minutes, 0)
    var hours = total_minutes / 60
    var minutes = total_minutes % 60
    if hours > 0:
        return "%dh %02dm" % [hours, minutes]
    return "%02dm" % minutes
