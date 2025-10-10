# WarmthSystem.gd overview:
# - Purpose: track ambient warmth, apply hourly temperature drift, and broadcast changes for HUD widgets.
# - Sections: constants define bounds/rates, state stores warmth, helpers convert times to rates and apply deltas.
extends RefCounted
class_name WarmthSystem

const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")

const MIN_WARMTH: float = 0.0
const MAX_WARMTH: float = 100.0
const DEFAULT_WARMTH: float = 65.0
const FLASHLIGHT_WARMTH_BONUS: float = 0.0 # reserved for future synergy hooks

const RATE_EARLY_MORNING: float = -3.0
const RATE_DAYTIME: float = 5.0
const RATE_EVENING: float = -3.0
const RATE_NIGHT: float = -10.0

signal warmth_changed(new_warmth: float, previous_warmth: float)

var _current_warmth: float = DEFAULT_WARMTH

func get_warmth() -> float:
    """Raw warmth value clamped between MIN_WARMTH and MAX_WARMTH."""
    return _current_warmth

func get_warmth_percent() -> float:
    return clamp(_current_warmth, MIN_WARMTH, MAX_WARMTH)

func set_warmth(value: float) -> float:
    var clamped = clamp(value, MIN_WARMTH, MAX_WARMTH)
    if is_equal_approx(clamped, _current_warmth):
        return _current_warmth
    var previous = _current_warmth
    _current_warmth = clamped
    warmth_changed.emit(_current_warmth, previous)
    return _current_warmth

func apply_warmth_delta(delta: float) -> float:
    if is_zero_approx(delta):
        return _current_warmth
    return set_warmth(_current_warmth + delta)

func apply_environment_minutes(minutes: int, start_minutes_since_daybreak: int, is_sleeping: bool) -> Dictionary:
    minutes = max(minutes, 0)
    if minutes == 0:
        return {
            "minutes": 0,
            "delta": 0.0,
            "new_warmth": _current_warmth,
            "previous_warmth": _current_warmth,
            "sleeping": is_sleeping
        }

    var remaining = minutes
    var minute_cursor = start_minutes_since_daybreak % TimeSystem.MINUTES_PER_DAY
    if minute_cursor < 0:
        minute_cursor += TimeSystem.MINUTES_PER_DAY
    var accumulated_delta = 0.0

    while remaining > 0:
        var absolute_minute = (TimeSystem.DAY_START_MINUTE + minute_cursor) % TimeSystem.MINUTES_PER_DAY
        var minutes_into_hour = absolute_minute % 60
        var slice = min(remaining, 60 - minutes_into_hour if minutes_into_hour != 0 else 60)
        var hourly_rate = _resolve_hourly_rate(absolute_minute)
        if is_sleeping and hourly_rate < 0.0:
            hourly_rate = 0.0
        var step_delta = hourly_rate * (float(slice) / 60.0)
        accumulated_delta += step_delta
        minute_cursor = (minute_cursor + slice) % TimeSystem.MINUTES_PER_DAY
        remaining -= slice

    var previous = _current_warmth
    var new_value = clamp(previous + accumulated_delta, MIN_WARMTH, MAX_WARMTH)
    _current_warmth = new_value
    if !is_equal_approx(new_value, previous):
        warmth_changed.emit(_current_warmth, previous)

    return {
        "minutes": minutes,
        "delta": accumulated_delta,
        "new_warmth": _current_warmth,
        "previous_warmth": previous,
        "sleeping": is_sleeping
    }

func preview_hourly_rate(minute_of_day: int) -> float:
    return _resolve_hourly_rate((minute_of_day % TimeSystem.MINUTES_PER_DAY + TimeSystem.MINUTES_PER_DAY) % TimeSystem.MINUTES_PER_DAY)

func _resolve_hourly_rate(minute_of_day: int) -> float:
    var hour = int(floor(float(minute_of_day) / 60.0))
    if hour >= 6 and hour < 11:
        return RATE_EARLY_MORNING
    if hour >= 11 and hour < 18:
        return RATE_DAYTIME
    if hour >= 18 and hour < 22:
        return RATE_EVENING
    return RATE_NIGHT
