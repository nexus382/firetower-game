# WolfSystem.gd overview:
# - Purpose: schedule daily wolf encounters, track active packs, and share forecast/status data with other systems.
# - Sections: constants define spawn math, lifecycle handles day resets and time advancement, helpers expose state & resolve lure rolls.
extends RefCounted
class_name WolfSystem

signal wolves_state_changed(state: Dictionary)

const MINUTES_PER_DAY: int = 24 * 60
const DAILY_APPEAR_CHANCE: float = 0.15
const MIN_DURATION_MINUTES: int = 60
const MAX_DURATION_MINUTES: int = 5 * 60

var _current_day: int = 1
var _pending_event: Dictionary = {}
var _state: Dictionary = {
    "active": false,
    "present": false,
    "day": 1,
    "arrived_minute": -1,
    "depart_minute": -1,
    "minutes_remaining": 0,
    "duration": 0,
    "scheduled_minute": -1,
    "scheduled_duration": 0,
    "last_reason": ""
}
var _last_minute_stamp: int = 0

func _init():
    print("🐺 WolfSystem ready")

func start_day(day_index: int, rng: RandomNumberGenerator) -> Dictionary:
    _current_day = day_index
    _last_minute_stamp = 0
    _pending_event = {}
    _state["day"] = day_index
    _state["scheduled_minute"] = -1
    _state["scheduled_duration"] = 0
    if _state.get("active", false) or _state.get("present", false):
        _state["active"] = false
        _state["present"] = false
        _state["arrived_minute"] = -1
        _state["depart_minute"] = -1
        _state["minutes_remaining"] = 0
        _state["duration"] = 0
        _state["last_reason"] = "day_rollover"
    var roll = rng.randf() if rng else 1.0
    var scheduled: Dictionary = {}
    if rng != null and roll < DAILY_APPEAR_CHANCE:
        var duration = rng.randi_range(MIN_DURATION_MINUTES, MAX_DURATION_MINUTES)
        var latest_start = max(MINUTES_PER_DAY - duration, 0)
        var minute = rng.randi_range(0, latest_start)
        scheduled = {
            "day": day_index,
            "minute": minute,
            "duration": duration,
            "end_minute": minute + duration
        }
        _pending_event = scheduled.duplicate(true)
        _state["scheduled_minute"] = minute
        _state["scheduled_duration"] = duration
        _state["last_reason"] = "scheduled"
    else:
        _pending_event = {}
    _emit_state()
    return {
        "day": day_index,
        "chance": DAILY_APPEAR_CHANCE,
        "roll": roll,
        "scheduled": scheduled.duplicate(true)
    }

func advance_time(minutes: int, current_minutes_since_daybreak: int, rolled_over: bool) -> Dictionary:
    minutes = max(minutes, 0)
    var previous_stamp = _last_minute_stamp
    _last_minute_stamp = current_minutes_since_daybreak
    var report: Dictionary = {}

    if !_state.get("active", false) and !_pending_event.is_empty():
        var arrival_minute = int(_pending_event.get("minute", -1))
        if arrival_minute >= 0 and _did_cross_marker(previous_stamp, current_minutes_since_daybreak, arrival_minute, rolled_over):
            report["arrived"] = _activate_wolves(arrival_minute, current_minutes_since_daybreak)
    if _state.get("active", false):
        var depart_minute = int(_state.get("depart_minute", -1))
        var remaining = max(depart_minute - current_minutes_since_daybreak, 0)
        if remaining <= 0:
            report["departed"] = _deactivate_wolves("timed_out")
        else:
            if !is_equal_approx(float(remaining), float(_state.get("minutes_remaining", remaining))):
                _state["minutes_remaining"] = remaining
                _emit_state()
    return report

func has_active_wolves() -> bool:
    return _state.get("active", false)

func get_state() -> Dictionary:
    return _state.duplicate(true)

func get_pending_event() -> Dictionary:
    return _pending_event.duplicate(true)

func clear_wolves(reason: String = "cleared") -> Dictionary:
    if !_state.get("active", false) and !_state.get("present", false):
        _state["last_reason"] = reason
        _emit_state()
        return {
            "success": false,
            "reason": "no_wolves"
        }
    return _deactivate_wolves(reason)

func attempt_lure(chance: float, rng: RandomNumberGenerator) -> Dictionary:
    var normalized = clamp(chance, 0.0, 1.0)
    if !_state.get("active", false):
        return {
            "success": false,
            "reason": "no_wolves",
            "chance": normalized,
            "roll": 1.0
        }
    if rng == null or normalized <= 0.0:
        return {
            "success": false,
            "reason": "chance_blocked",
            "chance": normalized,
            "roll": 1.0
        }
    var roll = rng.randf()
    var success = roll < normalized
    if success:
        _deactivate_wolves("lured")
    return {
        "success": success,
        "reason": "lured" if success else "wolves_stayed",
        "chance": normalized,
        "roll": roll
    }

func forecast_activity(hours_ahead: int, current_minutes_since_daybreak: int) -> Dictionary:
    var horizon_minutes = max(hours_ahead, 0) * 60
    var events: Array = []
    if !_pending_event.is_empty():
        var arrival_minute = int(_pending_event.get("minute", -1))
        if arrival_minute >= 0:
            var minutes_ahead = arrival_minute - current_minutes_since_daybreak
            if minutes_ahead < 0:
                minutes_ahead = 0
            if horizon_minutes <= 0 or minutes_ahead <= horizon_minutes:
                var entry = _pending_event.duplicate(true)
                entry["type"] = "arrival"
                entry["minutes_ahead"] = minutes_ahead
                events.append(entry)
    if _state.get("active", false):
        var remaining = int(_state.get("minutes_remaining", 0))
        var active_entry = {
            "type": "active",
            "minutes_remaining": max(remaining, 0),
            "depart_minute": int(_state.get("depart_minute", -1)),
            "arrived_minute": int(_state.get("arrived_minute", -1))
        }
        events.append(active_entry)
    return {
        "day": _current_day,
        "events": events
    }

func _activate_wolves(arrival_minute: int, current_minutes_since_daybreak: int) -> Dictionary:
    var duration = int(_pending_event.get("duration", _state.get("scheduled_duration", MIN_DURATION_MINUTES)))
    var depart_minute = arrival_minute + duration
    _pending_event = {}
    _state["active"] = true
    _state["present"] = true
    _state["arrived_minute"] = arrival_minute
    _state["depart_minute"] = depart_minute
    _state["duration"] = duration
    _state["minutes_remaining"] = max(depart_minute - current_minutes_since_daybreak, 0)
    _state["last_reason"] = "arrived"
    _emit_state()
    return get_state()

func _deactivate_wolves(reason: String) -> Dictionary:
    _state["active"] = false
    _state["present"] = false
    _state["minutes_remaining"] = 0
    _state["arrived_minute"] = -1
    _state["depart_minute"] = -1
    _state["duration"] = 0
    _state["last_reason"] = reason
    _emit_state()
    return {
        "success": true,
        "reason": reason
    }

func _did_cross_marker(previous: int, current: int, marker: int, rolled_over: bool) -> bool:
    if marker < 0:
        return false
    if rolled_over:
        return current >= marker or previous <= marker
    if previous <= marker:
        return current >= marker
    return false

func _emit_state():
    wolves_state_changed.emit(_state.duplicate(true))
