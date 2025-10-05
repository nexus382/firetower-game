extends Node
class_name GameManager

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const WeatherSystem = preload("res://scripts/systems/WeatherSystem.gd")

signal day_changed(new_day: int)
signal weather_changed(new_state: String, previous_state: String, hours_remaining: int)
signal weather_multiplier_changed(new_multiplier: float, state: String)

# Core game state
var current_day: int = 1
var game_paused: bool = false

# Player reference
var player: CharacterBody2D

# Simulation systems
var sleep_system: SleepSystem
var time_system: TimeSystem
var weather_system: WeatherSystem
var _last_awake_minute_stamp: int = 0

func _ready():
    print("🎮 GameManager initialized - Day %d" % current_day)
    player = get_node("../Player")
    if player:
        print("✅ Player found and connected")
    else:
        print("❌ Player not found!")

    sleep_system = SleepSystem.new()
    time_system = TimeSystem.new()
    weather_system = WeatherSystem.new()
    if time_system:
        time_system.day_rolled_over.connect(_on_day_rolled_over)
        _last_awake_minute_stamp = time_system.get_minutes_since_daybreak()
        if weather_system:
            time_system.time_advanced.connect(Callable(weather_system, "on_time_advanced"))
            time_system.day_rolled_over.connect(Callable(weather_system, "on_day_rolled_over"))
            weather_system.initialize_clock_offset(time_system.get_minutes_since_daybreak())
    if weather_system:
        weather_system.weather_changed.connect(_on_weather_system_changed)
        weather_system.broadcast_state()

func pause_game():
    game_paused = true
    print("⏸️ Game paused")

func resume_game():
    game_paused = false
    print("▶️ Game resumed")

func get_sleep_system() -> SleepSystem:
    """Expose the sleep system for UI consumers."""
    return sleep_system

func get_time_system() -> TimeSystem:
    """Expose the time system for UI consumers."""
    return time_system

func get_weather_system() -> WeatherSystem:
    """Expose the weather system for UI consumers."""
    return weather_system

func get_sleep_percent() -> float:
    """Convenience accessor for tired meter value."""
    return sleep_system.get_sleep_percent() if sleep_system else 0.0

func get_daily_calories_used() -> float:
    """Current daily calorie usage (can go negative)."""
    return sleep_system.get_daily_calories_used() if sleep_system else 0

func get_player_weight_lbs() -> float:
    return sleep_system.get_player_weight_lbs() if sleep_system else 0.0

func get_player_weight_kg() -> float:
    return sleep_system.get_player_weight_kg() if sleep_system else 0.0

func get_weight_unit() -> String:
    return sleep_system.get_weight_unit() if sleep_system else SleepSystem.WEIGHT_UNIT_LBS

func set_weight_unit(unit: String) -> String:
    return sleep_system.set_weight_unit(unit) if sleep_system else unit

func toggle_weight_unit() -> String:
    return sleep_system.toggle_weight_unit() if sleep_system else SleepSystem.WEIGHT_UNIT_LBS

func get_time_multiplier() -> float:
    return sleep_system.get_time_multiplier() if sleep_system else 1.0

func get_weather_activity_multiplier() -> float:
    return weather_system.get_activity_multiplier() if weather_system else 1.0

func get_combined_activity_multiplier() -> float:
    return get_time_multiplier() * get_weather_activity_multiplier()

func schedule_sleep(hours: int) -> Dictionary:
    """Apply sleep hours while advancing the daily clock."""
    if not sleep_system or not time_system:
        return {
            "accepted": false,
            "reason": "systems_unavailable"
        }

    hours = max(hours, 0)
    if hours == 0:
        return {
            "accepted": false,
            "reason": "no_hours"
        }

    var current_minutes = time_system.get_minutes_since_daybreak()
    _apply_awake_time_up_to(current_minutes)

    var multiplier = sleep_system.get_time_multiplier()
    var requested_minutes = int(ceil(hours * 60.0 * multiplier))
    var minutes_available = time_system.get_minutes_until_daybreak()
    if requested_minutes > minutes_available:
        print("⚠️ Sleep rejected: %d min requested, %d min available" % [requested_minutes, minutes_available])
        var hours_available = int(floor(minutes_available / (60.0 * multiplier)))
        return {
            "accepted": false,
            "reason": "exceeds_day",
            "minutes_available": minutes_available,
            "hours_available": max(hours_available, 0),
            "time_multiplier": multiplier
        }

    var time_report = time_system.advance_minutes(requested_minutes)
    var sleep_report = sleep_system.apply_sleep(hours)

    _last_awake_minute_stamp = time_system.get_minutes_since_daybreak()

    var result: Dictionary = sleep_report.duplicate()
    result["accepted"] = true
    result["minutes_spent"] = time_report.get("minutes_applied", requested_minutes)
    result["rolled_over"] = time_report.get("rolled_over", false)
    result["daybreaks_crossed"] = time_report.get("daybreaks_crossed", 0)
    result["ended_at_minutes_since_daybreak"] = time_system.get_minutes_since_daybreak()
    result["ended_at_time"] = time_system.get_formatted_time()
    result["minutes_until_daybreak"] = time_system.get_minutes_until_daybreak()
    result["time_multiplier"] = multiplier
    result["requested_minutes"] = requested_minutes

    print("⏳ Time multiplier x%.1f -> %d min spent" % [multiplier, result["minutes_spent"]])

    return result

func _on_day_rolled_over():
    current_day += 1
    print("🌅 New day begins: Day %d" % current_day)
    if sleep_system:
        sleep_system.reset_daily_counters()
    _last_awake_minute_stamp = 0
    day_changed.emit(current_day)

func _on_weather_system_changed(new_state: String, previous_state: String, hours_remaining: int):
    var multiplier = get_weather_activity_multiplier()
    weather_changed.emit(new_state, previous_state, hours_remaining)
    weather_multiplier_changed.emit(multiplier, new_state)

func _apply_awake_time_up_to(current_minutes: int):
    if not sleep_system or not time_system:
        return

    var delta = current_minutes - _last_awake_minute_stamp
    if delta < 0:
        delta += TimeSystem.MINUTES_PER_DAY
    if delta > 0:
        sleep_system.apply_awake_minutes(delta)
    _last_awake_minute_stamp = current_minutes
