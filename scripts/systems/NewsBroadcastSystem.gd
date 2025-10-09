# NewsBroadcastSystem.gd overview:
# - Purpose: pick day-appropriate radio bulletins and emit broadcasts for the radio panel.
# - Sections: schedule table defines weighted variants, helpers roll availability, public methods surface results.
extends RefCounted
class_name NewsBroadcastSystem

signal broadcast_selected(day: int, broadcast: Dictionary)

# Broadcast windows:
# - Days 1-3: 8 illness variants covering escalating public strain.
# - Days 4-7: 13 supply variants following infrastructure breakdown reports.
# - Days 8-10: 5 martial-law variants delivering evacuation mandates.
# - Days 11+: 3 collapse variants with a 0.25 chance; failed rolls return silence.
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
            },
            {
                "id": "domestic_reports",
                "text": "There has been a spike in domestic violence reports over the last 24 hours, so please stay safe out there."
            },
            {
                "id": "call_volume",
                "text": "911 reports higher than average traffic on their network. Callers are asked to remain patient; brief waits are possible but unlikely."
            },
            {
                "id": "anthony_fill_in",
                "text": "Hi there, Anthony Scordino filling in today while our reporter Nina is out sick, joining several staff feeling under the weather."
            },
            {
                "id": "military_sightings",
                "text": "We have reports of military presence in the area, with helicopters and trucks spotted around town according to witness claims."
            },
            {
                "id": "business_shutdowns",
                "text": "Due to the rise in sick residents, a few local businesses have temporarily closed. Wash your hands, rest up, and stay hydrated, everybody."
            }
        ]
    },
    {
        "id": "supply_disruptions",
        "title": "Emergency Network",
        "start_day": 4,
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
                "text": "Roadblocks seal the southern ridge. Drones captured crowds pushing toward the forests, hoping the firetowers still watch."
            },
            {
                "id": "riots_spreading",
                "text": "With a further increase in riots and violence, CDC officials and army personnel have set up relief shelters and refuge camps on the outskirts."
            },
            {
                "id": "emergency_calls",
                "text": "911 advises residents not to call unless it is an absolute emergency. Dispatch shares only what the CDC has confirmed at this time."
            },
            {
                "id": "looting_reports",
                "text": "Looting and rioting have erupted in larger cities, with food, water, and essentials stolen as price gouging pushes water to $20 a gallon."
            },
            {
                "id": "shelter_in_place",
                "text": "The CDC advises everyone to remain indoors and plan to shelter in place for at least ten days. Military units evacuate the most affected blocks."
            },
            {
                "id": "state_of_emergency",
                "text": "The travel ban enacted two days ago has been raised to a State of Emergency. Only essential personnel should be on the roads."
            },
            {
                "id": "military_support",
                "text": "Military convoys continue to roll into the region to help contain violent outbreaks. Stay inside and await further instructions."
            },
            {
                "id": "virus_connection",
                "text": "Reports from around the globe point to a connection between the violence and the newly identified virus spreading through the population."
            },
            {
                "id": "h2z1_resurgence",
                "text": "First reports indicate H2Z1 patients slipping into a death-like state, then reviving violently. Quarantine anyone infected and call the hotline."
            },
            {
                "id": "mass_violence",
                "text": "Violence has flooded the streets. Large, relentless groups leave numerous injuries and fatalities in their wake across major cities."
            },
            {
                "id": "unconfirmed_attacks",
                "text": "Unconfirmed alerts describe aggressive individuals causing severe harm, in some cases biting or tearing at their victims."
            }
        ]
    },
    {
        "id": "martial_law",
        "title": "Emergency Broadcast System",
        "start_day": 8,
        "end_day": 10,
        "chance": 1.0,
        "variants": [
            {
                "id": "martial_law_declaration",
                "text": "*BEEEEEP* This is an official declaration of martial law. Stay indoors, keep doors and windows locked, avoid all infected contact, and do not seek loved ones. *BEEEEEP*"
            },
            {
                "id": "mandatory_evacuation",
                "text": "The military is clearing neighborhoods outside the city as conditions deteriorate. Evacuations are mandatory; follow every instruction from personnel on site."
            },
            {
                "id": "hospital_lockdown",
                "text": "Hospitals are beyond capacity, forcing the military to erect roadblocks and turn people away. Shelter at home and wait for evacuation orders."
            },
            {
                "id": "burn_protocol",
                "text": "Anyone lost to the H2Z1 virus must be burned immediately. Reports nationwide describe the deceased rising again to attack the living."
            },
            {
                "id": "avoid_crowds",
                "text": "Avoid dense areas, obey military and police directives, lock down your home, and remain quiet while awaiting evacuation updates."
            }
        ]
    },
    {
        "id": "collapse_alert",
        "title": "Distress Signal",
        "start_day": 11,
        "end_day": 9999,
        "chance": 0.25,
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
    # Keeps a stable pick for the day so the same report repeats when re-opened.
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
