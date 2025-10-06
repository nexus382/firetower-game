extends RefCounted
class_name ZombieSystem

signal zombies_changed(count: int)
signal zombies_spawned(added: int, total: int, day: int)
signal zombies_damaged_tower(damage: float, count: int)

const DAMAGE_INTERVAL_MINUTES: int = 6 * 60
const DAMAGE_PER_ZOMBIE: float = 0.5

var _active_zombies: int = 0
var _minutes_since_tick: int = 0
var _current_day: int = 1

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
    var spawn_rolls = _resolve_spawn_rolls(day_index)
    var spawn_chance = _resolve_spawn_chance(day_index)
    if spawn_rolls <= 0 or spawn_chance <= 0.0 or rng == null:
        return {
            "day": day_index,
            "spawns": 0,
            "active": _active_zombies,
            "rolls": spawn_rolls,
            "chance": spawn_chance
        }

    var spawned = 0
    for _i in range(spawn_rolls):
        if rng.randf() < spawn_chance:
            spawned += 1

    if spawned > 0:
        _active_zombies += spawned
        _minutes_since_tick = 0
        zombies_spawned.emit(spawned, _active_zombies, day_index)
        zombies_changed.emit(_active_zombies)

    return {
        "day": day_index,
        "spawns": spawned,
        "active": _active_zombies,
        "rolls": spawn_rolls,
        "chance": spawn_chance
    }

func clear_zombies() -> void:
    if _active_zombies <= 0:
        return
    _active_zombies = 0
    _minutes_since_tick = 0
    zombies_changed.emit(_active_zombies)

func advance_time(minutes: int) -> Dictionary:
    minutes = max(minutes, 0)
    if _active_zombies <= 0 or minutes <= 0:
        return {
            "ticks": 0,
            "damage_per_tick": 0.0,
            "total_damage": 0.0,
            "zombies": _active_zombies
        }

    _minutes_since_tick += minutes
    var ticks = 0
    while _minutes_since_tick >= DAMAGE_INTERVAL_MINUTES:
        _minutes_since_tick -= DAMAGE_INTERVAL_MINUTES
        ticks += 1

    var damage_per_tick = _active_zombies * DAMAGE_PER_ZOMBIE
    var total_damage = damage_per_tick * ticks

    if ticks > 0 and damage_per_tick > 0.0:
        zombies_damaged_tower.emit(total_damage, _active_zombies)

    return {
        "ticks": ticks,
        "damage_per_tick": damage_per_tick,
        "total_damage": total_damage,
        "zombies": _active_zombies
    }

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

