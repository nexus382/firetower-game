extends Node
class_name GameManager

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const BodyWeightSystem = preload("res://scripts/systems/BodyWeightSystem.gd")

signal time_changed(formatted_time: String)
signal day_changed(day_index: int)

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
    player = get_node("../Player")
    if player:
        print("✅ Player found and connected")
    else:
        print("❌ Player not found!")

    sleep_system = SleepSystem.new()
    time_system = TimeSystem.new()
    body_weight_system = BodyWeightSystem.new()

    current_day = time_system.get_current_day()
    time_system.time_changed.connect(_on_time_changed)
    time_system.day_rolled_over.connect(_on_day_rolled_over)

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
    """Expose the shared timekeeper."""
    return time_system

func get_body_weight_system() -> BodyWeightSystem:
    """Expose weight data for modifiers and UI."""
    return body_weight_system

func get_sleep_percent() -> float:
    """Convenience accessor for tired meter value."""
    return sleep_system.get_sleep_percent() if sleep_system else 0.0

func get_daily_calories_used() -> int:
    """Current daily calorie usage (can go negative)."""
    return sleep_system.get_daily_calories_used() if sleep_system else 0

func get_formatted_time() -> String:
    return time_system.get_formatted_time() if time_system else "--:--"

func set_difficulty_multiplier(value: float):
    if time_system:
        time_system.set_difficulty_multiplier(value)

func get_effective_minutes_for_hours(hours: int) -> Dictionary:
    if not time_system:
        return {}
    var weight_multiplier := _get_weight_time_multiplier()
    var base_minutes := max(hours, 0) * 60
    var preview := time_system.preview_minutes(base_minutes, weight_multiplier)
    preview["weight_multiplier"] = weight_multiplier
    preview["difficulty_multiplier"] = time_system.get_difficulty_multiplier() if time_system else 1.0
    return preview

func schedule_sleep(hours: int) -> Dictionary:
    """Apply sleep hours and propagate calorie burn."""
    if not sleep_system or not time_system:
        return {}

    var weight_multiplier := _get_weight_time_multiplier()
    var time_result := time_system.advance_hours(hours, weight_multiplier)
    var sleep_result := sleep_system.apply_sleep(hours)
    sleep_result["time_spent_minutes"] = time_result.get("effective_minutes", 0)
    sleep_result["finished_at"] = time_result.get("result_time", get_formatted_time())
    sleep_result["rolled_days"] = time_result.get("rolled_days", 0)
    sleep_result["finished_day"] = time_result.get("result_day", current_day)
    print("⏱️ Sleep task used %d min (weight x%.2f) -> finished %s on Day %d" % [
        sleep_result["time_spent_minutes"],
        weight_multiplier,
        sleep_result["finished_at"],
        sleep_result["finished_day"]
    ])
    return sleep_result

func _get_weight_time_multiplier() -> float:
    if body_weight_system:
        return body_weight_system.get_time_multiplier()
    return 1.0

func _on_time_changed(formatted_time: String):
    time_changed.emit(formatted_time)

func _on_day_rolled_over(new_day_index: int):
    current_day = new_day_index
    if sleep_system:
        sleep_system.reset_daily_counters()
    if body_weight_system:
        body_weight_system.reset_daily_counters()
    day_changed.emit(current_day)
