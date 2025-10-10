# PlayerHealthSystem.gd overview:
# - Purpose: manage survivor health percentage, surface injury/heal signals, and clamp mutations to safe bounds.
# - Sections: constants store limits, state tracks current health, helpers apply damage/heals and expose ratios for UI.
extends RefCounted
class_name PlayerHealthSystem

const MIN_HEALTH: float = 0.0
const MAX_HEALTH: float = 100.0
const DEFAULT_HEALTH: float = 100.0

signal health_changed(new_health: float, previous_health: float)
signal damaged(amount: float, source: String, new_health: float)
signal healed(amount: float, source: String, new_health: float)

var _current_health: float = DEFAULT_HEALTH

func get_health() -> float:
    """Absolute health value (0-100)."""
    return _current_health

func get_max_health() -> float:
    return MAX_HEALTH

func get_health_ratio() -> float:
    if MAX_HEALTH <= 0.0:
        return 0.0
    return clamp(_current_health / MAX_HEALTH, 0.0, 1.0)

func get_health_percent() -> float:
    return get_health_ratio() * 100.0

func set_health(value: float) -> float:
    var clamped = clamp(value, MIN_HEALTH, MAX_HEALTH)
    if is_equal_approx(clamped, _current_health):
        return _current_health
    var previous = _current_health
    _current_health = clamped
    health_changed.emit(_current_health, previous)
    if _current_health > previous:
        healed.emit(_current_health - previous, "set", _current_health)
    elif _current_health < previous:
        damaged.emit(previous - _current_health, "set", _current_health)
    return _current_health

func apply_damage(amount: float, source: String = "") -> Dictionary:
    amount = max(amount, 0.0)
    if amount <= 0.0:
        return {
            "applied": 0.0,
            "new_health": _current_health,
            "source": source
        }
    var previous = _current_health
    _current_health = max(previous - amount, MIN_HEALTH)
    var applied = previous - _current_health
    if applied <= 0.0:
        return {
            "applied": 0.0,
            "new_health": _current_health,
            "source": source
        }
    health_changed.emit(_current_health, previous)
    damaged.emit(applied, source, _current_health)
    return {
        "applied": applied,
        "new_health": _current_health,
        "source": source
    }

func apply_heal(amount: float, source: String = "") -> Dictionary:
    amount = max(amount, 0.0)
    if amount <= 0.0:
        return {
            "applied": 0.0,
            "new_health": _current_health,
            "source": source
        }
    var previous = _current_health
    _current_health = clamp(previous + amount, MIN_HEALTH, MAX_HEALTH)
    var applied = _current_health - previous
    if applied <= 0.0:
        return {
            "applied": 0.0,
            "new_health": _current_health,
            "source": source
        }
    health_changed.emit(_current_health, previous)
    healed.emit(applied, source, _current_health)
    return {
        "applied": applied,
        "new_health": _current_health,
        "source": source
    }

func is_alive() -> bool:
    return _current_health > MIN_HEALTH
