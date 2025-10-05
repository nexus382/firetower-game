extends RefCounted
class_name SleepSystem

# Sleep configuration
const MIN_SLEEP_PERCENT: float = 0.0
const MAX_SLEEP_PERCENT: float = 100.0
const SLEEP_PERCENT_PER_HOUR: float = 10.0
const CALORIES_PER_SLEEP_HOUR: int = 100

# Hunger & weight configuration (logic stored in pounds)
const AWAKE_CALORIES_PER_HOUR: float = 23.0
const CALORIES_PER_POUND: float = 100.0
const WEIGHT_UNIT_LBS := "lbs"
const WEIGHT_UNIT_KG := "kg"
const MALNOURISHED_MAX_LBS: float = 149.0
const NORMAL_MIN_LBS: float = 150.0
const NORMAL_MAX_LBS: float = 200.0
const OVERWEIGHT_MIN_LBS: float = 201.0

# Signals for UI bindings
signal sleep_percent_changed(new_percent: float)
signal daily_calories_used_changed(new_total: float)
signal weight_changed(new_weight_lbs: float)
signal weight_category_changed(new_category: String)
signal weight_unit_changed(new_unit: String)

# Internal state
var sleep_percent: float = 75.0
var daily_calories_used: float = 0.0
var player_weight_lbs: float = 175.0
var weight_unit: String = WEIGHT_UNIT_LBS

var _current_weight_category: String = ""

func _init():
    _current_weight_category = _determine_weight_category(player_weight_lbs)
    print("😴 SleepSystem ready with %.0f%% rest, %.1f lbs (%s)" % [sleep_percent, player_weight_lbs, _current_weight_category])

func get_sleep_percent() -> float:
    """Current tired meter value (0-100%)."""
    return sleep_percent

func get_daily_calories_used() -> float:
    """Calories burned today from all activities."""
    return daily_calories_used

func get_player_weight_lbs() -> float:
    """Current player weight in pounds."""
    return player_weight_lbs

func get_player_weight_kg() -> float:
    """Current player weight converted to kilograms."""
    return player_weight_lbs / 2.2

func get_display_weight() -> float:
    return get_player_weight_lbs() if weight_unit == WEIGHT_UNIT_LBS else get_player_weight_kg()

func get_weight_unit() -> String:
    return weight_unit

func set_weight_unit(unit: String) -> String:
    unit = unit.to_lower()
    if unit not in [WEIGHT_UNIT_LBS, WEIGHT_UNIT_KG]:
        return weight_unit
    if unit == weight_unit:
        return weight_unit
    weight_unit = unit
    weight_unit_changed.emit(weight_unit)
    weight_changed.emit(player_weight_lbs)
    print("⚖️ Weight unit set to %s" % weight_unit)
    return weight_unit

func toggle_weight_unit() -> String:
    var new_unit = WEIGHT_UNIT_KG if weight_unit == WEIGHT_UNIT_LBS else WEIGHT_UNIT_LBS
    return set_weight_unit(new_unit)

func get_weight_category() -> String:
    return _current_weight_category

func get_time_multiplier() -> float:
    match _current_weight_category:
        "malnourished":
            return 2.0
        "overweight":
            return 1.5
        _:
            return 1.0

func apply_sleep(hours: int) -> Dictionary:
    """Increase rest by scheduled sleep hours and track calorie burn."""
    hours = max(hours, 0)
    if hours == 0:
        return {
            "hours": 0,
            "percent_gained": 0.0,
            "new_percent": sleep_percent,
            "calories_used": 0,
            "weight_delta_lbs": 0.0,
            "new_weight_lbs": player_weight_lbs
        }

    var gained_percent = hours * SLEEP_PERCENT_PER_HOUR
    var previous_percent = sleep_percent
    sleep_percent = clamp(previous_percent + gained_percent, MIN_SLEEP_PERCENT, MAX_SLEEP_PERCENT)
    var actual_gain = sleep_percent - previous_percent

    var calories_spent = float(hours * CALORIES_PER_SLEEP_HOUR)
    var weight_delta = _apply_calorie_delta(calories_spent)

    sleep_percent_changed.emit(sleep_percent)

    print("🛌 Slept %d hour(s): +%.0f%% rest, %.0f%% total" % [hours, actual_gain, sleep_percent])
    print("🔥 Daily calories used: %.0f" % daily_calories_used)

    return {
        "hours": hours,
        "percent_gained": actual_gain,
        "new_percent": sleep_percent,
        "calories_used": calories_spent,
        "weight_delta_lbs": weight_delta,
        "new_weight_lbs": player_weight_lbs
    }

func consume_sleep(percent: float) -> float:
    """Reduce rest by a raw percent (for tiring actions)."""
    percent = max(percent, 0.0)
    if percent == 0.0:
        return 0.0

    var previous_percent = sleep_percent
    sleep_percent = clamp(previous_percent - percent, MIN_SLEEP_PERCENT, MAX_SLEEP_PERCENT)
    var actual_spent = previous_percent - sleep_percent

    if !is_zero_approx(actual_spent):
        sleep_percent_changed.emit(sleep_percent)
        print("😓 Spent %.0f%% rest (%.0f%% remaining)" % [actual_spent, sleep_percent])

    return actual_spent

func apply_awake_minutes(minutes: int) -> Dictionary:
    """Burn baseline calories for awake time (23 cal/hour)."""
    minutes = max(minutes, 0)
    if minutes == 0:
        return {
            "minutes": 0,
            "calories_used": 0.0,
            "weight_delta_lbs": 0.0,
            "new_weight_lbs": player_weight_lbs
        }

    var calories = minutes * (AWAKE_CALORIES_PER_HOUR / 60.0)
    var weight_delta = _apply_calorie_delta(calories)
    print("🥪 Awake burn %d min -> %.1f cal" % [minutes, calories])
    return {
        "minutes": minutes,
        "calories_used": calories,
        "weight_delta_lbs": weight_delta,
        "new_weight_lbs": player_weight_lbs
    }

func adjust_daily_calories(calorie_delta: float) -> float:
    """Apply external calorie changes (e.g. meals) to the daily total."""
    var weight_delta = _apply_calorie_delta(calorie_delta)
    print("📊 Daily calorie delta adjusted by %.1f (total: %.0f, Δlbs: %.2f)" % [calorie_delta, daily_calories_used, weight_delta])
    return daily_calories_used

func reset_daily_counters():
    """Clear daily tracking at day rollover."""
    daily_calories_used = 0.0
    print("🔄 Daily calorie usage reset")
    daily_calories_used_changed.emit(daily_calories_used)

func _apply_calorie_delta(calorie_delta: float) -> float:
    if is_zero_approx(calorie_delta):
        return 0.0

    var previous_weight = player_weight_lbs
    daily_calories_used += calorie_delta
    daily_calories_used_changed.emit(daily_calories_used)

    var weight_shift = calorie_delta / CALORIES_PER_POUND
    var new_weight = max(previous_weight - weight_shift, 0.0)
    _update_weight(new_weight)
    return player_weight_lbs - previous_weight

func _update_weight(new_weight_lbs: float):
    new_weight_lbs = max(new_weight_lbs, 0.0)
    if is_equal_approx(new_weight_lbs, player_weight_lbs):
        return

    player_weight_lbs = new_weight_lbs
    weight_changed.emit(player_weight_lbs)

    var new_category = _determine_weight_category(player_weight_lbs)
    if new_category != _current_weight_category:
        _current_weight_category = new_category
        weight_category_changed.emit(_current_weight_category)
        print("⚖️ Weight category -> %s" % _current_weight_category)

func _determine_weight_category(weight_lbs: float) -> String:
    if weight_lbs <= MALNOURISHED_MAX_LBS:
        return "malnourished"
    if weight_lbs >= OVERWEIGHT_MIN_LBS:
        return "overweight"
    return "average"
