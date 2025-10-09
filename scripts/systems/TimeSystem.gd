# TimeSystem.gd overview:
# - Purpose: advance the in-game clock, emit daybreak events, and provide formatted time helpers.
# - Sections: constants define day length, signals announce changes, advance_minutes/_format_minutes handle core math.
extends RefCounted
class_name TimeSystem

const MINUTES_PER_DAY: int = 24 * 60
const DAY_START_MINUTE: int = 6 * 60

signal time_advanced(minutes: int, crossed_daybreak: bool)
signal day_rolled_over()

var minutes_since_daybreak: int = 0

func _init():
    print("🕒 TimeSystem ready at %s" % get_formatted_time())

func get_minutes_since_daybreak() -> int:
    """Elapsed minutes since the current day's 06:00 start."""
    return minutes_since_daybreak

func get_minutes_until_daybreak() -> int:
    """Minutes remaining until the next 06:00 rollover."""
    if minutes_since_daybreak == 0:
        return MINUTES_PER_DAY
    return MINUTES_PER_DAY - minutes_since_daybreak

func get_minutes_since_midnight() -> int:
    """Return absolute minutes since midnight for the current clock."""
    return (DAY_START_MINUTE + minutes_since_daybreak) % MINUTES_PER_DAY

func get_formatted_time() -> String:
    """Current clock time in 12-hour format with AM/PM."""
    return _format_minutes(get_minutes_since_midnight())

func get_formatted_time_after(minutes_ahead: int) -> String:
    """Clock text after advancing the requested minutes (non-destructive)."""
    minutes_ahead = max(minutes_ahead, 0)
    var preview_total = (minutes_since_daybreak + minutes_ahead) % MINUTES_PER_DAY
    var preview_clock = (DAY_START_MINUTE + preview_total) % MINUTES_PER_DAY
    return _format_minutes(preview_clock)

func advance_minutes(duration_minutes: int) -> Dictionary:
    """Advance time by a positive minute count and emit rollover events."""
    duration_minutes = max(duration_minutes, 0)
    var result := {
        "requested_minutes": duration_minutes,
        "minutes_applied": duration_minutes,
        "rolled_over": false,
        "daybreaks_crossed": 0,
        "previous_minutes_since_daybreak": minutes_since_daybreak,
        "current_minutes_since_daybreak": minutes_since_daybreak,
        "overflow_minutes": 0
    }

    if duration_minutes == 0:
        result["minutes_until_daybreak"] = get_minutes_until_daybreak()
        result["current_clock_text"] = get_formatted_time()
        return result

    var total_minutes = minutes_since_daybreak + duration_minutes
    var daybreaks_crossed = int(total_minutes / MINUTES_PER_DAY)
    minutes_since_daybreak = total_minutes % MINUTES_PER_DAY

    result["daybreaks_crossed"] = daybreaks_crossed
    result["current_minutes_since_daybreak"] = minutes_since_daybreak
    result["overflow_minutes"] = minutes_since_daybreak

    if daybreaks_crossed > 0:
        result["rolled_over"] = true
        for _i in range(daybreaks_crossed):
            day_rolled_over.emit()

    time_advanced.emit(duration_minutes, result["rolled_over"])
    result["minutes_until_daybreak"] = get_minutes_until_daybreak()
    result["current_clock_text"] = get_formatted_time()
    print("⏱️ Advanced %d minute(s) -> %s" % [duration_minutes, get_formatted_time()])

    return result

func _format_minutes(total_minutes: int) -> String:
    var hour_24 = total_minutes / 60
    var minute = total_minutes % 60
    var is_pm = hour_24 >= 12
    var suffix = "PM" if is_pm else "AM"
    var hour_12 = hour_24 % 12
    if hour_12 == 0:
        hour_12 = 12
    return "%d:%02d %s" % [hour_12, minute, suffix]
