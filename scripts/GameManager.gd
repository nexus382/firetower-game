extends Node
class_name GameManager

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const BodyWeightSystem = preload("res://scripts/systems/BodyWeightSystem.gd")

signal day_changed(new_day: int)
signal systems_ready
signal body_weight_changed(display_weight: String)

# Core game state
var current_day: int = 1
var game_paused: bool = false

# Player reference
var player: CharacterBody2D

# Simulation systems
var sleep_system: SleepSystem
var time_system: TimeSystem
var body_weight_system: BodyWeightSystem

func _ready():
    print("🎮 GameManager initialized - Day %d" % current_day)
    add_to_group("game_manager")
    player = get_node("../Player")
    if player:
        print("✅ Player found and connected")
    else:
        print("❌ Player not found!")

    sleep_system = SleepSystem.new()
    time_system = TimeSystem.new()
    body_weight_system = BodyWeightSystem.new()

    if time_system:
        time_system.day_rolled_over.connect(_on_day_rolled_over)

    if body_weight_system:
        body_weight_system.body_weight_changed.connect(_on_body_weight_changed)

    call_deferred("_emit_initial_system_state")

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

func get_body_weight_system() -> BodyWeightSystem:
    """Expose the body weight system for UI consumers."""
    return body_weight_system

func get_sleep_percent() -> float:
    """Convenience accessor for tired meter value."""
    return sleep_system.get_sleep_percent() if sleep_system else 0.0

func get_daily_calories_used() -> int:
    """Current daily calorie usage (can go negative)."""
    return sleep_system.get_daily_calories_used() if sleep_system else 0

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

    var requested_minutes = hours * 60
    var minutes_available = time_system.get_minutes_until_daybreak()
    if requested_minutes > minutes_available:
        print("⚠️ Sleep rejected: %d min requested, %d min available" % [requested_minutes, minutes_available])
        return {
            "accepted": false,
            "reason": "exceeds_day",
            "minutes_available": minutes_available,
            "hours_available": int(minutes_available / 60)
        }

    var time_report = time_system.advance_minutes(requested_minutes)
    var sleep_report = sleep_system.apply_sleep(hours)

    var result: Dictionary = sleep_report.duplicate()
    result["accepted"] = true
    result["minutes_spent"] = time_report.get("minutes_applied", requested_minutes)
    result["rolled_over"] = time_report.get("rolled_over", false)
    result["daybreaks_crossed"] = time_report.get("daybreaks_crossed", 0)
    result["ended_at_minutes_since_daybreak"] = time_system.get_minutes_since_daybreak()
    result["ended_at_time"] = time_system.get_formatted_time()
    result["minutes_until_daybreak"] = time_system.get_minutes_until_daybreak()

    return result

func _on_day_rolled_over():
    current_day += 1
    print("🌅 New day begins: Day %d" % current_day)
    if sleep_system:
        sleep_system.reset_daily_counters()
    if body_weight_system:
        var weight_report = body_weight_system.calculate_daily_weight_change()
        var new_weight = weight_report.get("new_weight_lbs", body_weight_system.get_weight_lbs())
        var delta = weight_report.get("weight_change_lbs", 0.0)
        print("⚖️ Weight update: %.1f lbs (%+.1f)" % [new_weight, delta])
    day_changed.emit(current_day)

func _on_body_weight_changed(display_weight: String):
    body_weight_changed.emit(display_weight)

func _emit_initial_system_state():
    systems_ready.emit()
    if body_weight_system:
        body_weight_changed.emit(body_weight_system.get_weight_display_string())
