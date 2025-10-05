extends RefCounted
class_name WeatherSystem

const MINUTES_PER_HOUR: int = 60
const RAIN_START_CHANCE: float = 0.05
const HEAVY_STORM_CHANCE: float = 0.15
const RAINING_CHANCE: float = 0.35
const SPRINKLING_CHANCE: float = 0.50

const WEATHER_CLEAR := "clear"
const WEATHER_SPRINKLING := "sprinkling"
const WEATHER_RAINING := "raining"
const WEATHER_HEAVY_STORM := "heavy_storm"

const WEATHER_LABELS := {
    WEATHER_CLEAR: "Clear Skies",
    WEATHER_SPRINKLING: "Sprinkling",
    WEATHER_RAINING: "Raining",
    WEATHER_HEAVY_STORM: "Heavy Storm"
}

const WEATHER_MULTIPLIERS := {
    WEATHER_CLEAR: 1.0,
    WEATHER_SPRINKLING: 1.25,
    WEATHER_RAINING: 1.5,
    WEATHER_HEAVY_STORM: 1.75
}

const WEATHER_DEFAULT_DURATIONS := {
    WEATHER_SPRINKLING: 1,
    WEATHER_RAINING: 2,
    WEATHER_HEAVY_STORM: 5
}

signal weather_changed(new_state: String, previous_state: String, hours_remaining: int)

var _current_state: String = WEATHER_CLEAR
var _hour_timer: int = 0
var _minute_accumulator: int = 0
var _rng: RandomNumberGenerator

func _init():
    _rng = RandomNumberGenerator.new()
    _rng.randomize()
    print("☁️ WeatherSystem ready: %s" % _format_state_debug())

func initialize_clock_offset(minutes_since_daybreak: int):
    _minute_accumulator = posmod(minutes_since_daybreak, MINUTES_PER_HOUR)

func on_time_advanced(minutes: int, _rolled_over: bool = false):
    minutes = max(minutes, 0)
    if minutes == 0:
        return

    _minute_accumulator += minutes
    while _minute_accumulator >= MINUTES_PER_HOUR:
        _minute_accumulator -= MINUTES_PER_HOUR
        _process_hour_tick()

func on_day_rolled_over():
    # Hourly countdown already handles duration reductions; reset minute accumulator for the new dawn.
    _minute_accumulator = 0

func get_state() -> String:
    return _current_state

func get_hours_remaining() -> int:
    return max(_hour_timer, 0)

func get_activity_multiplier() -> float:
    return WEATHER_MULTIPLIERS.get(_current_state, 1.0)

func get_state_display_name() -> String:
    return get_state_display_name_for(_current_state)

func get_state_display_name_for(state: String) -> String:
    return WEATHER_LABELS.get(state, state.capitalize())

func get_multiplier_for_state(state: String) -> float:
    return WEATHER_MULTIPLIERS.get(state, 1.0)

func is_precipitating() -> bool:
    return is_precipitating_state(_current_state)

func is_precipitating_state(state: String) -> bool:
    return state != WEATHER_CLEAR

func broadcast_state():
    weather_changed.emit(_current_state, _current_state, get_hours_remaining())

func _process_hour_tick():
    if is_precipitating():
        _hour_timer = max(_hour_timer - 1, 0)
        if _hour_timer == 0:
            _set_state(WEATHER_CLEAR, 0)
            return

    if _current_state == WEATHER_CLEAR:
        var roll = _rng.randf()
        if roll < RAIN_START_CHANCE:
            _begin_precipitation()

func _begin_precipitation():
    var total_weight = HEAVY_STORM_CHANCE + RAINING_CHANCE + SPRINKLING_CHANCE
    if total_weight <= 0.0:
        total_weight = 1.0
    var intensity_roll = _rng.randf() * total_weight
    var heavy_threshold = HEAVY_STORM_CHANCE
    var rain_threshold = heavy_threshold + RAINING_CHANCE

    var new_state = WEATHER_SPRINKLING
    if intensity_roll < heavy_threshold:
        new_state = WEATHER_HEAVY_STORM
    elif intensity_roll < rain_threshold:
        new_state = WEATHER_RAINING
    else:
        new_state = WEATHER_SPRINKLING

    var duration = WEATHER_DEFAULT_DURATIONS.get(new_state, 1)
    _set_state(new_state, duration)

func _set_state(new_state: String, duration_hours: int):
    var previous_state = _current_state
    _current_state = new_state
    _hour_timer = max(duration_hours, 0)
    weather_changed.emit(_current_state, previous_state, get_hours_remaining())
    print("🌦️ Weather -> %s" % _format_state_debug())

func _format_state_debug() -> String:
    var label = get_state_display_name()
    var multiplier = get_activity_multiplier()
    var hours_left = get_hours_remaining()
    if is_precipitating() and hours_left > 0:
        return "%s (x%.2f, %dh left)" % [label, multiplier, hours_left]
    return "%s (x%.2f)" % [label, multiplier]
