extends RefCounted
class_name TimeSystem

const MINUTES_PER_DAY: int = 1440
const DAY_START_MINUTES: int = 360  # 6:00 AM baseline
const MIN_DIFFICULTY_MULTIPLIER: float = 0.1

signal time_changed(formatted_time: String)
signal day_rolled_over(new_day: int)

var current_day_index: int = 1
var minutes_since_day_start: int = 0
var difficulty_multiplier: float = 1.0

func _init():
    minutes_since_day_start = 0
    print("🕒 TimeSystem ready at %s" % get_formatted_time())

func set_difficulty_multiplier(value: float):
    difficulty_multiplier = max(value, MIN_DIFFICULTY_MULTIPLIER)
    print("🎚️ Difficulty multiplier set to %.2f" % difficulty_multiplier)

func get_difficulty_multiplier() -> float:
    return difficulty_multiplier

func get_current_day() -> int:
    return current_day_index

func get_formatted_time() -> String:
    return _format_minutes(minutes_since_day_start)

func get_minutes_until_day_reset() -> int:
    return MINUTES_PER_DAY - minutes_since_day_start

func calculate_effective_minutes(base_minutes: int, weight_factor: float = 1.0, difficulty_override: float = -1.0) -> int:
    if base_minutes <= 0:
        return 0
    var difficulty := difficulty_multiplier if difficulty_override <= 0.0 else max(difficulty_override, MIN_DIFFICULTY_MULTIPLIER)
    var effective := int(round(base_minutes * max(weight_factor, 0.0) * difficulty))
    return max(effective, 1)

func preview_minutes(base_minutes: int, weight_factor: float = 1.0, difficulty_override: float = -1.0) -> Dictionary:
    var effective := calculate_effective_minutes(base_minutes, weight_factor, difficulty_override)
    if effective == 0:
        return {
            "base_minutes": 0,
            "effective_minutes": 0,
            "rolled_days": 0,
            "result_day": current_day_index,
            "result_time": get_formatted_time()
        }

    var temp_minutes := minutes_since_day_start + effective
    var rolled_days := temp_minutes / MINUTES_PER_DAY
    var result_minutes_since_start := temp_minutes % MINUTES_PER_DAY
    var result_day := current_day_index + rolled_days

    return {
        "base_minutes": base_minutes,
        "effective_minutes": effective,
        "rolled_days": rolled_days,
        "result_day": result_day,
        "result_time": _format_minutes(result_minutes_since_start)
    }

func advance_minutes(base_minutes: int, weight_factor: float = 1.0, difficulty_override: float = -1.0) -> Dictionary:
    var effective := calculate_effective_minutes(base_minutes, weight_factor, difficulty_override)
    if effective == 0:
        return {
            "base_minutes": 0,
            "effective_minutes": 0,
            "rolled_days": 0,
            "result_day": current_day_index,
            "result_time": get_formatted_time()
        }

    var rolled_days := 0
    var remaining := effective
    while remaining > 0:
        var minutes_until_roll := MINUTES_PER_DAY - minutes_since_day_start
        if remaining < minutes_until_roll:
            minutes_since_day_start += remaining
            remaining = 0
        else:
            remaining -= minutes_until_roll
            minutes_since_day_start = 0
            rolled_days += 1
            current_day_index += 1
            day_rolled_over.emit(current_day_index)
            print("📅 New day: %d at 6:00 AM" % current_day_index)

    var formatted := get_formatted_time()
    time_changed.emit(formatted)

    return {
        "base_minutes": base_minutes,
        "effective_minutes": effective,
        "rolled_days": rolled_days,
        "result_day": current_day_index,
        "result_time": formatted
    }

func advance_hours(hours: float, weight_factor: float = 1.0, difficulty_override: float = -1.0) -> Dictionary:
    var base_minutes := int(round(hours * 60.0))
    return advance_minutes(base_minutes, weight_factor, difficulty_override)

func _format_minutes(minutes_since_start: int) -> String:
    minutes_since_start = clamp(minutes_since_start, 0, MINUTES_PER_DAY - 1)
    var absolute_minutes := (DAY_START_MINUTES + minutes_since_start) % MINUTES_PER_DAY
    var hour_24 := absolute_minutes / 60
    var minute := absolute_minutes % 60
    var meridiem := "AM" if hour_24 < 12 else "PM"
    var display_hour := hour_24 % 12
    if display_hour == 0:
        display_hour = 12
    return "%02d:%02d %s" % [display_hour, minute, meridiem]
