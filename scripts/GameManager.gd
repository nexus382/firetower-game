extends Node
class_name GameManager

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")

# Core game state
var current_day: int = 1
var game_paused: bool = false

# Player reference
var player: CharacterBody2D

# Simulation systems
var sleep_system: SleepSystem

func _ready():
    print("🎮 GameManager initialized - Day %d" % current_day)
    player = get_node("../Player")
    if player:
        print("✅ Player found and connected")
    else:
        print("❌ Player not found!")

    sleep_system = SleepSystem.new()

func pause_game():
    game_paused = true
    print("⏸️ Game paused")

func resume_game():
    game_paused = false
    print("▶️ Game resumed")

func get_sleep_system() -> SleepSystem:
    """Expose the sleep system for UI consumers."""
    return sleep_system

func get_sleep_percent() -> float:
    """Convenience accessor for tired meter value."""
    return sleep_system.get_sleep_percent() if sleep_system else 0.0

func get_daily_calories_used() -> int:
    """Current daily calorie usage (can go negative)."""
    return sleep_system.get_daily_calories_used() if sleep_system else 0

func schedule_sleep(hours: int) -> Dictionary:
    """Apply sleep hours and propagate calorie burn."""
    if not sleep_system:
        return {}

    return sleep_system.apply_sleep(hours)
