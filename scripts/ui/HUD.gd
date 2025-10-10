# HUD.gd overview:
# - Purpose: keep the survival overlay synchronized with simulation systems and expose player toggles.
# - Sections: preloads cache systems, onready grabs widgets, ready hook wires signals, handlers update each stat line.
extends Control

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const WeatherSystem = preload("res://scripts/systems/WeatherSystem.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const TowerHealthSystem = preload("res://scripts/systems/TowerHealthSystem.gd")
const ZombieSystem = preload("res://scripts/systems/ZombieSystem.gd")
const PlayerHealthSystem = preload("res://scripts/systems/PlayerHealthSystem.gd")
const WarmthSystem = preload("res://scripts/systems/WarmthSystem.gd")

const LBS_PER_KG: float = 2.2

# Cached node references so we only traverse the tree once on startup.
@onready var game_manager: GameManager = _resolve_game_manager()
@onready var tired_bar: ProgressBar = %TiredBar
@onready var tired_value_label: Label = %TiredValue
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_value_label: Label = %HealthValue
@onready var warmth_label: Label = %WarmthLabel
@onready var warmth_bar: ProgressBar = %WarmthBar
@onready var warmth_value_label: Label = %WarmthValue
@onready var daily_cal_value_label: Label = %DailyCalValue
@onready var weight_value_label: Label = %WeightValue
@onready var weight_unit_button: Button = %WeightUnitButton
@onready var weight_status_label: Label = %WeightStatus
@onready var weight_header_label: Label = %WeightHeader
@onready var weather_label: Label = %WeatherLabel
@onready var day_label: Label = %DayLabel
@onready var clock_label: Label = %ClockLabel
@onready var recon_alert_label: Label = %ReconAlertLabel
@onready var food_counter_label: Label = %FoodCounter
@onready var wood_counter_label: Label = %WoodCounter
@onready var zombie_counter_label: Label = %ZombieCounter
@onready var tower_health_label: Label = %TowerHealthLabel
@onready var trap_indicator: HBoxContainer = %TrapIndicator
@onready var trap_icon_label: Label = %TrapIconLabel
@onready var trap_status_label: Label = %TrapStatusLabel

var time_system: TimeSystem
var sleep_system: SleepSystem
var weather_system: WeatherSystem
var inventory_system: InventorySystem
var tower_health_system: TowerHealthSystem
var zombie_system: ZombieSystem
var health_system: PlayerHealthSystem
var warmth_system: WarmthSystem
var _weight_unit: String = "lbs"
var _latest_weight_lbs: float = 0.0
var _latest_weight_category: String = "average"
var _latest_weather_state: String = WeatherSystem.WEATHER_CLEAR if WeatherSystem else "clear"
var _latest_weather_hours: int = 0

func _ready():
    # Wire HUD widgets to the various systems as soon as the scene loads.
    daily_cal_value_label.add_theme_color_override("font_color", Color.WHITE)
    tired_value_label.add_theme_color_override("font_color", Color.WHITE)
    health_value_label.add_theme_color_override("font_color", Color.WHITE)
    warmth_label.add_theme_color_override("font_color", Color.WHITE)
    warmth_value_label.add_theme_color_override("font_color", Color.WHITE)
    day_label.add_theme_color_override("font_color", Color.WHITE)
    clock_label.add_theme_color_override("font_color", Color.WHITE)
    recon_alert_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
    recon_alert_label.visible = false
    weight_value_label.add_theme_color_override("font_color", Color.WHITE)
    weight_status_label.add_theme_color_override("font_color", Color.WHITE)
    weight_header_label.add_theme_color_override("font_color", Color.WHITE)
    weather_label.add_theme_color_override("font_color", Color.WHITE)
    food_counter_label.add_theme_color_override("font_color", Color.WHITE)
    wood_counter_label.add_theme_color_override("font_color", Color.WHITE)
    zombie_counter_label.add_theme_color_override("font_color", Color.WHITE)
    tower_health_label.add_theme_color_override("font_color", Color.WHITE)

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

    health_system = game_manager.get_health_system()
    if health_system:
        health_system.health_changed.connect(_on_health_changed)
        _on_health_changed(health_system.get_health(), health_system.get_health())

    warmth_system = game_manager.get_warmth_system()
    if warmth_system:
        warmth_system.warmth_changed.connect(_on_warmth_changed)
        _on_warmth_changed(warmth_system.get_warmth(), warmth_system.get_warmth())
    else:
        if is_instance_valid(warmth_bar):
            warmth_bar.value = 0.0
        if is_instance_valid(warmth_value_label):
            warmth_value_label.text = "--"

    game_manager.day_changed.connect(_on_day_changed)
    game_manager.recon_alerts_changed.connect(_on_recon_alerts_changed)
    _update_day_label(game_manager.current_day)
    _on_recon_alerts_changed(game_manager.get_recon_alerts())

    weather_system = game_manager.get_weather_system()
    if weather_system:
        game_manager.weather_changed.connect(_on_weather_changed)
        _on_weather_changed(weather_system.get_state(), weather_system.get_state(), weather_system.get_hours_remaining())
    else:
        weather_label.text = "Weather Offline"

    inventory_system = game_manager.get_inventory_system()
    if inventory_system:
        inventory_system.food_total_changed.connect(_on_food_total_changed)
        inventory_system.item_added.connect(_on_inventory_item_added)
        inventory_system.item_consumed.connect(_on_inventory_item_consumed)
        _on_food_total_changed(inventory_system.get_total_food_units())
        _update_wood_counter()
    else:
        food_counter_label.text = "Food: --"
        wood_counter_label.text = "Wood: --"

    tower_health_system = game_manager.get_tower_health_system()
    if tower_health_system:
        tower_health_system.tower_health_changed.connect(_on_tower_health_changed)
        _on_tower_health_changed(tower_health_system.get_health(), tower_health_system.get_health())
    else:
        tower_health_label.text = "Tower: --"

    zombie_system = game_manager.get_zombie_system()
    if zombie_system:
        zombie_system.zombies_changed.connect(_on_zombie_count_changed)
        _update_zombie_counter(zombie_system.get_active_zombies())
    else:
        zombie_counter_label.text = "Zombies: --"

    if game_manager.has_signal("trap_state_changed"):
        game_manager.trap_state_changed.connect(_on_trap_state_changed)
    _update_trap_indicator(game_manager.get_trap_state())
    trap_icon_label.add_theme_color_override("font_color", Color.WHITE)
    trap_status_label.add_theme_color_override("font_color", Color.WHITE)

func _on_sleep_percent_changed(value: float):
    tired_bar.value = value
    tired_value_label.text = "%d%%" % int(round(value))

func _on_health_changed(value: float, _previous: float):
    if is_instance_valid(health_bar):
        health_bar.value = value
    if is_instance_valid(health_value_label):
        health_value_label.text = "%d%%" % int(round(value))

func _on_warmth_changed(value: float, _previous: float):
    if is_instance_valid(warmth_bar):
        warmth_bar.value = clamp(value, WarmthSystem.MIN_WARMTH, WarmthSystem.MAX_WARMTH)
    if is_instance_valid(warmth_value_label):
        warmth_value_label.text = "%d%%" % int(round(value))

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

func _on_recon_alerts_changed(alerts: Dictionary):
    if !is_instance_valid(recon_alert_label):
        return
    var text = _resolve_recon_alert_text(alerts)
    recon_alert_label.visible = text != ""
    recon_alert_label.text = text

func _on_food_total_changed(new_total: float):
    if !is_instance_valid(food_counter_label):
        return
    food_counter_label.text = "Food: %s" % _format_food_amount(new_total)

func _on_inventory_item_added(item_id: String, _quantity_added: int, _food_gained: float, _total_food_units: float):
    if item_id == "wood":
        _update_wood_counter()

func _on_inventory_item_consumed(item_id: String, _quantity_removed: int, _food_lost: float, _total_food_units: float):
    if item_id == "wood":
        _update_wood_counter()

func _on_tower_health_changed(new_health: float, _previous_health: float):
    if !is_instance_valid(tower_health_label):
        return
    tower_health_label.text = _format_tower_health(new_health)

func _update_wood_counter():
    if !is_instance_valid(wood_counter_label):
        return
    var count = inventory_system.get_item_count("wood") if inventory_system else 0
    wood_counter_label.text = "Wood: %d" % count

func _update_zombie_counter(count: int = -1):
    if !is_instance_valid(zombie_counter_label):
        return
    if zombie_system == null:
        zombie_counter_label.text = "Zombies: --"
        return
    var current = count if count >= 0 else zombie_system.get_active_zombies()
    zombie_counter_label.text = "Zombies: %d" % max(current, 0)

func _on_zombie_count_changed(count: int):
    _update_zombie_counter(count)

func _on_trap_state_changed(_active: bool, state: Dictionary):
    _update_trap_indicator(state)

func _update_trap_indicator(state: Dictionary):
    if !is_instance_valid(trap_indicator) or !is_instance_valid(trap_status_label):
        return

    var active = state.get("active", false)
    trap_indicator.visible = active
    if !active:
        trap_status_label.text = "Trap Idle"
        return

    var break_percent = int(round(state.get("break_chance", GameManager.TRAP_BREAK_CHANCE) * 100.0))
    var deployed_time = String(state.get("deployed_at_time", ""))
    var fragments: PackedStringArray = []
    fragments.append("%d%% break" % break_percent)
    if deployed_time != "":
        fragments.append(deployed_time)
    trap_status_label.text = "Trap Armed (%s)" % " | ".join(fragments)

func _on_weight_unit_button_pressed():
    if sleep_system:
        sleep_system.toggle_weight_unit()

func _resolve_game_manager() -> GameManager:
    # Gracefully search for the manager so editor previews do not hard-crash.
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

func _resolve_recon_alert_text(alerts: Dictionary) -> String:
    if typeof(alerts) != TYPE_DICTIONARY or alerts.is_empty():
        return ""
    var chosen_entry: Dictionary = {}
    var chosen_minutes: float = -1.0
    for key in alerts.keys():
        var entry = alerts.get(key, {})
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        if !entry.get("active", true):
            continue
        var remaining = float(entry.get("minutes_until", -1))
        if remaining <= 0.0:
            continue
        if chosen_minutes < 0.0 or remaining < chosen_minutes:
            chosen_minutes = remaining
            chosen_entry = entry
    if chosen_entry.is_empty():
        return ""
    var eta = _format_recon_eta(chosen_entry.get("minutes_until", 0.0))
    var label = String(chosen_entry.get("label", ""))
    var entry_type = String(chosen_entry.get("type", ""))
    if entry_type == "weather":
        if label == "":
            label = "Weather"
        return "%s in %s" % [label, eta]
    if entry_type == "zombies":
        return "Zombies approaching in %s" % eta
    if label == "":
        label = "Event"
    return "%s in %s" % [label, eta]

func _format_recon_eta(value: float) -> String:
    var minutes = int(round(value))
    if minutes <= 0:
        return "0h"
    var hours = minutes / 60
    var mins = minutes % 60
    if hours > 0 and mins > 0:
        return "%dh %dm" % [hours, mins]
    if hours > 0:
        return "%dh" % hours
    return "%dm" % mins

func _format_weight_category_title(category: String) -> String:
    match category:
        "malnourished":
            return "Malnourished"
        "overweight":
            return "Overweight"
        _:
            return "Healthy"

func _format_food_amount(value: float) -> String:
    if is_equal_approx(value, round(value)):
        return "%d" % int(round(value))
    return "%.1f" % value

func _format_tower_health(value: float) -> String:
    if tower_health_system == null:
        return "Tower: --"
    var max_health = tower_health_system.get_max_health()
    return "Tower: %.0f/%.0f" % [value, max_health]
