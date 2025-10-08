extends Node
class_name GameManager

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const WeatherSystem = preload("res://scripts/systems/WeatherSystem.gd")
const TowerHealthSystem = preload("res://scripts/systems/TowerHealthSystem.gd")
const NewsBroadcastSystem = preload("res://scripts/systems/NewsBroadcastSystem.gd")
const ZombieSystem = preload("res://scripts/systems/ZombieSystem.gd")

const CALORIES_PER_FOOD_UNIT: float = 1000.0
const LEAD_AWAY_ZOMBIE_CHANCE: float = ZombieSystem.DEFAULT_LEAD_AWAY_CHANCE

const CRAFTING_RECIPES := {
    "fishing_bait": {
        "item_id": "fishing_bait",
        "display_name": "Fishing Bait",
        "description": "Fresh bait to tempt nearby fish.",
        "cost": {
            "grubs": 1
        },
        "hours": 0.5,
        "rest_cost_percent": 2.5,
        "quantity": 1
    },
    "fishing_rod": {
        "item_id": "fishing_rod",
        "display_name": "Fishing Rod",
        "description": "Simple pole ready for shoreline casting.",
        "cost": {
            "rock": 1,
            "string": 2,
            "wood": 2
        },
        "hours": 1.5,
        "rest_cost_percent": 7.5,
        "quantity": 1
    },
    "rope": {
        "item_id": "rope",
        "display_name": "Rope",
        "description": "Braided vines for tying or climbing.",
        "cost": {
            "vines": 3
        },
        "hours": 1.0,
        "rest_cost_percent": 5.0,
        "quantity": 1
    },
    "spike_trap": {
        "item_id": "spike_trap",
        "display_name": "Spike Trap",
        "description": "Sturdy spikes to slow unwanted guests.",
        "cost": {
            "wood": 6
        },
        "hours": 2.0,
        "rest_cost_percent": 12.5,
        "quantity": 1
    },
    "spear": {
        "item_id": "spear",
        "display_name": "The Spear",
        "description": "A sharpened pole for close defense.",
        "cost": {
            "wood": 1
        },
        "hours": 1.0,
        "rest_cost_percent": 5.0,
        "quantity": 1
    },
    "string": {
        "item_id": "string",
        "display_name": "String",
        "description": "Twisted cloth cord for light bindings.",
        "cost": {
            "ripped_cloth": 1
        },
        "hours": 0.5,
        "rest_cost_percent": 2.5,
        "quantity": 1
    }
}

const MEAL_PORTIONS := {
    "small": {
        "food_units": 0.5,
        "label": "Small"
    },
    "normal": {
        "food_units": 1.0,
        "label": "Normal"
    },
    "large": {
        "food_units": 1.5,
        "label": "Large"
    }
}

signal day_changed(new_day: int)
signal weather_changed(new_state: String, previous_state: String, hours_remaining: int)
signal weather_multiplier_changed(new_multiplier: float, state: String)

# Core game state
var current_day: int = 1
var game_paused: bool = false

# Player reference
var player: CharacterBody2D

# Simulation systems
# Instantiated immediately so UI elements resolving GameManager during their own _ready callbacks
# always see live systems instead of a null placeholder.
var sleep_system: SleepSystem = SleepSystem.new()
var inventory_system: InventorySystem = InventorySystem.new()
var time_system: TimeSystem = TimeSystem.new()
var weather_system: WeatherSystem = WeatherSystem.new()
var tower_health_system: TowerHealthSystem = TowerHealthSystem.new()
var news_system: NewsBroadcastSystem = NewsBroadcastSystem.new()
var zombie_system: ZombieSystem = ZombieSystem.new()
var _last_awake_minute_stamp: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
    print("🎮 GameManager initialized - Day %d" % current_day)
    player = get_node("../Player")
    if player:
        print("✅ Player found and connected")
    else:
        print("❌ Player not found!")

    if sleep_system == null:
        sleep_system = SleepSystem.new()
    if inventory_system == null:
        inventory_system = InventorySystem.new()
    if time_system == null:
        time_system = TimeSystem.new()
    if weather_system == null:
        weather_system = WeatherSystem.new()
    if tower_health_system == null:
        tower_health_system = TowerHealthSystem.new()
    if news_system == null:
        news_system = NewsBroadcastSystem.new()
    if zombie_system == null:
        zombie_system = ZombieSystem.new()
    if _rng == null:
        _rng = RandomNumberGenerator.new()
    _rng.randomize()

    if inventory_system:
        inventory_system.bootstrap_defaults()
        inventory_system.set_total_food_units(5.0)
    if time_system:
        time_system.day_rolled_over.connect(_on_day_rolled_over)
        _last_awake_minute_stamp = time_system.get_minutes_since_daybreak()
        if weather_system:
            time_system.time_advanced.connect(Callable(weather_system, "on_time_advanced"))
            time_system.day_rolled_over.connect(Callable(weather_system, "on_day_rolled_over"))
            weather_system.initialize_clock_offset(time_system.get_minutes_since_daybreak())
        time_system.time_advanced.connect(_on_time_advanced_by_minutes)
    if weather_system:
        weather_system.weather_changed.connect(_on_weather_system_changed)
        weather_system.weather_hour_elapsed.connect(_on_weather_hour_elapsed)
        weather_system.broadcast_state()
    if tower_health_system and weather_system:
        tower_health_system.set_initial_weather_state(weather_system.get_state())
    if news_system:
        news_system.reset_day(current_day)
    if zombie_system:
        zombie_system.zombies_damaged_tower.connect(_on_zombie_damage_tower)
        zombie_system.start_day(current_day, _rng)

func pause_game():
    game_paused = true
    print("⏸️ Game paused")

func resume_game():
    game_paused = false
    print("▶️ Game resumed")

func get_sleep_system() -> SleepSystem:
    """Expose the sleep system for UI consumers."""
    return sleep_system

func get_time_system() -> TimeSystem:
    """Expose the time system for UI consumers."""
    return time_system

func get_inventory_system() -> InventorySystem:
    """Expose the inventory system for UI consumers."""
    return inventory_system

func get_weather_system() -> WeatherSystem:
    """Expose the weather system for UI consumers."""
    return weather_system

func get_tower_health_system() -> TowerHealthSystem:
    return tower_health_system

func get_news_system() -> NewsBroadcastSystem:
    return news_system

func get_zombie_system() -> ZombieSystem:
    return zombie_system

func get_crafting_recipes() -> Dictionary:
    var copy := {}
    for key in CRAFTING_RECIPES.keys():
        copy[key] = CRAFTING_RECIPES[key].duplicate(true)
    return copy

func get_sleep_percent() -> float:
    """Convenience accessor for tired meter value."""
    return sleep_system.get_sleep_percent() if sleep_system else 0.0

func get_daily_calories_used() -> float:
    """Current daily calorie usage (can go negative)."""
    return sleep_system.get_daily_calories_used() if sleep_system else 0

func get_player_weight_lbs() -> float:
    return sleep_system.get_player_weight_lbs() if sleep_system else 0.0

func get_player_weight_kg() -> float:
    return sleep_system.get_player_weight_kg() if sleep_system else 0.0

func get_weight_unit() -> String:
    return sleep_system.get_weight_unit() if sleep_system else SleepSystem.WEIGHT_UNIT_LBS

func set_weight_unit(unit: String) -> String:
    return sleep_system.set_weight_unit(unit) if sleep_system else unit

func toggle_weight_unit() -> String:
    return sleep_system.toggle_weight_unit() if sleep_system else SleepSystem.WEIGHT_UNIT_LBS

func get_time_multiplier() -> float:
    return sleep_system.get_time_multiplier() if sleep_system else 1.0

func get_weather_activity_multiplier() -> float:
    return weather_system.get_activity_multiplier() if weather_system else 1.0

func get_combined_activity_multiplier() -> float:
    return get_time_multiplier() * get_weather_activity_multiplier()

func request_radio_broadcast() -> Dictionary:
    if news_system == null:
        return {
            "success": false,
            "reason": "news_offline"
        }

    var broadcast = news_system.get_broadcast_for_day(current_day)
    var has_message = !broadcast.is_empty() and !broadcast.get("text", "").is_empty()
    var result := {
        "success": true,
        "day": current_day,
        "has_message": has_message,
        "broadcast": broadcast
    }
    if !has_message:
        result["reason"] = "no_broadcast"
    return result

func perform_eating(portion_key: String) -> Dictionary:
    if not sleep_system or not time_system or not inventory_system:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "eat"
        }

    var portion = _resolve_meal_portion(portion_key)
    var food_units = portion.get("food_units", 1.0)
    if !inventory_system.has_food_units(food_units):
        return {
            "success": false,
            "reason": "insufficient_food",
            "action": "eat",
            "portion": portion.get("key", "normal"),
            "required_food": food_units,
            "total_food_units": inventory_system.get_total_food_units()
        }

    var time_report = _spend_activity_time(1.0, "eat")
    if !time_report.get("success", false):
        time_report["action"] = "eat"
        time_report["portion"] = portion.get("key", "normal")
        return time_report

    var consume_report = inventory_system.consume_food_units(food_units)
    if !consume_report.get("success", false):
        return {
            "success": false,
            "reason": consume_report.get("reason", "consume_failed"),
            "action": "eat",
            "portion": portion.get("key", "normal"),
            "required_food": food_units,
            "total_food_units": inventory_system.get_total_food_units()
        }

    var calories = portion.get("calories", food_units * CALORIES_PER_FOOD_UNIT)
    var daily_total = sleep_system.adjust_daily_calories(-calories)
    var result := time_report.duplicate()
    result["action"] = "eat"
    result["portion"] = portion.get("key", "normal")
    result["food_units_spent"] = consume_report.get("amount_consumed", food_units)
    result["calories_consumed"] = calories
    result["calorie_delta"] = -calories
    result["daily_calories_used"] = daily_total
    result["weight_lbs"] = sleep_system.get_player_weight_lbs()
    result["total_food_units"] = inventory_system.get_total_food_units()

    print("🍴 Ate %s meal: -%.0f cal, -%.1f food" % [result["portion"], calories, result["food_units_spent"]])
    return result

func repair_tower(materials: Dictionary = {}) -> Dictionary:
    if not time_system or not sleep_system or tower_health_system == null or inventory_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "repair"
        }

    if tower_health_system.is_at_repair_cap():
        return {
            "success": false,
            "reason": "tower_full_health",
            "action": "repair",
            "health": tower_health_system.get_health()
        }

    var required_wood: int = 1
    var wood_available = inventory_system.get_item_count("wood") if inventory_system else 0
    if wood_available < required_wood:
        return {
            "success": false,
            "reason": "insufficient_wood",
            "action": "repair",
            "wood_required": required_wood,
            "wood_available": wood_available
        }

    var time_report = _spend_activity_time(1.0, "repair")
    if !time_report.get("success", false):
        time_report["action"] = "repair"
        return time_report

    var consume_report = inventory_system.consume_item("wood", required_wood) if inventory_system else {"success": false}
    if !consume_report.get("success", false):
        return {
            "success": false,
            "reason": "wood_consume_failed",
            "action": "repair",
            "wood_required": required_wood,
            "wood_available": wood_available
        }

    var before = tower_health_system.get_health()
    var material_report := materials.duplicate() if typeof(materials) == TYPE_DICTIONARY else {}
    material_report["wood"] = material_report.get("wood", 0) + required_wood
    var repaired = tower_health_system.apply_repair(TowerHealthSystem.REPAIR_HEALTH_PER_ACTION, "manual_repair", material_report)
    var result := time_report.duplicate()
    result["action"] = "repair"
    result["health_before"] = before
    result["health_after"] = repaired
    result["health_restored"] = repaired - before
    var calorie_burn = sleep_system.adjust_daily_calories(350.0)
    var rest_bonus = sleep_system.apply_rest_bonus(10.0)
    result["calories_spent"] = 350.0
    result["daily_calories_used"] = calorie_burn
    result["rest_granted_percent"] = rest_bonus.get("percent_granted", 0.0)
    result["sleep_percent_remaining"] = rest_bonus.get("new_percent", sleep_system.get_sleep_percent())
    result["wood_spent"] = required_wood
    result["wood_remaining"] = inventory_system.get_item_count("wood") if inventory_system else 0

    print("🔧 Tower repair -> +%.1f (%.1f/%.1f)" % [result["health_restored"], repaired, tower_health_system.get_max_health()])
    return result

func reinforce_tower(materials: Dictionary = {}) -> Dictionary:
    if not time_system or not sleep_system or tower_health_system == null or inventory_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "reinforce"
        }

    if tower_health_system.is_at_reinforced_cap():
        return {
            "success": false,
            "reason": "reinforced_cap",
            "action": "reinforce",
            "health": tower_health_system.get_health()
        }

    var required_wood: int = 3
    var required_nails: int = 5
    var wood_available = inventory_system.get_item_count("wood") if inventory_system else 0
    var nails_available = inventory_system.get_item_count("nails") if inventory_system else 0
    if wood_available < required_wood or nails_available < required_nails:
        return {
            "success": false,
            "reason": "insufficient_material",
            "action": "reinforce",
            "wood_required": required_wood,
            "wood_available": wood_available,
            "nails_required": required_nails,
            "nails_available": nails_available
        }

    var time_report = _spend_activity_time(2.0, "reinforce")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "reinforce"
        return failure

    var wood_consume = inventory_system.consume_item("wood", required_wood)
    if !wood_consume.get("success", false):
        return {
            "success": false,
            "reason": "wood_consume_failed",
            "action": "reinforce",
            "wood_required": required_wood,
            "wood_available": wood_available
        }

    var nails_consume = inventory_system.consume_item("nails", required_nails)
    if !nails_consume.get("success", false):
        inventory_system.add_item("wood", required_wood)
        return {
            "success": false,
            "reason": "nails_consume_failed",
            "action": "reinforce",
            "nails_required": required_nails,
            "nails_available": nails_available,
            "wood_refunded": required_wood
        }

    var rest_spent = sleep_system.consume_sleep(20.0)
    var calorie_cost = 450.0
    var calorie_burn = sleep_system.adjust_daily_calories(calorie_cost)
    var before = tower_health_system.get_health()
    var material_report := materials.duplicate() if typeof(materials) == TYPE_DICTIONARY else {}
    material_report["wood"] = material_report.get("wood", 0) + required_wood
    material_report["nails"] = material_report.get("nails", 0) + required_nails
    var reinforced = tower_health_system.apply_reinforcement(25.0, "manual_reinforce", material_report)
    var added = reinforced - before

    var result := time_report.duplicate()
    result["action"] = "reinforce"
    result["success"] = true
    result["status"] = result.get("status", "applied")
    result["health_before"] = before
    result["health_after"] = reinforced
    result["health_added"] = added
    result["rest_spent_percent"] = rest_spent
    result["calories_spent"] = calorie_cost
    result["daily_calories_used"] = calorie_burn
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["wood_spent"] = required_wood
    result["wood_remaining"] = inventory_system.get_item_count("wood") if inventory_system else 0
    result["nails_spent"] = required_nails
    result["nails_remaining"] = inventory_system.get_item_count("nails") if inventory_system else 0
    result["reinforced_cap"] = tower_health_system.get_max_health()

    print("🧱 Tower reinforcement -> +%.1f (%.1f/%.1f)" % [added, reinforced, tower_health_system.get_max_health()])
    return result


func schedule_sleep(hours: float) -> Dictionary:
    """Apply sleep hours while advancing the daily clock."""
    if not sleep_system or not time_system:
        return {
            "accepted": false,
            "reason": "systems_unavailable"
        }

    hours = max(hours, 0.0)
    if is_zero_approx(hours):
        return {
            "accepted": false,
            "reason": "no_hours"
        }

    var current_minutes = time_system.get_minutes_since_daybreak()
    _apply_awake_time_up_to(current_minutes)

    var multiplier = sleep_system.get_time_multiplier()
    multiplier = max(multiplier, 0.01)
    var input_hours = hours
    var requested_minutes = int(ceil(hours * 60.0 * multiplier))
    var original_requested_minutes = requested_minutes
    var minutes_available = time_system.get_minutes_until_daybreak()
    var truncated = false
    if requested_minutes > minutes_available:
        if minutes_available <= 0:
            print("⚠️ Sleep rejected: %d min requested, %d min available" % [requested_minutes, minutes_available])
            var hours_available = int(floor(minutes_available / (60.0 * multiplier)))
            return {
                "accepted": false,
                "reason": "exceeds_day",
                "minutes_available": minutes_available,
                "hours_available": max(hours_available, 0),
                "time_multiplier": multiplier
            }
        truncated = true
        hours = float(minutes_available) / (60.0 * multiplier)
        requested_minutes = minutes_available
        if is_zero_approx(hours):
            print("⚠️ Sleep rejected: requested %.2f hr but %.0f min remain" % [hours, float(minutes_available)])
            return {
                "accepted": false,
                "reason": "exceeds_day",
                "minutes_available": minutes_available,
                "hours_available": 0,
                "time_multiplier": multiplier
            }

    var time_report = time_system.advance_minutes(requested_minutes)
    var sleep_report = sleep_system.apply_sleep(hours)

    _last_awake_minute_stamp = time_system.get_minutes_since_daybreak()

    var result: Dictionary = sleep_report.duplicate()
    result["accepted"] = true
    result["minutes_spent"] = time_report.get("minutes_applied", requested_minutes)
    result["rolled_over"] = time_report.get("rolled_over", false)
    result["daybreaks_crossed"] = time_report.get("daybreaks_crossed", 0)
    result["ended_at_minutes_since_daybreak"] = time_system.get_minutes_since_daybreak()
    result["ended_at_time"] = time_system.get_formatted_time()
    result["minutes_until_daybreak"] = time_system.get_minutes_until_daybreak()
    result["time_multiplier"] = multiplier
    result["requested_minutes"] = requested_minutes
    result["requested_minutes_original"] = original_requested_minutes
    result["truncated"] = truncated
    result["requested_hours"] = hours
    result["requested_hours_input"] = input_hours

    print("⏳ Time multiplier x%.1f -> %d min spent" % [multiplier, result["minutes_spent"]])

    return result

func perform_forging() -> Dictionary:
    if inventory_system == null or _rng == null or time_system == null or sleep_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "forging"
        }

    if zombie_system and zombie_system.has_active_zombies():
        return {
            "success": false,
            "reason": "zombies_present",
            "action": "forging",
            "zombie_count": zombie_system.get_active_zombies()
        }

    var time_report = _spend_activity_time(1.0, "forging")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["success"] = false
        failure["action"] = "forging"
        failure["reason"] = failure.get("reason", "time_rejected")
        failure["status"] = failure.get("status", "rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(15.0)
    var loot_roll = _roll_forging_loot()
    var result := time_report.duplicate()
    result["action"] = "forging"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()

    if loot_roll.is_empty():
        result["success"] = false
        result["reason"] = "nothing_found"
        print("🌲 Forging yielded nothing")
        return result

    var loot_reports: Array = []
    for item in loot_roll:
        var report = inventory_system.add_item(item.get("item_id", ""), item.get("quantity", 1))
        report["roll"] = item.get("roll", 0.0)
        report["chance"] = item.get("chance", 0.0)
        report["tier"] = item.get("tier", "basic")
        report["quantity_rolled"] = item.get("quantity", report.get("quantity_added", 1))
        loot_reports.append(report)

    result["success"] = true
    result["loot"] = loot_reports
    result["items_found"] = loot_reports.size()
    result["total_food_units"] = inventory_system.get_total_food_units()
    print("🌲 Forging success: %s" % result)
    return result

func perform_lead_away_undead() -> Dictionary:
    if time_system == null or sleep_system == null or zombie_system == null or _rng == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "lead_away"
        }

    if !zombie_system.has_active_zombies():
        return {
            "success": false,
            "reason": "no_zombies",
            "action": "lead_away",
            "zombies_before": zombie_system.get_active_zombies()
        }

    var time_report = _spend_activity_time(1.0, "lead_away")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "lead_away"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(15.0)
    var before = zombie_system.get_active_zombies()
    var attempt = zombie_system.attempt_lead_away(LEAD_AWAY_ZOMBIE_CHANCE, _rng)
    var removed = int(attempt.get("removed", 0))
    var remaining = int(attempt.get("remaining", zombie_system.get_active_zombies()))

    var result := time_report.duplicate()
    result["action"] = "lead_away"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["zombies_before"] = before
    result["removed"] = removed
    result["remaining"] = remaining
    result["rolls"] = int(attempt.get("rolls", before))
    result["rolls_failed"] = int(attempt.get("rolls_failed", max(before - removed, 0)))
    result["chance"] = float(attempt.get("chance", LEAD_AWAY_ZOMBIE_CHANCE))
    result["success"] = removed > 0
    if removed <= 0:
        var attempt_reason = str(attempt.get("reason", "stayed"))
        result["reason"] = "zombies_stayed" if attempt_reason == "stayed" else attempt_reason

    if removed > 0:
        print("🧟‍♂️ Lead Away -> removed %d (%.0f%% each, %d remain)" % [removed, result["chance"] * 100.0, max(remaining, 0)])
    else:
        print("🧟‍♂️ Lead Away failed (%.0f%% each, %d tried)" % [result["chance"] * 100.0, result["rolls"]])

    return result

func craft_item(recipe_id: String) -> Dictionary:
    var key = recipe_id.to_lower()
    if inventory_system == null or time_system == null or sleep_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "craft",
            "recipe": key
        }

    if !CRAFTING_RECIPES.has(key):
        return {
            "success": false,
            "reason": "recipe_missing",
            "action": "craft",
            "recipe": key
        }

    var recipe: Dictionary = CRAFTING_RECIPES.get(key, {})
    var cost: Dictionary = recipe.get("cost", {})
    var requirements: Array = []
    if !cost.is_empty():
        var cost_keys: Array = cost.keys()
        cost_keys.sort()
        for material_id in cost_keys:
            var needed = int(cost.get(material_id, 0))
            if needed <= 0:
                continue
            var available = inventory_system.get_item_count(material_id)
            if available < needed:
                return {
                    "success": false,
                    "reason": "insufficient_material",
                    "action": "craft",
                    "recipe": key,
                    "material_id": String(material_id),
                    "material_display": inventory_system.get_item_display_name(material_id),
                    "required": needed,
                    "available": available
                }
            requirements.append({
                "item_id": String(material_id),
                "quantity": needed
            })

    var hours = float(recipe.get("hours", 1.0))
    var time_report: Dictionary
    if hours <= 0.0:
        time_report = {
            "success": true,
            "activity": "craft_%s" % key,
            "minutes_spent": 0,
            "time_multiplier": get_combined_activity_multiplier(),
            "rolled_over": false,
            "daybreaks_crossed": 0,
            "ended_at_minutes_since_daybreak": time_system.get_minutes_since_daybreak(),
            "ended_at_time": time_system.get_formatted_time(),
            "minutes_until_daybreak": time_system.get_minutes_until_daybreak(),
            "minutes_required": 0,
            "status": "applied"
        }
    else:
        time_report = _spend_activity_time(hours, "craft_%s" % key)

    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["success"] = false
        failure["reason"] = failure.get("reason", "time_rejected")
        failure["action"] = "craft"
        failure["recipe"] = key
        return failure

    var rest_cost = max(float(recipe.get("rest_cost_percent", 0.0)), 0.0)
    var rest_spent = 0.0
    if rest_cost > 0.0:
        rest_spent = sleep_system.consume_sleep(rest_cost)

    var materials_spent: Array = []
    for requirement in requirements:
        var material_id = String(requirement.get("item_id", ""))
        var amount = int(requirement.get("quantity", 0))
        if material_id.is_empty() or amount <= 0:
            continue
        var consume_report = inventory_system.consume_item(material_id, amount)
        if !consume_report.get("success", false):
            return {
                "success": false,
                "reason": "material_consume_failed",
                "action": "craft",
                "recipe": key,
                "material_id": material_id,
                "material_display": inventory_system.get_item_display_name(material_id),
                "required": amount,
                "available": inventory_system.get_item_count(material_id)
            }
        materials_spent.append({
            "item_id": material_id,
            "display_name": consume_report.get("display_name", inventory_system.get_item_display_name(material_id)),
            "quantity": amount
        })

    var quantity = int(recipe.get("quantity", 1))
    if quantity <= 0:
        quantity = 1
    var add_report = inventory_system.add_item(recipe.get("item_id", key), quantity)

    var result := time_report.duplicate()
    result["success"] = true
    result["action"] = "craft"
    result["recipe"] = key
    result["status"] = time_report.get("status", "applied")
    result["item_id"] = add_report.get("item_id", recipe.get("item_id", key))
    result["display_name"] = add_report.get("display_name", recipe.get("display_name", key.capitalize()))
    result["quantity_added"] = add_report.get("quantity_added", quantity)
    var wood_spent = 0
    for entry in materials_spent:
        if String(entry.get("item_id", "")) == "wood":
            wood_spent += int(entry.get("quantity", 0))
    result["wood_spent"] = wood_spent
    result["materials_spent"] = materials_spent
    result["rest_spent_percent"] = rest_spent
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["total_food_units"] = inventory_system.get_total_food_units()

    var material_summary: PackedStringArray = []
    for entry in materials_spent:
        var label = entry.get("display_name", entry.get("item_id", "Material"))
        var qty = int(entry.get("quantity", 0))
        material_summary.append("%s -%d" % [label, max(qty, 0)])
    if material_summary.is_empty():
        material_summary.append("No materials")
    print("🛠️ Crafted %s -> +%d (%s)" % [result.get("display_name", key.capitalize()), result.get("quantity_added", quantity), ", ".join(material_summary)])
    return result

func _roll_forging_loot() -> Array:
    var table = [
        {
            "item_id": "mushrooms",
            "chance": 0.25,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "berries",
            "chance": 0.25,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "walnuts",
            "chance": 0.25,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "grubs",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "ripped_cloth",
            "chance": 0.15,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "rock",
            "chance": 0.30,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "vines",
            "chance": 0.175,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "wood",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "plastic_sheet",
            "chance": 0.10,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "metal_scrap",
            "chance": 0.10,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "nails",
            "chance": 0.10,
            "quantity": 3,
            "tier": "advanced"
        },
        {
            "item_id": "duct_tape",
            "chance": 0.10,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "medicinal_herbs",
            "chance": 0.10,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "fuel",
            "chance": 0.10,
            "quantity_range": [3, 5],
            "tier": "advanced"
        },
        {
            "item_id": "mechanical_parts",
            "chance": 0.10,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "electrical_parts",
            "chance": 0.10,
            "quantity": 1,
            "tier": "advanced"
        }
    ]

    var rewards: Array = []
    for entry in table:
        var chance = float(entry.get("chance", 0.0))
        if chance <= 0.0:
            continue
        var quantity = int(entry.get("quantity", 1))
        if entry.has("quantity_range"):
            var range: Array = entry.get("quantity_range", [])
            if range.size() >= 2:
                var min_q = int(range[0])
                var max_q = int(range[1])
                if min_q > max_q:
                    var temp = min_q
                    min_q = max_q
                    max_q = temp
                quantity = _rng.randi_range(min_q, max_q)
        if quantity <= 0:
            continue
        var roll = _rng.randf()
        if roll < chance:
            rewards.append({
                "item_id": entry.get("item_id", ""),
                "quantity": quantity,
                "chance": chance,
                "roll": roll,
                "tier": entry.get("tier", "basic")
            })
    return rewards

func _on_day_rolled_over():
    current_day += 1
    print("🌅 New day begins: Day %d" % current_day)
    if sleep_system:
        sleep_system.reset_daily_counters()
    _last_awake_minute_stamp = 0
    if tower_health_system:
        var current_state = weather_system.get_state() if weather_system else WeatherSystem.WEATHER_CLEAR
        tower_health_system.on_day_completed(current_state)
    if news_system:
        news_system.reset_day(current_day)
    if zombie_system:
        zombie_system.start_day(current_day, _rng)
    day_changed.emit(current_day)

func _on_weather_system_changed(new_state: String, previous_state: String, hours_remaining: int):
    var multiplier = get_weather_activity_multiplier()
    weather_changed.emit(new_state, previous_state, hours_remaining)
    weather_multiplier_changed.emit(multiplier, new_state)

func _on_weather_hour_elapsed(state: String):
    if tower_health_system:
        tower_health_system.register_weather_hour(state)

func _on_time_advanced_by_minutes(minutes: int, _rolled_over: bool):
    if zombie_system == null or tower_health_system == null:
        return
    var report = zombie_system.advance_time(minutes)
    if report.get("ticks", 0) <= 0:
        return
    var damage = float(report.get("total_damage", 0.0))
    if damage > 0.0:
        tower_health_system.apply_damage(damage, "zombie_presence")

func _on_zombie_damage_tower(damage: float, count: int):
    print("🧟 Zombies inflicted %.2f damage (%d active)" % [damage, count])

func _apply_awake_time_up_to(current_minutes: int):
    if not sleep_system or not time_system:
        return

    var delta = current_minutes - _last_awake_minute_stamp
    if delta < 0:
        delta += TimeSystem.MINUTES_PER_DAY
    if delta > 0:
        sleep_system.apply_awake_minutes(delta)
    _last_awake_minute_stamp = current_minutes

func _resolve_meal_portion(portion_key: String) -> Dictionary:
    var key = portion_key.to_lower()
    if key.is_empty() or !MEAL_PORTIONS.has(key):
        key = "normal"
    var definition: Dictionary = MEAL_PORTIONS.get(key, MEAL_PORTIONS["normal"])
    var resolved := definition.duplicate()
    resolved["key"] = key
    resolved["calories"] = resolved.get("food_units", 1.0) * CALORIES_PER_FOOD_UNIT
    return resolved

func _spend_activity_time(hours: float, activity: String) -> Dictionary:
    if not time_system or not sleep_system:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "activity": activity,
            "status": "unavailable"
        }

    hours = max(hours, 0.0)
    if is_zero_approx(hours):
        return {
            "success": false,
            "reason": "no_duration",
            "activity": activity,
            "status": "rejected"
        }

    var multiplier = get_combined_activity_multiplier()
    multiplier = max(multiplier, 0.01)
    var requested_minutes = int(ceil(hours * 60.0 * multiplier))
    requested_minutes = max(requested_minutes, 1)
    var minutes_available = time_system.get_minutes_until_daybreak()
    if requested_minutes > minutes_available:
        return {
            "success": false,
            "reason": "exceeds_day",
            "activity": activity,
            "minutes_required": requested_minutes,
            "minutes_available": minutes_available,
            "time_multiplier": multiplier,
            "status": "blocked",
            "blocker": "daybreak"
        }

    var current_minutes = time_system.get_minutes_since_daybreak()
    _apply_awake_time_up_to(current_minutes)

    var advance_report = time_system.advance_minutes(requested_minutes)
    if sleep_system:
        sleep_system.apply_awake_minutes(requested_minutes)

    _last_awake_minute_stamp = time_system.get_minutes_since_daybreak()

    return {
        "success": true,
        "activity": activity,
        "minutes_spent": requested_minutes,
        "time_multiplier": multiplier,
        "rolled_over": advance_report.get("rolled_over", false),
        "daybreaks_crossed": advance_report.get("daybreaks_crossed", 0),
        "ended_at_minutes_since_daybreak": time_system.get_minutes_since_daybreak(),
        "ended_at_time": time_system.get_formatted_time(),
        "minutes_until_daybreak": time_system.get_minutes_until_daybreak(),
        "minutes_required": requested_minutes,
        "status": "applied"
    }
