extends RefCounted
class_name TowerHealthSystem

const WeatherSystem = preload("res://scripts/systems/WeatherSystem.gd")

signal tower_health_changed(new_health: float, previous_health: float)
signal tower_damaged(amount: float, source: String)
signal tower_repaired(amount: float, source: String)

const BASE_MAX_HEALTH: float = 100.0
const REINFORCED_MAX_HEALTH: float = 150.0
const MIN_HEALTH: float = 0.0
const DAILY_DRY_DAMAGE: float = 5.0
const REPAIR_HEALTH_PER_ACTION: float = 5.0

const RAIN_DAMAGE_PER_HOUR := {
    WeatherSystem.WEATHER_SPRINKLING: 1.0,
    WeatherSystem.WEATHER_RAINING: 2.0,
    WeatherSystem.WEATHER_HEAVY_STORM: 3.0
}

var _current_health: float = BASE_MAX_HEALTH
var _reinforced_cap: float = BASE_MAX_HEALTH
var _had_precipitation_today: bool = false

func _init():
    print("🛡️ TowerHealthSystem ready (health %.0f/%.0f)" % [_current_health, BASE_MAX_HEALTH])

func get_health() -> float:
    return _current_health

func get_max_health() -> float:
    return _reinforced_cap

func get_base_max_health() -> float:
    return BASE_MAX_HEALTH

func get_health_ratio() -> float:
    var cap = max(get_max_health(), 0.0001)
    return clamp(_current_health / cap, 0.0, 1.0)

func is_at_max_health() -> bool:
    return _current_health >= _reinforced_cap - 0.001

func is_at_reinforced_cap() -> bool:
    return _current_health >= REINFORCED_MAX_HEALTH - 0.001

func is_at_repair_cap() -> bool:
    return _current_health >= BASE_MAX_HEALTH - 0.001

func set_initial_weather_state(state: String):
    _had_precipitation_today = _is_precipitating_state(state)

func register_weather_hour(state: String):
    if _is_precipitating_state(state):
        _had_precipitation_today = true
        var damage = RAIN_DAMAGE_PER_HOUR.get(state, 0.0)
        if damage > 0.0:
            apply_damage(damage, "weather_%s" % state)

func on_day_completed(current_state: String):
    if !_had_precipitation_today:
        apply_damage(DAILY_DRY_DAMAGE, "dry_day")
    _had_precipitation_today = _is_precipitating_state(current_state)

func apply_damage(amount: float, source: String = "unknown") -> float:
    amount = max(amount, 0.0)
    if amount <= 0.0:
        return _current_health
    var previous = _current_health
    _current_health = max(_current_health - amount, MIN_HEALTH)
    var actual_damage: float = previous - _current_health
    if actual_damage <= 0.0:
        return _current_health
    tower_health_changed.emit(_current_health, previous)
    tower_damaged.emit(actual_damage, source)
    print("🏚️ Tower damaged %.1f (%s) -> %.1f/%.1f" % [actual_damage, source, _current_health, _reinforced_cap])
    return _current_health

func apply_repair(amount: float, source: String = "unknown", materials: Dictionary = {}) -> float:
    amount = max(amount, 0.0)
    if amount <= 0.0:
        return _current_health
    var previous = _current_health
    var repair_cap = min(_reinforced_cap, BASE_MAX_HEALTH)
    if previous < repair_cap:
        _current_health = clamp(previous + amount, MIN_HEALTH, repair_cap)
    else:
        _current_health = previous
    var actual_repair: float = _current_health - previous
    if actual_repair <= 0.0:
        return _current_health
    tower_health_changed.emit(_current_health, previous)
    tower_repaired.emit(actual_repair, source)
    print("🛠️ Tower repaired %.1f (%s) -> %.1f/%.1f" % [actual_repair, source, _current_health, _reinforced_cap])
    return _current_health

func apply_reinforcement(amount: float, source: String = "reinforce", materials: Dictionary = {}) -> float:
    amount = max(amount, 0.0)
    if amount <= 0.0:
        return _current_health
    var previous = _current_health
    _reinforced_cap = max(_reinforced_cap, REINFORCED_MAX_HEALTH)
    _current_health = clamp(_current_health + amount, MIN_HEALTH, _reinforced_cap)
    var actual_repair: float = _current_health - previous
    if actual_repair <= 0.0:
        return _current_health
    tower_health_changed.emit(_current_health, previous)
    tower_repaired.emit(actual_repair, source)
    print("🧱 Tower reinforced %.1f (%s) -> %.1f/%.1f" % [actual_repair, source, _current_health, _reinforced_cap])
    return _current_health


func _is_precipitating_state(state: String) -> bool:
    return state != WeatherSystem.WEATHER_CLEAR
