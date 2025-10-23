# ExpeditionSystem.gd overview:
# - Purpose: manage checkpoint progression, travel option draws, and selection state for the overland expedition.
# - Sections: constants define deck ranges, signals broadcast updates, helpers build options, selection/commit advance progress.
extends RefCounted
class_name ExpeditionSystem

signal expedition_state_changed(state: Dictionary)

const TOTAL_CHECKPOINTS: int = 8
const OPTIONS_PER_CHECKPOINT: int = 2

const DEFAULT_REST_COST_PERCENT: float = 15.0
const DEFAULT_CALORIE_COST: float = 600.0

const LOCATION_DECK := [
    {
        "id": "overgrown_path",
        "label": "Overgrown Path",
        "hours_min": 3.5,
        "hours_max": 5.5,
        "summary": "Slow march through tangled brush.",
        "rest_cost_percent": 15.0,
        "calorie_cost": 620.0,
        "hazard_tier": "calm",
        "temperature_band": "temperate",
        "forage_profile": "wild_standard",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.18,
            "zombies": 0.32,
            "survivors": 0.25
        },
        "shelter_from_rain": false
    },
    {
        "id": "clearing",
        "label": "Clearing",
        "hours_min": 3.0,
        "hours_max": 4.5,
        "summary": "Sunlit gap great for pacing and morale.",
        "rest_cost_percent": 13.5,
        "calorie_cost": 560.0,
        "hazard_tier": "hostile",
        "temperature_band": "warm",
        "forage_profile": "wild_standard",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.33,
            "zombies": 0.35,
            "survivors": 0.32
        },
        "shelter_from_rain": false
    },
    {
        "id": "small_stream",
        "label": "Small Stream",
        "hours_min": 4.0,
        "hours_max": 5.5,
        "summary": "Wade beside cold water, watch footing.",
        "rest_cost_percent": 15.0,
        "calorie_cost": 600.0,
        "hazard_tier": "hostile",
        "temperature_band": "temperate",
        "forage_profile": "stream_banks",
        "fishing_allowed": true,
        "encounter_focus": {
            "wolves": 0.55,
            "zombies": 0.25,
            "survivors": 0.20
        },
        "shelter_from_rain": false
    },
    {
        "id": "thick_forest",
        "label": "Thick Forest",
        "hours_min": 5.0,
        "hours_max": 6.5,
        "summary": "Dense pines force short, careful steps.",
        "rest_cost_percent": 16.5,
        "calorie_cost": 640.0,
        "hazard_tier": "calm",
        "temperature_band": "cool",
        "forage_profile": "wild_standard",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.12,
            "zombies": 0.20,
            "survivors": 0.18
        },
        "shelter_from_rain": false
    },
    {
        "id": "old_campsite",
        "label": "Old Campsite",
        "hours_min": 4.0,
        "hours_max": 6.0,
        "summary": "Rummage ruins while passing through.",
        "rest_cost_percent": 15.0,
        "calorie_cost": 590.0,
        "hazard_tier": "watchful",
        "temperature_band": "cool",
        "forage_profile": "camp_cache",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.10,
            "zombies": 0.45,
            "survivors": 0.45
        },
        "shelter_from_rain": true
    },
    {
        "id": "old_cave",
        "label": "Old Cave",
        "hours_min": 4.5,
        "hours_max": 6.0,
        "summary": "Shaded crawl with slippery rock shelves.",
        "rest_cost_percent": 17.0,
        "calorie_cost": 610.0,
        "hazard_tier": "calm",
        "temperature_band": "cold",
        "forage_profile": "cave_sparse",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.05,
            "zombies": 0.12,
            "survivors": 0.08
        },
        "shelter_from_rain": true
    },
    {
        "id": "hunting_stand",
        "label": "Hunting Stand",
        "hours_min": 3.5,
        "hours_max": 4.5,
        "summary": "Clear sightlines, great for short breaks.",
        "rest_cost_percent": 14.0,
        "calorie_cost": 570.0,
        "hazard_tier": "watchful",
        "temperature_band": "cool",
        "forage_profile": "wild_standard",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.28,
            "zombies": 0.36,
            "survivors": 0.36
        },
        "shelter_from_rain": false
    }
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_checkpoint: int = 1
var _options: Array = []
var _selected_index: int = -1
var _completed_routes: Array = []
var _journey_complete: bool = false

func initialize(rng: RandomNumberGenerator) -> void:
    """Seed the deck and generate the first checkpoint routes."""
    _rng = rng if rng != null else RandomNumberGenerator.new()
    if _rng != rng:
        _rng.randomize()
    _current_checkpoint = 1
    _options.clear()
    _completed_routes.clear()
    _journey_complete = false
    _selected_index = -1
    _build_options_for_checkpoint()
    _emit_state()

func get_state() -> Dictionary:
    """Return a snapshot of checkpoints, options, and completed legs."""
    var state := {
        "current_checkpoint": _current_checkpoint,
        "total_checkpoints": TOTAL_CHECKPOINTS,
        "selected_option_index": _selected_index,
        "options": _clone_options(_options),
        "completed_routes": _clone_options(_completed_routes),
        "completed_count": _completed_routes.size(),
        "checkpoints_remaining": max(TOTAL_CHECKPOINTS - _completed_routes.size(), 0),
        "journey_complete": _journey_complete
    }
    return state

func select_option(index: int) -> Dictionary:
    """Mark an option for the upcoming travel leg."""
    if _journey_complete:
        return {
            "success": false,
            "reason": "journey_complete",
            "selected_index": _selected_index
        }
    if index < 0 or index >= _options.size():
        return {
            "success": false,
            "reason": "invalid_option",
            "selected_index": _selected_index,
            "options": _clone_options(_options)
        }
    _selected_index = index
    var response := {
        "success": true,
        "selected_index": _selected_index,
        "option": _options[_selected_index].duplicate(true)
    }
    _emit_state()
    return response

func get_selected_option() -> Dictionary:
    if _selected_index < 0 or _selected_index >= _options.size():
        return {}
    return _options[_selected_index].duplicate(true)

func commit_selected_route() -> Dictionary:
    """Advance to the next checkpoint using the current selection."""
    if _journey_complete:
        return {
            "success": false,
            "reason": "journey_complete",
            "completed_count": _completed_routes.size(),
            "total_checkpoints": TOTAL_CHECKPOINTS
        }
    if _selected_index < 0 or _selected_index >= _options.size():
        return {
            "success": false,
            "reason": "no_selection",
            "options": _clone_options(_options)
        }

    var option: Dictionary = _options[_selected_index].duplicate(true)
    option["checkpoint_departed"] = _current_checkpoint
    option["checkpoint_arrived"] = min(_current_checkpoint + 1, TOTAL_CHECKPOINTS)
    option["travel_hours"] = float(option.get("travel_hours", option.get("hours_min", 4.0)))
    _completed_routes.append(option)

    var result := {
        "success": true,
        "option": option.duplicate(true),
        "completed_count": _completed_routes.size(),
        "total_checkpoints": TOTAL_CHECKPOINTS,
        "journey_complete": false
    }

    _current_checkpoint += 1
    _selected_index = -1

    if _current_checkpoint > TOTAL_CHECKPOINTS:
        _journey_complete = true
        _options.clear()
        result["journey_complete"] = true
        result["checkpoints_remaining"] = 0
    else:
        _build_options_for_checkpoint()
        result["checkpoints_remaining"] = TOTAL_CHECKPOINTS - _completed_routes.size()

    _emit_state()
    return result

func _build_options_for_checkpoint() -> void:
    _options.clear()
    var pool: Array = LOCATION_DECK.duplicate(true)
    pool.shuffle()
    for i in range(OPTIONS_PER_CHECKPOINT):
        if pool.is_empty():
            pool = LOCATION_DECK.duplicate(true)
            pool.shuffle()
        var template: Dictionary = pool.pop_front()
        _options.append(_build_option(template))

func _build_option(template: Dictionary) -> Dictionary:
    var min_hours = float(template.get("hours_min", 3.5))
    var max_hours = float(template.get("hours_max", 6.0))
    if min_hours > max_hours:
        var swap = min_hours
        min_hours = max_hours
        max_hours = swap
    var roll = _rng.randf_range(min_hours, max_hours)
    var rounded = _round_to_half_hour(roll)
    var option := {
        "id": String(template.get("id", "route")),
        "label": String(template.get("label", "Route")),
        "hours_min": min_hours,
        "hours_max": max_hours,
        "travel_hours": rounded,
        "rest_cost_percent": float(template.get("rest_cost_percent", DEFAULT_REST_COST_PERCENT)),
        "calorie_cost": float(template.get("calorie_cost", DEFAULT_CALORIE_COST)),
        "summary": String(template.get("summary", "")),
        "checkpoint_index": _current_checkpoint
    }
    for extra_key in [
        "hazard_tier",
        "temperature_band",
        "forage_profile",
        "fishing_allowed",
        "encounter_focus",
        "shelter_from_rain"
    ]:
        if template.has(extra_key):
            option[extra_key] = template[extra_key]
    return option

func _round_to_half_hour(value: float) -> float:
    var clamped = max(value, 0.0)
    return round(clamped * 2.0) / 2.0

func _clone_options(source: Array) -> Array:
    var copy: Array = []
    for entry in source:
        if typeof(entry) == TYPE_DICTIONARY:
            copy.append(entry.duplicate(true))
        else:
            copy.append(entry)
    return copy

func _emit_state() -> void:
    expedition_state_changed.emit(get_state())
