extends Node
class_name GameManager

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const WeatherSystem = preload("res://scripts/systems/WeatherSystem.gd")
const TowerHealthSystem = preload("res://scripts/systems/TowerHealthSystem.gd")

const CALORIES_PER_FOOD_UNIT: float = 1000.0

const MEAL_PORTIONS := {
    "small": {
        "food_units": 0.5,
        "label": "Small"
    },
    "normal": {
        "food_units": 1.0,
        "label": "Normal"
    },
    "large": {
        "food_units": 1.5,
        "label": "Large"
    }
}

signal day_changed(new_day: int)
signal weather_changed(new_state: String, previous_state: String, hours_remaining: int)
signal weather_multiplier_changed(new_multiplier: float, state: String)

# Core game state
var current_day: int = 1
var game_paused: bool = false

# Player reference
var player: CharacterBody2D

# Simulation systems
# Instantiated immediately so UI elements resolving GameManager during their own _ready callbacks
# always see live systems instead of a null placeholder.
var sleep_system: SleepSystem = SleepSystem.new()
var inventory_system: InventorySystem = InventorySystem.new()
var time_system: TimeSystem = TimeSystem.new()
var weather_system: WeatherSystem = WeatherSystem.new()
var tower_health_system: TowerHealthSystem = TowerHealthSystem.new()
var _last_awake_minute_stamp: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
    print("🎮 GameManager initialized - Day %d" % current_day)
    player = get_node("../Player")
    if player:
        print("✅ Player found and connected")
    else:
        print("❌ Player not found!")

    if sleep_system == null:
        sleep_system = SleepSystem.new()
    if inventory_system == null:
        inventory_system = InventorySystem.new()
    if time_system == null:
        time_system = TimeSystem.new()
    if weather_system == null:
        weather_system = WeatherSystem.new()
    if tower_health_system == null:
        tower_health_system = TowerHealthSystem.new()
    if _rng == null:
        _rng = RandomNumberGenerator.new()
    _rng.randomize()

    if inventory_system:
        inventory_system.bootstrap_defaults()
        inventory_system.set_total_food_units(5.0)
    if time_system:
        time_system.day_rolled_over.connect(_on_day_rolled_over)
        _last_awake_minute_stamp = time_system.get_minutes_since_daybreak()
        if weather_system:
            time_system.time_advanced.connect(Callable(weather_system, "on_time_advanced"))
            time_system.day_rolled_over.connect(Callable(weather_system, "on_day_rolled_over"))
            weather_system.initialize_clock_offset(time_system.get_minutes_since_daybreak())
    if weather_system:
        weather_system.weather_changed.connect(_on_weather_system_changed)
        weather_system.weather_hour_elapsed.connect(_on_weather_hour_elapsed)
        weather_system.broadcast_state()
    if tower_health_system and weather_system:
        tower_health_system.set_initial_weather_state(weather_system.get_state())

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

func get_inventory_system() -> InventorySystem:
    """Expose the inventory system for UI consumers."""
    return inventory_system

func get_weather_system() -> WeatherSystem:
    """Expose the weather system for UI consumers."""
    return weather_system

func get_tower_health_system() -> TowerHealthSystem:
    return tower_health_system

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

func perform_eating(portion_key: String) -> Dictionary:
    if not sleep_system or not time_system or not inventory_system:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "eat"
        }

    var portion = _resolve_meal_portion(portion_key)
    var food_units = portion.get("food_units", 1.0)
    if !inventory_system.has_food_units(food_units):
        return {
            "success": false,
            "reason": "insufficient_food",
            "action": "eat",
            "portion": portion.get("key", "normal"),
            "required_food": food_units,
            "total_food_units": inventory_system.get_total_food_units()
        }

    var time_report = _spend_activity_time(1.0, "eat")
    if !time_report.get("success", false):
        time_report["action"] = "eat"
        time_report["portion"] = portion.get("key", "normal")
        return time_report

    var consume_report = inventory_system.consume_food_units(food_units)
    if !consume_report.get("success", false):
        return {
            "success": false,
            "reason": consume_report.get("reason", "consume_failed"),
            "action": "eat",
            "portion": portion.get("key", "normal"),
            "required_food": food_units,
            "total_food_units": inventory_system.get_total_food_units()
        }

    var calories = portion.get("calories", food_units * CALORIES_PER_FOOD_UNIT)
    var daily_total = sleep_system.adjust_daily_calories(-calories)
    var result := time_report.duplicate()
    result["action"] = "eat"
    result["portion"] = portion.get("key", "normal")
    result["food_units_spent"] = consume_report.get("amount_consumed", food_units)
    result["calories_consumed"] = calories
    result["calorie_delta"] = -calories
    result["daily_calories_used"] = daily_total
    result["weight_lbs"] = sleep_system.get_player_weight_lbs()
    result["total_food_units"] = inventory_system.get_total_food_units()

    print("🍴 Ate %s meal: -%.0f cal, -%.1f food" % [result["portion"], calories, result["food_units_spent"]])
    return result

func repair_tower(materials: Dictionary = {}) -> Dictionary:
    if not time_system or not sleep_system or tower_health_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "repair"
        }

    if tower_health_system.is_at_max_health():
        return {
            "success": false,
            "reason": "tower_full_health",
            "action": "repair",
            "health": tower_health_system.get_health()
        }

    var time_report = _spend_activity_time(1.0, "repair")
    if !time_report.get("success", false):
        time_report["action"] = "repair"
        return time_report

    var before = tower_health_system.get_health()
    var repaired = tower_health_system.apply_repair(TowerHealthSystem.REPAIR_HEALTH_PER_ACTION, "manual_repair", materials)
    var result := time_report.duplicate()
    result["action"] = "repair"
    result["health_before"] = before
    result["health_after"] = repaired
    result["health_restored"] = repaired - before

    print("🔧 Tower repair -> +%.1f (%.1f/%.1f)" % [result["health_restored"], repaired, tower_health_system.get_max_health()])
    return result

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

func perform_forging() -> Dictionary:
    if inventory_system == null or _rng == null:
        return {
            "success": false,
            "reason": "inventory_unavailable"
        }

    var roll = _rng.randf()
    var outcome = _resolve_forging_outcome(roll)
    if outcome.is_empty():
        print("🌲 Forging yielded nothing (roll %.2f)" % roll)
        return {
            "success": false,
            "reason": "nothing_found",
            "chance_roll": roll
        }

    var report = inventory_system.add_item(outcome.get("item_id", ""), outcome.get("quantity", 1))
    report["success"] = true
    report["chance_roll"] = roll
    print("🌲 Forging success: %s" % report)
    return report

func _resolve_forging_outcome(roll: float) -> Dictionary:
    var thresholds = [
        {
            "cutoff": 0.25,
            "item_id": "mushrooms",
            "quantity": 1
        },
        {
            "cutoff": 0.50,
            "item_id": "berries",
            "quantity": 1
        },
        {
            "cutoff": 0.75,
            "item_id": "walnuts",
            "quantity": 1
        },
        {
            "cutoff": 0.95,
            "item_id": "grubs",
            "quantity": 1
        }
    ]

    for entry in thresholds:
        if roll < entry.get("cutoff", 0.0):
            return entry

    return {}

func _on_day_rolled_over():
    current_day += 1
    print("🌅 New day begins: Day %d" % current_day)
    if sleep_system:
        sleep_system.reset_daily_counters()
    _last_awake_minute_stamp = 0
    if tower_health_system:
        var current_state = weather_system.get_state() if weather_system else WeatherSystem.WEATHER_CLEAR
        tower_health_system.on_day_completed(current_state)
    day_changed.emit(current_day)

func _on_weather_system_changed(new_state: String, previous_state: String, hours_remaining: int):
    var multiplier = get_weather_activity_multiplier()
    weather_changed.emit(new_state, previous_state, hours_remaining)
    weather_multiplier_changed.emit(multiplier, new_state)

func _on_weather_hour_elapsed(state: String):
    if tower_health_system:
        tower_health_system.register_weather_hour(state)

func _apply_awake_time_up_to(current_minutes: int):
    if not sleep_system or not time_system:
        return

    var delta = current_minutes - _last_awake_minute_stamp
    if delta < 0:
        delta += TimeSystem.MINUTES_PER_DAY
    if delta > 0:
        sleep_system.apply_awake_minutes(delta)
    _last_awake_minute_stamp = current_minutes

func _resolve_meal_portion(portion_key: String) -> Dictionary:
    var key = portion_key.to_lower()
    if key.is_empty() or !MEAL_PORTIONS.has(key):
        key = "normal"
    var definition: Dictionary = MEAL_PORTIONS.get(key, MEAL_PORTIONS["normal"])
    var resolved := definition.duplicate()
    resolved["key"] = key
    resolved["calories"] = resolved.get("food_units", 1.0) * CALORIES_PER_FOOD_UNIT
    return resolved

func _spend_activity_time(hours: float, activity: String) -> Dictionary:
    if not time_system or not sleep_system:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "activity": activity
        }

    hours = max(hours, 0.0)
    if is_zero_approx(hours):
        return {
            "success": false,
            "reason": "no_duration",
            "activity": activity
        }

    var multiplier = get_combined_activity_multiplier()
    multiplier = max(multiplier, 0.01)
    var requested_minutes = int(ceil(hours * 60.0 * multiplier))
    requested_minutes = max(requested_minutes, 1)
    var minutes_available = time_system.get_minutes_until_daybreak()
    if requested_minutes > minutes_available:
        return {
            "success": false,
            "reason": "exceeds_day",
            "activity": activity,
            "minutes_required": requested_minutes,
            "minutes_available": minutes_available,
            "time_multiplier": multiplier
        }

    var current_minutes = time_system.get_minutes_since_daybreak()
    _apply_awake_time_up_to(current_minutes)

    var advance_report = time_system.advance_minutes(requested_minutes)
    if sleep_system:
        sleep_system.apply_awake_minutes(requested_minutes)

    _last_awake_minute_stamp = time_system.get_minutes_since_daybreak()

    return {
        "success": true,
        "activity": activity,
        "minutes_spent": requested_minutes,
        "time_multiplier": multiplier,
        "rolled_over": advance_report.get("rolled_over", false),
        "daybreaks_crossed": advance_report.get("daybreaks_crossed", 0),
        "ended_at_minutes_since_daybreak": time_system.get_minutes_since_daybreak(),
        "ended_at_time": time_system.get_formatted_time(),
        "minutes_until_daybreak": time_system.get_minutes_until_daybreak()
    }
