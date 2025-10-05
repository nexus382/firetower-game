extends RefCounted
class_name SleepSystem

# Sleep configuration
const MIN_SLEEP_PERCENT: float = 0.0
const MAX_SLEEP_PERCENT: float = 100.0
const SLEEP_PERCENT_PER_HOUR: float = 10.0
const CALORIES_PER_SLEEP_HOUR: int = 100

# Signals for UI bindings
signal sleep_percent_changed(new_percent: float)
signal daily_calories_used_changed(new_total: int)

# Internal state
var sleep_percent: float = 75.0
var daily_calories_used: int = 0

func _init():
    print("😴 SleepSystem ready with %.0f%% rest" % sleep_percent)

func get_sleep_percent() -> float:
    """Current tired meter value (0-100%)."""
    return sleep_percent

func get_daily_calories_used() -> int:
    """Calories burned today from all activities."""
    return daily_calories_used

func apply_sleep(hours: int) -> Dictionary:
    """Increase rest by scheduled sleep hours and track calorie burn."""
    hours = max(hours, 0)
    if hours == 0:
        return {
            "hours": 0,
            "percent_gained": 0.0,
            "new_percent": sleep_percent,
            "calories_used": 0
        }

    var gained_percent = hours * SLEEP_PERCENT_PER_HOUR
    var previous_percent = sleep_percent
    sleep_percent = clamp(previous_percent + gained_percent, MIN_SLEEP_PERCENT, MAX_SLEEP_PERCENT)
    var actual_gain = sleep_percent - previous_percent

    var calories_spent = hours * CALORIES_PER_SLEEP_HOUR
    daily_calories_used += calories_spent

    sleep_percent_changed.emit(sleep_percent)
    daily_calories_used_changed.emit(daily_calories_used)

    print("🛌 Slept %d hour(s): +%.0f%% rest, %.0f%% total" % [hours, actual_gain, sleep_percent])
    print("🔥 Daily calories used: %d" % daily_calories_used)

    return {
        "hours": hours,
        "percent_gained": actual_gain,
        "new_percent": sleep_percent,
        "calories_used": calories_spent
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

func adjust_daily_calories(calorie_delta: int) -> int:
    """Apply external calorie changes (e.g. meals) to the daily total."""
    daily_calories_used += calorie_delta
    daily_calories_used_changed.emit(daily_calories_used)
    print("📊 Daily calorie delta adjusted by %d (total: %d)" % [calorie_delta, daily_calories_used])
    return daily_calories_used

func reset_daily_counters():
    """Clear daily tracking at day rollover."""
    daily_calories_used = 0
    daily_calories_used_changed.emit(daily_calories_used)
    print("🔄 Daily calorie usage reset")
