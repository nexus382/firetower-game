extends RefCounted
class_name BodyWeightSystem

# Weight configuration (in pounds)
const HEALTHY_MIN_WEIGHT_LBS = 180.0
const HEALTHY_MAX_WEIGHT_LBS = 219.0
const OVERWEIGHT_THRESHOLD_LBS = 220.0
const SKINNY_THRESHOLD_LBS = 150.0
const MALNOURISHED_THRESHOLD_LBS = 149.0

# Calorie configuration
const CALORIES_PER_POUND = 1000.0  # 1000 calories = 1 pound change

# Weight tracking (internal storage in pounds)
var current_weight_lbs: float = 200.0  # Start at 200 lbs (healthy weight)
var daily_calories_consumed: int = 0
var daily_calories_burned: int = 0

# UI preferences
var display_unit: String = "lbs"  # "lbs" or "kg"

# Weight categories for health buffs/debuffs
enum WeightCategory {
    MALNOURISHED,  # < 150 lbs
    SKINNY,        # 150-179 lbs
    NORMAL,        # 180-219 lbs
    OVERWEIGHT     # >= 220 lbs
}

# Task timing modifiers
const WEIGHT_TIME_MULTIPLIERS := {
    WeightCategory.MALNOURISHED: 1.35,
    WeightCategory.SKINNY: 1.15,
    WeightCategory.NORMAL: 1.0,
    WeightCategory.OVERWEIGHT: 1.25
}

func _init():
    print("⚖️ BodyWeightSystem initialized with %d lbs" % current_weight_lbs)

# Unit conversion methods
func get_weight_kg() -> float:
    """Convert pounds to kilograms"""
    return current_weight_lbs / 2.2

func get_weight_lbs() -> float:
    """Get weight in pounds"""
    return current_weight_lbs

func set_display_unit(unit: String):
    """Set preferred display unit for UI"""
    if unit in ["lbs", "kg"]:
        display_unit = unit
        print("⚖️ Display unit set to: %s" % unit)

func get_display_weight() -> float:
    """Get weight in preferred display unit"""
    return get_weight_kg() if display_unit == "kg" else get_weight_lbs()

# Calorie management
func consume_food(calories: int) -> bool:
    """Add calories from eating"""
    if calories < 0:
        return false

    daily_calories_consumed += calories
    print("🍽️ Consumed %d calories (total: %d)" % [calories, daily_calories_consumed])
    return true

func burn_calories(calories: int) -> bool:
    """Burn calories from activities"""
    if calories < 0:
        return false

    daily_calories_burned += calories
    print("🔥 Burned %d calories (total: %d)" % [calories, daily_calories_burned])
    return true

# Daily weight calculation
func calculate_daily_weight_change() -> Dictionary:
    """Calculate weight change from daily calorie balance"""
    var net_calories = daily_calories_consumed - daily_calories_burned
    var weight_change_lbs = net_calories / CALORIES_PER_POUND

    var old_weight = current_weight_lbs
    current_weight_lbs += weight_change_lbs

    # Reset daily counters
    daily_calories_consumed = 0
    daily_calories_burned = 0

    return {
        "old_weight_lbs": old_weight,
        "new_weight_lbs": current_weight_lbs,
        "weight_change_lbs": weight_change_lbs,
        "net_calories": net_calories,
        "category": get_weight_category()
    }

# Weight category determination
func get_weight_category() -> int:
    """Get current weight category for health effects"""
    if current_weight_lbs <= MALNOURISHED_THRESHOLD_LBS:
        return WeightCategory.MALNOURISHED
    elif current_weight_lbs < SKINNY_THRESHOLD_LBS:
        return WeightCategory.SKINNY
    elif current_weight_lbs <= HEALTHY_MAX_WEIGHT_LBS:
        return WeightCategory.NORMAL
    else:
        return WeightCategory.OVERWEIGHT

func get_weight_category_name() -> String:
    """Get human-readable weight category name"""
    match get_weight_category():
        WeightCategory.MALNOURISHED:
            return "Malnourished"
        WeightCategory.SKINNY:
            return "Skinny"
        WeightCategory.NORMAL:
            return "Normal"
        WeightCategory.OVERWEIGHT:
            return "Overweight"
        _:
            return "Unknown"

func get_weight_effects() -> Array:
    """Get gameplay effects based on weight category"""
    match get_weight_category():
        WeightCategory.MALNOURISHED:
            return ["Weak", "Slow Healing", "Low Energy"]
        WeightCategory.SKINNY:
            return ["Reduced Strength", "Faster Fatigue"]
        WeightCategory.NORMAL:
            return []  # Optimal performance
        WeightCategory.OVERWEIGHT:
            return ["Slower Movement", "Higher Calorie Needs"]
        _:
            return []

# UI data methods
func get_weight_display_string() -> String:
    """Get formatted weight string for UI"""
    var weight = get_display_weight()
    var unit = display_unit.to_upper()
    return "%.1f %s" % [weight, unit]

func get_calorie_summary() -> Dictionary:
    """Get daily calorie tracking for UI"""
    return {
        "consumed": daily_calories_consumed,
        "burned": daily_calories_burned,
        "net": daily_calories_consumed - daily_calories_burned,
        "category": get_weight_category_name()
    }

func get_time_multiplier() -> float:
    """Multiplier applied to task durations based on weight class"""
    var category := get_weight_category()
    return WEIGHT_TIME_MULTIPLIERS.get(category, 1.0)

func reset_daily_counters():
    """Clear per-day calorie tracking when the clock rolls over"""
    daily_calories_consumed = 0
    daily_calories_burned = 0
    print("🔁 Body weight daily counters reset")
