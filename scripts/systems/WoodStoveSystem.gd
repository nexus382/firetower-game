# WoodStoveSystem.gd overview:
# - Purpose: track stove fuel, minutes of heat, and apply warmth bonuses when flames stay lit.
# - Sections: constants describe log runtime and warmth gains, state stores logs/minutes, helpers mutate fuel and expose snapshots.
extends RefCounted
class_name WoodStoveSystem

const WarmthSystem = preload("res://scripts/systems/WarmthSystem.gd")

const MINUTES_PER_LOG: int = 240  # 4 in-game hours per log.
const MAX_LOGS_LOADED: int = 6    # Keep chamber manageable and UI readable.
const WARMTH_BONUS_PER_HOUR: float = 8.0

signal stove_state_changed(state: Dictionary)

var _logs_loaded: int = 0
var _burn_minutes_remaining: float = 0.0
var _lit: bool = false

func reset():
    _logs_loaded = 0
    _burn_minutes_remaining = 0.0
    _lit = false
    stove_state_changed.emit(get_state())

func get_state() -> Dictionary:
    var hours_remaining = _burn_minutes_remaining / 60.0
    return {
        "logs_loaded": max(_logs_loaded, 0),
        "burn_minutes_remaining": max(_burn_minutes_remaining, 0.0),
        "burn_hours_remaining": max(hours_remaining, 0.0),
        "lit": _lit and _burn_minutes_remaining > 0.0,
        "capacity_remaining": max(MAX_LOGS_LOADED - max(_logs_loaded, 0), 0),
        "minutes_per_log": MINUTES_PER_LOG,
        "warmth_per_hour": WARMTH_BONUS_PER_HOUR,
        "max_logs": MAX_LOGS_LOADED
    }

func get_logs_loaded() -> int:
    return max(_logs_loaded, 0)

func is_lit() -> bool:
    return _lit and _burn_minutes_remaining > 0.0

func add_logs(amount: int) -> Dictionary:
    var accepted = min(max(amount, 0), get_capacity_remaining())
    if accepted <= 0:
        return {
            "accepted": 0,
            "state": get_state(),
            "reason": "no_capacity"
        }
    _logs_loaded += accepted
    _burn_minutes_remaining += float(accepted * MINUTES_PER_LOG)
    var state = get_state()
    stove_state_changed.emit(state)
    return {
        "accepted": accepted,
        "state": state
    }

func ignite() -> Dictionary:
    if is_lit():
        return {
            "success": false,
            "reason": "already_lit",
            "state": get_state()
        }
    if _burn_minutes_remaining <= 0.0:
        return {
            "success": false,
            "reason": "no_fuel",
            "state": get_state()
        }
    _lit = true
    var state = get_state()
    stove_state_changed.emit(state)
    return {
        "success": true,
        "state": state
    }

func extinguish() -> Dictionary:
    if !_lit:
        return {
            "success": false,
            "reason": "already_out",
            "state": get_state()
        }
    _lit = false
    var state = get_state()
    stove_state_changed.emit(state)
    return {
        "success": true,
        "state": state
    }

func advance_minutes(minutes: int, warmth_system: WarmthSystem) -> Dictionary:
    minutes = max(minutes, 0)
    if minutes == 0:
        return {
            "minutes_processed": 0,
            "minutes_burning": 0,
            "warmth_delta": 0.0,
            "state": get_state()
        }

    var minutes_burning = 0
    var warmth_delta = 0.0
    if is_lit():
        minutes_burning = min(minutes, int(ceil(_burn_minutes_remaining)))
        _burn_minutes_remaining = max(_burn_minutes_remaining - minutes_burning, 0.0)
        if minutes_burning > 0:
            warmth_delta = WARMTH_BONUS_PER_HOUR * (float(minutes_burning) / 60.0)
            if warmth_system != null and !is_zero_approx(warmth_delta):
                warmth_system.apply_warmth_delta(warmth_delta)
        if _burn_minutes_remaining <= 0.0:
            _burn_minutes_remaining = 0.0
            _lit = false

    _logs_loaded = int(ceil(_burn_minutes_remaining / MINUTES_PER_LOG)) if _burn_minutes_remaining > 0.0 else 0
    var state = get_state()
    stove_state_changed.emit(state)
    return {
        "minutes_processed": minutes,
        "minutes_burning": minutes_burning,
        "warmth_delta": warmth_delta,
        "state": state
    }

func get_capacity_remaining() -> int:
    return max(MAX_LOGS_LOADED - max(_logs_loaded, 0), 0)
