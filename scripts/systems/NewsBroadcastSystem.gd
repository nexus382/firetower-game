extends RefCounted
class_name NewsBroadcastSystem

signal broadcast_selected(day: int, broadcast: Dictionary)

const BROADCAST_SCHEDULE := [
    {
        "id": "mysterious_illness",
        "title": "Regional Bulletin",
        "start_day": 1,
        "end_day": 3,
        "chance": 1.0,
        "variants": [
            {
                "id": "strain_a",
                "text": "Reports mention a strange cough spreading through the valley. Officials call it \"seasonal\" but crews are advised to keep distance." 
            },
            {
                "id": "strain_b",
                "text": "Hospitals request volunteers as night shifts triple. Symptoms remain vague, only described as a fever that won't break." 
            },
            {
                "id": "strain_c",
                "text": "Dispatch relays shortages of basic meds. Campers along the river are abandoning sites after hearing about a new illness." 
            }
        ]
    },
    {
        "id": "supply_disruptions",
        "title": "Emergency Network",
        "start_day": 3,
        "end_day": 7,
        "chance": 1.0,
        "variants": [
            {
                "id": "convoys_delayed",
                "text": "State patrol grounded supply convoys after drivers collapsed mid-route. Town sirens keep sounding through the night." 
            },
            {
                "id": "fuel_ration",
                "text": "Fuel rationing begins at midnight. Stations in three counties have already run dry. Residents told to stay sheltered." 
            },
            {
                "id": "roads_closed",
                "text": "Roadblocks seal the southern ridge. Drones captured crowds pushing toward the forests, hoping the fire towers still watch." 
            }
        ]
    },
    {
        "id": "collapse_alert",
        "title": "Distress Signal",
        "start_day": 7,
        "end_day": 12,
        "chance": 0.75,
        "variants": [
            {
                "id": "evac_order",
                "text": "Broken transmissions repeat an evacuation order for the capital. The message loops, interrupted by faint screaming." 
            },
            {
                "id": "static_warning",
                "text": "Only static comes through until a voice whispers \"stay above ground\" before cutting off. Repeaters keep replaying it." 
            },
            {
                "id": "distress_call",
                "text": "A ranger from the north begs any tower still online to respond. Their crew hasn't checked in for 18 hours." 
            }
        ]
    }
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _daily_cache: Dictionary = {}

func _init():
    _rng.randomize()

func reset_day(day: int) -> Dictionary:
    if _daily_cache.has(day):
        return _daily_cache[day]
    var broadcast = _select_broadcast_for_day(day)
    _daily_cache[day] = broadcast
    broadcast_selected.emit(day, broadcast)
    return broadcast

func get_broadcast_for_day(day: int) -> Dictionary:
    if _daily_cache.has(day):
        return _daily_cache[day]
    return reset_day(day)

func _select_broadcast_for_day(day: int) -> Dictionary:
    var entry = _resolve_schedule_entry(day)
    if entry.is_empty():
        return {}

    var chance = clamp(entry.get("chance", 1.0), 0.0, 1.0)
    if _rng.randf() > chance:
        return {}

    var variants: Array = entry.get("variants", [])
    if variants.is_empty():
        return {}

    var index = _rng.randi_range(0, variants.size() - 1)
    var variant: Dictionary = variants[index]

    var resolved := {
        "id": entry.get("id", ""),
        "title": entry.get("title", "Radio Update"),
        "day": day,
        "variant_id": variant.get("id", str(index)),
        "text": variant.get("text", "")
    }
    return resolved

func _resolve_schedule_entry(day: int) -> Dictionary:
    for entry in BROADCAST_SCHEDULE:
        var start_day = int(entry.get("start_day", 1))
        var end_day = int(entry.get("end_day", start_day))
        if day >= start_day and day <= end_day:
            return entry
    return {}

func clear_cache():
    _daily_cache.clear()
