# ZombieSystem.gd overview:
# - Purpose: simulate nightly zombie pressure, schedule daily spawn windows, and support diversion attempts.
# - Sections: signals track changes, constants define spawn math, lifecycle methods process day start, spawn timing, and time advancement.
extends RefCounted
class_name ZombieSystem

signal zombies_changed(count: int)
signal zombies_spawned(added: int, total: int, day: int)
signal zombies_damaged_tower(damage: float, count: int)

const DAMAGE_INTERVAL_MINUTES: int = 6 * 60
const DAMAGE_PER_ZOMBIE: float = 0.5
const DEFAULT_LEAD_AWAY_CHANCE: float = 0.80
const MINUTES_PER_DAY: int = 24 * 60

var _active_zombies: int = 0
var _minutes_since_tick: int = 0
var _current_day: int = 1
var _pending_spawn: Dictionary = {}
var _last_minute_stamp: int = 0

func _init():
    print("🧟 ZombieSystem ready")

func get_active_zombies() -> int:
    return _active_zombies

func has_active_zombies() -> bool:
    return _active_zombies > 0

func get_current_day() -> int:
    return _current_day

func start_day(day_index: int, rng: RandomNumberGenerator) -> Dictionary:
    _current_day = day_index
    _last_minute_stamp = 0
    var spawn_rolls = _resolve_spawn_rolls(day_index)
    var spawn_chance = _resolve_spawn_chance(day_index)
    _pending_spawn = {}

    if spawn_rolls <= 0 or spawn_chance <= 0.0 or rng == null:
        return {
            "day": day_index,
            "spawns": 0,
            "active": _active_zombies,
            "rolls": spawn_rolls,
            "chance": spawn_chance,
            "scheduled_minute": -1
        }

    var spawned = 0
    for _i in range(spawn_rolls):
        if rng.randf() < spawn_chance:
            spawned += 1

    var scheduled_minute = -1
    if spawned > 0:
        scheduled_minute = _pick_spawn_minute(rng)
        var minute_slot = max(scheduled_minute, 0)
        scheduled_minute = minute_slot
        _pending_spawn = {
            "day": day_index,
            "minute": minute_slot,
            "quantity": spawned
        }
        if minute_slot <= 0:
            _resolve_pending_spawn(_pending_spawn)

    return {
        "day": day_index,
        "spawns": spawned,
        "active": _active_zombies,
        "rolls": spawn_rolls,
        "chance": spawn_chance,
        "scheduled_minute": scheduled_minute
    }

func clear_zombies() -> void:
    if _active_zombies <= 0:
        return
    _active_zombies = 0
    _minutes_since_tick = 0
    zombies_changed.emit(_active_zombies)

func advance_time(minutes: int, current_minutes_since_daybreak: int, rolled_over: bool) -> Dictionary:
    minutes = max(minutes, 0)
    var previous_stamp = _last_minute_stamp
    var spawn_report: Dictionary = {}
    var minutes_after_spawn = minutes

    if has_pending_spawn():
        var pending_snapshot = _pending_spawn.duplicate(true)
        var spawn_minute = int(pending_snapshot.get("minute", -1))
        if spawn_minute >= 0 and _did_cross_marker(previous_stamp, current_minutes_since_daybreak, spawn_minute, rolled_over):
            var minutes_before_spawn = _minutes_until_marker(previous_stamp, spawn_minute, rolled_over, minutes)
            minutes_after_spawn = max(minutes - minutes_before_spawn, 0)
            spawn_report = _resolve_pending_spawn(pending_snapshot)
        else:
            minutes_after_spawn = minutes

    _last_minute_stamp = current_minutes_since_daybreak

    if !spawn_report.is_empty():
        if _active_zombies > 0:
            _minutes_since_tick += minutes_after_spawn
    else:
        if _active_zombies > 0:
            _minutes_since_tick += minutes
        else:
            _minutes_since_tick = 0

    var ticks = 0
    while _minutes_since_tick >= DAMAGE_INTERVAL_MINUTES:
        _minutes_since_tick -= DAMAGE_INTERVAL_MINUTES
        ticks += 1

    var damage_per_tick = _active_zombies * DAMAGE_PER_ZOMBIE
    var total_damage = damage_per_tick * ticks

    if ticks > 0 and damage_per_tick > 0.0:
        zombies_damaged_tower.emit(total_damage, _active_zombies)

    var report := {
        "ticks": ticks,
        "damage_per_tick": damage_per_tick,
        "total_damage": total_damage,
        "zombies": _active_zombies
    }
    if !spawn_report.is_empty():
        report.merge(spawn_report)
    return report

func attempt_lead_away(chance: float, rng: RandomNumberGenerator) -> Dictionary:
    var active_before = _active_zombies
    var resolved_chance = clamp(chance, 0.0, 1.0)

    if active_before <= 0:
        return {
            "rolls": 0,
            "removed": 0,
            "remaining": _active_zombies,
            "chance": resolved_chance,
            "reason": "no_zombies"
        }

    if resolved_chance <= 0.0 or rng == null:
        return {
            "rolls": active_before,
            "removed": 0,
            "remaining": _active_zombies,
            "chance": resolved_chance,
            "reason": "chance_blocked"
        }

    var removed = 0
    for _i in range(active_before):
        if rng.randf() < resolved_chance:
            removed += 1

    var remaining = max(active_before - removed, 0)
    if removed > 0:
        _active_zombies = remaining
        if _active_zombies <= 0:
            _minutes_since_tick = 0
        zombies_changed.emit(_active_zombies)

    var outcome = "cleared" if removed > 0 else "stayed"
    return {
        "rolls": active_before,
        "removed": removed,
        "remaining": _active_zombies,
        "chance": resolved_chance,
        "rolls_failed": max(active_before - removed, 0),
        "reason": outcome
    }

func preview_day_spawn(day_index: int, rng: RandomNumberGenerator) -> Dictionary:
    var spawn_rolls = _resolve_spawn_rolls(day_index)
    var spawn_chance = _resolve_spawn_chance(day_index)
    if spawn_rolls <= 0 or spawn_chance <= 0.0 or rng == null:
        return {
            "day": day_index,
            "spawns": 0,
            "rolls": spawn_rolls,
            "chance": spawn_chance,
            "scheduled_minute": -1
        }

    var spawned = 0
    for _i in range(spawn_rolls):
        if rng.randf() < spawn_chance:
            spawned += 1

    var scheduled_minute = -1
    if spawned > 0:
        scheduled_minute = _pick_spawn_minute(rng)

    return {
        "day": day_index,
        "spawns": spawned,
        "rolls": spawn_rolls,
        "chance": spawn_chance,
        "scheduled_minute": scheduled_minute
    }

func get_pending_spawn() -> Dictionary:
    if _pending_spawn.is_empty():
        return {}
    return _pending_spawn.duplicate(true)

func has_pending_spawn() -> bool:
    return !_pending_spawn.is_empty()

func _resolve_spawn_rolls(day_index: int) -> int:
    if day_index < 6:
        return 0
    if day_index <= 15:
        return 3
    if day_index <= 24:
        return 5
    return 5

func _resolve_spawn_chance(day_index: int) -> float:
    if day_index < 6:
        return 0.0
    if day_index <= 15:
        return 0.10
    if day_index <= 24:
        return 0.15
    return 0.15

func _pick_spawn_minute(rng: RandomNumberGenerator) -> int:
    if rng == null:
        return -1
    var hour = rng.randi_range(0, 23)
    return hour * 60

func _did_cross_marker(start: int, end: int, marker: int, rolled_over: bool) -> bool:
    if marker < 0:
        return false
    if rolled_over or end < start:
        return marker > start or marker <= end
    return marker > start and marker <= end

func _minutes_until_marker(start: int, marker: int, rolled_over: bool, elapsed: int) -> int:
    if elapsed <= 0:
        return 0
    if marker == start:
        return 0
    if !rolled_over and marker >= start:
        return min(marker - start, elapsed)
    var diff = (MINUTES_PER_DAY - start) + marker
    return min(diff, elapsed)

func _resolve_pending_spawn(payload: Dictionary) -> Dictionary:
    var quantity = int(payload.get("quantity", 0))
    if quantity <= 0:
        _pending_spawn = {}
        return {}

    _active_zombies += quantity
    _minutes_since_tick = 0
    _pending_spawn = {}
    var day_index = int(payload.get("day", _current_day))
    zombies_spawned.emit(quantity, _active_zombies, day_index)
    zombies_changed.emit(_active_zombies)

    return {
        "spawn_event": {
            "day": day_index,
            "spawns": quantity,
            "total": _active_zombies,
            "minute": int(payload.get("minute", 0))
        }
    }

