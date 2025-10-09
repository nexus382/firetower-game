# Firetower Survival Guide

## Core Loop Snapshot
* Daybreak hits at 6:00 AM; a full day spans 1,440 minutes tracked by `TimeSystem`.
* `GameManager` advances time for every action, spends calories, and applies rest changes using sleep and weather multipliers.
* Weather rolls every hour: 5% chance to start precipitation when clear, with intensity weighted 15% heavy storm, 35% rain, 50% sprinkling and default durations 5h/2h/1h respectively.
* Zombies begin daily spawn checks on Day 6; successful rolls schedule a single wave at a random hour (0-23) and inflict 0.5 tower damage per zombie every 6 hours once active.
* Recon is available from 6:00 AM through 12:00 AM, consumes 1 hour plus 150 calories, and locks in a six-hour weather and zombie forecast using the live RNG sequence.

## Systems Reference

### GameManager (`scripts/GameManager.gd`)
* **Role**: survival coordinator that instantiates systems, owns task actions, and relays signals to UI.
* **Signals**
  - `day_changed(new_day)` – broadcast after `_on_day_rolled_over`.
  - `weather_changed(new_state, previous_state, hours_remaining)` – fired from `_on_weather_system_changed`.
  - `weather_multiplier_changed(new_multiplier, state)` – exposes weather activity scaling to UI.
* **Key constants**
  - `CALORIES_PER_FOOD_UNIT = 1000` (1 food unit equals 1,000 calories).
  - `LEAD_AWAY_ZOMBIE_CHANCE = 0.80` (80% success per zombie).
  - `RECON_CALORIE_COST = 150` (burned during recon).
  - Recon window bounds: `start_minute = 0` (6:00 AM), `end_minute = 1080` (12:00 AM) relative to daybreak.
* **Lifecycle**
  - `_ready()` – seeds RNG, spawns systems, hooks listeners, starts Day 1 spawn planning.
  - `pause_game()` / `resume_game()` – set `game_paused` flag.
* **System accessors**
  - `get_sleep_system()`, `get_time_system()`, `get_inventory_system()`, `get_weather_system()`, `get_tower_health_system()`, `get_news_system()`, `get_zombie_system()`.
  - `get_crafting_recipes()` – deep copy of crafting blueprint dictionary.
  - Recon helpers: `get_recon_window_status()` returns availability, cutoff, and resume timestamps.
* **Player status getters**
  - `get_sleep_percent()`, `get_daily_calories_used()`, `get_player_weight_lbs()`, `get_player_weight_kg()`, `get_weight_unit()`.
  - `set_weight_unit(unit)` / `toggle_weight_unit()` – pass-through to `SleepSystem`.
  - Multipliers: `get_time_multiplier()`, `get_weather_activity_multiplier()`, `get_combined_activity_multiplier()`.
* **Radio & narrative**
  - `request_radio_broadcast()` – returns cached `NewsBroadcastSystem` message for the current day (or static when missing).
* **Task actions**
  - `perform_eating(portion_key)` – spends 1 activity hour, converts food units to calories, and updates weight.
  - `schedule_sleep(hours)` – applies rest (10% per hour), burns 100 calories/hour, and advances time using the combined multiplier. Duration auto-truncates if daybreak would be crossed.
  - `perform_forging()` – requires no active zombies, consumes 1 hour plus 12.5% energy, burns 500 calories, rolls `_roll_forging_loot()`, and awards inventory loot.
  - `perform_lead_away_undead()` – spends 1 hour plus 15% energy, rolls each zombie at 80% success, and updates counts.
  - `perform_recon()` – restricted to recon window, consumes 1 hour plus 150 calories, snapshots RNG, and returns six-hour weather and zombie forecasts.
  - `repair_tower(materials)` – costs 1 hour and 1 wood, burns 350 calories, grants 10% rest bonus, restores 5 tower health (capped at 100).
  - `reinforce_tower(materials)` – costs 2 hours, 3 wood, 5 nails, burns 450 calories, spends 20% rest, adds 25 health up to 150 cap.
  - `craft_item(recipe_id)` – validates materials, spends recipe time (scaled by multipliers), consumes optional rest %, and adds crafted goods.
* **Internal helpers**
  - `_roll_forging_loot()` – iterates forging loot table (see Resource Catalog) using stored RNG.
  - `_on_day_rolled_over()` – increments `current_day`, resets calories, applies dry-day damage, refreshes news, and schedules the next zombie wave.
  - `_on_weather_system_changed()` / `_on_weather_hour_elapsed()` – rebroadcast weather and apply hourly precipitation wear.
  - `_on_time_advanced_by_minutes(minutes, rolled_over)` – feeds elapsed minutes into `ZombieSystem` and applies resulting tower damage.
  - `_on_zombie_damage_tower(damage, count)` – logs wave damage.
  - `_apply_awake_time_up_to(current_minutes)` – burns baseline calories between actions.
  - `_resolve_meal_portion(portion_key)` – normalizes meal presets and computes calorie totals.
  - `_forecast_zombie_activity(minutes_horizon, rng)` – assembles recon zombie outlook including pending same-day spawns and next-day previews when horizon crosses 6:00 AM.
  - `_spend_activity_time(hours, activity)` – enforces daybreak cutoff, multiplies requested duration by combined activity multiplier, advances `TimeSystem`, and records awake calorie burn.

### SleepSystem (`scripts/systems/SleepSystem.gd`)
* **Role**: track rest %, daily calories, and weight-based activity multipliers.
* **Core constants**
  - Rest bounds: `MIN_SLEEP_PERCENT = 0`, `MAX_SLEEP_PERCENT = 100`, `SLEEP_PERCENT_PER_HOUR = 10`.
  - Energy costs: `CALORIES_PER_SLEEP_HOUR = 100`, `AWAKE_CALORIES_PER_HOUR = 23`.
  - Weight conversion: `CALORIES_PER_POUND = 1000`.
  - Weight thresholds (lbs): `<=149 malnourished`, `150-200 average`, `>=201 overweight`.
* **Signals** – `sleep_percent_changed`, `daily_calories_used_changed`, `weight_changed`, `weight_category_changed`, `weight_unit_changed`.
* **Public API**
  - Getters: `get_sleep_percent()`, `get_daily_calories_used()`, `get_player_weight_lbs()`, `get_player_weight_kg()`, `get_display_weight()`, `get_weight_unit()`, `get_weight_category()`, `get_time_multiplier()` (2.0 malnourished, 1.5 overweight, 1.0 average).
  - Unit controls: `set_weight_unit(unit)`, `toggle_weight_unit()`.
  - Rest management: `apply_sleep(hours)`, `consume_sleep(percent)`, `apply_rest_bonus(percent)`.
  - Calorie handling: `apply_awake_minutes(minutes)`, `adjust_daily_calories(delta)`, `reset_daily_counters()`.
* **Internals** – `_apply_calorie_delta(calorie_delta)` adjusts weight, `_update_weight(new_weight_lbs)` fires signals, `_determine_weight_category(weight_lbs)` maps thresholds.

### BodyWeightSystem (`scripts/systems/BodyWeightSystem.gd`)
* **Role**: standalone calorie-to-weight utility (currently unused by GameManager but available for future health buffs).
* **Constants** – `CALORIES_PER_POUND = 1000`, healthy window `180-219 lbs`, overweight `>=220`, skinny `150-179`, malnourished `<150`.
* **Daily tracking** – `consume_food(calories)`, `burn_calories(calories)`, `calculate_daily_weight_change()` resets counters and returns net delta.
* **Display helpers** – `set_display_unit(unit)`, `get_display_weight()`, `get_weight_display_string()`, `get_calorie_summary()`.
* **Category helpers** – `get_weight_category()`, `get_weight_category_name()`, `get_weight_effects()` enumerates narrative modifiers.

### TimeSystem (`scripts/systems/TimeSystem.gd`)
* **Role**: authoritative in-game clock.
* **Constants** – `MINUTES_PER_DAY = 1440`, `DAY_START_MINUTE = 360` (6:00 AM).
* **Signals** – `time_advanced(minutes, crossed_daybreak)`, `day_rolled_over()`.
* **Public API**
  - Queries: `get_minutes_since_daybreak()`, `get_minutes_until_daybreak()`, `get_minutes_since_midnight()`, `get_formatted_time()`, `get_formatted_time_after(minutes)`.
  - `advance_minutes(duration)` – clamps to >=0, emits `day_rolled_over` for each 24h crossed, returns timing metadata.
* **Internals** – `_format_minutes(total_minutes)` renders 12-hour clock text.

### WeatherSystem (`scripts/systems/WeatherSystem.gd`)
* **Role**: hourly precipitation driver with forecast support.
* **States** – `clear`, `sprinkling`, `raining`, `heavy_storm`.
* **Chances**
  - Hourly rain start: `RAIN_START_CHANCE = 0.05` when clear.
  - Intensity weighting (normalized when roll succeeds): heavy 0.15, raining 0.35, sprinkling 0.50.
  - Default durations (hours): sprinkling 1, raining 2, heavy storm 5.
* **Multipliers** – `WEATHER_MULTIPLIERS`: clear x1.00, sprinkling x1.25, raining x1.50, heavy storm x1.75 applied to activity time.
* **Signals** – `weather_changed(new_state, previous_state, hours_remaining)`, `weather_hour_elapsed(state)`.
* **Public API**
  - Queries: `get_state()`, `get_hours_remaining()`, `get_activity_multiplier()`, `get_state_display_name()`, `get_state_display_name_for(state)`, `get_multiplier_for_state(state)`, `is_precipitating()`, `is_precipitating_state(state)`.
  - Lifecycle: `initialize_clock_offset(minutes_since_daybreak)`, `on_time_advanced(minutes, rolled_over)`, `on_day_rolled_over()`, `broadcast_state()`.
  - Forecast: `forecast_precipitation(hours_ahead)` clones RNG and simulates hourly ticks, returning event list with `start`, `stop`, and `ongoing` entries plus final state snapshot.
* **Internals** – `_process_hour_tick()` decrements precipitation timers, `_begin_precipitation()` selects intensity, `_set_state(new_state, duration)` updates timers, `_format_state_debug()` logs state string.

### TowerHealthSystem (`scripts/systems/TowerHealthSystem.gd`)
* **Role**: track tower health, weather wear, repairs, and reinforcements.
* **Health bounds** – Base 100 HP, reinforced cap 150 HP, dry-day decay 5 HP when no precipitation occurred.
* **Signals** – `tower_health_changed(new_health, previous)`, `tower_damaged(amount, source)`, `tower_repaired(amount, source)`.
* **Damage rules**
  - Precipitation damage per hour: sprinkling 1, raining 2, heavy storm 3.
  - Zombies supply external damage via `GameManager`.
* **Public API**
  - Queries: `get_health()`, `get_max_health()`, `get_base_max_health()`, `get_health_ratio()`, `is_at_max_health()`, `is_at_reinforced_cap()`, `is_at_repair_cap()`.
  - Lifecycle hooks: `set_initial_weather_state(state)`, `register_weather_hour(state)`, `on_day_completed(current_state)`.
  - Mutators: `apply_damage(amount, source)`, `apply_repair(amount, source, materials)`, `apply_reinforcement(amount, source, materials)`.
* **Internals** – `_is_precipitating_state(state)` defers to `WeatherSystem` constants.

### InventorySystem (`scripts/systems/InventorySystem.gd`)
* **Role**: item registry plus stack and food tracking.
* **Signals** – `food_total_changed(new_total)`, `item_added(item_id, quantity_added, food_gained, total_food_units)`, `item_consumed(item_id, quantity_removed, food_lost, total_food_units)`.
* **Setup** – `bootstrap_defaults()` registers all base items (see Resource Catalog).
* **Definitions** – `register_item_definition(item_id, definition)` normalizes display name, food units, and stack limit; `ensure_item_definition(item_id)` auto-registers missing IDs.
* **Queries** – `get_item_definition()`, `get_item_display_name()`, `get_item_count()`, `get_item_counts()`, `get_total_food_units()`.
* **Mutations**
  - Food: `set_total_food_units(amount)`, `add_food_units(delta)`, `has_food_units(amount)`, `consume_food_units(amount)`.
  - Items: `add_item(item_id, quantity)`, `consume_item(item_id, quantity)`, `clear()`.
* **Internals** – `_apply_food_delta(delta)` clamps totals and emits change events.

### NewsBroadcastSystem (`scripts/systems/NewsBroadcastSystem.gd`)
* **Role**: day-based radio script generator.
* **Schedule blocks**
  - Days 1-3: `mysterious_illness` (8 variants, 100% chance).
  - Days 4-7: `supply_disruptions` (13 variants, 100% chance).
  - Days 8-10: `martial_law` (5 variants, 100% chance).
  - Day 11+: `collapse_alert` (3 variants, 25% chance; otherwise silence).
* **Signals** – `broadcast_selected(day, broadcast)` fired when caching a report.
* **Public API**
  - `reset_day(day)` – selects or returns cached broadcast.
  - `get_broadcast_for_day(day)` – ensures a deterministic message per day.
  - `clear_cache()` – flush cached reports.
* **Internals** – `_select_broadcast_for_day(day)` applies chance roll and variant pick; `_resolve_schedule_entry(day)` finds active schedule row.

### ZombieSystem (`scripts/systems/ZombieSystem.gd`)
* **Role**: manage daily spawns, hourly damage ticks, and lead-away attempts.
* **Signals** – `zombies_changed(count)`, `zombies_spawned(added, total, day)`, `zombies_damaged_tower(damage, count)`.
* **Spawn rules**
  - Day 1-5: no rolls.
  - Days 6-15: 3 rolls, 10% success each.
  - Days 16-24: 5 rolls, 15% success each.
  - Day 25+: 5 rolls, 15% success each.
  - Successful daystart rolls sum to a single wave quantity scheduled at a random hour (0-23). Minute 0 spawns immediately at 6:00 AM.
* **Damage** – every 360 minutes with zombies active, apply `active * 0.5` tower damage and reset timer.
* **Public API**
  - Queries: `get_active_zombies()`, `has_active_zombies()`, `get_current_day()`, `get_pending_spawn()`.
  - Lifecycle: `start_day(day_index, rng)` – runs spawn rolls, caches pending event, resolves immediate waves.
  - Simulation: `advance_time(minutes, current_minutes_since_daybreak, rolled_over)` – resolves scheduled waves and returns damage summary.
  - Player actions: `attempt_lead_away(chance, rng)` – per-zombie roll with 0-1 outcome; `clear_zombies()` wipes active count.
  - Forecast: `preview_day_spawn(day_index, rng)` – mirrors `start_day` without mutating state.
* **Internals** – `_resolve_spawn_rolls(day)`, `_resolve_spawn_chance(day)`, `_pick_spawn_minute(rng)` (hour * 60), `_did_cross_marker(...)` handles wraparound, `_minutes_until_marker(...)`, `_resolve_pending_spawn(payload)` mutates counts.

### Weather-Aware Tower Interplay
* Every precipitation hour triggers `TowerHealthSystem.register_weather_hour`, deducting damage according to intensity.
* On clear, dry days `_had_precipitation_today` stays false; `on_day_completed` applies 5 damage to mimic wear.
* Recon weather forecast includes `events` with `minutes_ahead`, `state`, and `duration_hours` or `stop` entries for planning repairs or forging windows.

## Task & Action Catalog
| Action | Base Hours | Rest Impact | Calorie Impact | Requirements | Outcome |
| --- | --- | --- | --- | --- | --- |
| Sleep (`schedule_sleep`) | Input hours (auto-truncated) | +10% rest per hour (clamped 0-100) | -100 cal/hour (burn) | Open time before daybreak | Advances clock, updates rest %, burns calories, triggers awake calorie catch-up. |
| Eat (`perform_eating`) | 1h | None | -`food_units*1000` (net calories gained) | Sufficient food units | Consumes food, updates daily calories, returns weight snapshot. |
| Forge (`perform_forging`) | 1h | -12.5% energy | +500 cal burned (plus awake burn) | No active zombies | Rolls loot table, adds items, updates food totals. |
| Fish (`perform_fishing`) | 1h | -10% rest | +650 cal burned | Fishing Rod & ≥1 Grub (50% loss chance) | 5 rolls @30% each -> Small 50% (0.5), Medium 35% (1.0), Large 15% (1.5); adds food on hits. |
| Lead Away (`perform_lead_away_undead`) | 1h | -15% energy | Awake burn only | Active zombies present | Rolls 80% per zombie to remove, updates counts. |
| Recon (`perform_recon`) | 1h | None | +150 cal burned (`adjust_daily_calories`) | Time within 6 AM–12 AM | Returns six-hour forecast for weather and zombie spawns. |
| Repair (`repair_tower`) | 1h | +10% rest bonus | +350 cal burned | ≥1 wood, tower below 100 HP | Restores 5 HP, records materials used, updates health. |
| Reinforce (`reinforce_tower`) | 2h | -20% rest | +450 cal burned | ≥3 wood & 5 nails, tower below 150 HP | Adds 25 HP up to 150 cap, logs material spend. |
| Craft (varies) | Recipe hours | Recipe rest cost % | Awake burn; optional additional | Materials per recipe | Adds crafted item quantity, consumes inputs, tracks rest spend. |

## Crafting Recipes (`GameManager.CRAFTING_RECIPES`)
| Recipe | Output Qty | Hours | Rest Cost % | Material Costs | Notes |
| --- | --- | --- | --- | --- | --- |
| Fishing Bait | 1 | 0.5 | 2.5 | Grubs ×1 | Zero food value output. |
| Fishing Rod | 1 | 1.5 | 7.5 | Rock ×1, String ×2, Wood ×2 | Stack limit 1 in inventory. |
| Rope | 1 | 1.0 | 5.0 | Vines ×3 | Used for future climbing/traps. |
| Spike Trap | 1 | 2.0 | 12.5 | Wood ×6 | Defensive deployable. |
| The Spear | 1 | 1.0 | 5.0 | Wood ×1 | Close-defense tool. |
| String | 1 | 0.5 | 2.5 | Ripped Cloth ×1 | Intermediate crafting good. |

## Foraging Loot Table (`_roll_forging_loot`)
* Rolls execute independently per entry each trip; success adds the specified quantity.
* Quantities default to table value; ranges roll inclusive min/max.

| Item | Chance | Quantity | Tier | Notes |
| --- | --- | --- | --- | --- |
| Mushrooms | 25% | 1 | Basic | +1.0 food unit. |
| Berries | 25% | 1 | Basic | +1.0 food unit. |
| Walnuts | 25% | 1 | Basic | +0.5 food unit. |
| Grubs | 20% | 1 | Basic | +0.5 food unit. |
| Apples | 20% | 1 | Basic | +0.5 food unit. |
| Oranges | 20% | 1 | Basic | +0.5 food unit. |
| Raspberries | 20% | 1 | Basic | +0.5 food unit. |
| Blueberries | 20% | 1 | Basic | +0.5 food unit. |
| Ripped Cloth | 15% | 1 | Basic | Crafting fiber. |
| Rock | 30% | 1 | Basic | Tool material. |
| Vines | 17.5% | 1 | Basic | Rope input. |
| Wood | 20% | 1 | Basic | Repair & crafting staple. |
| Plastic Sheet | 10% | 1 | Advanced | Shelter upgrade material. |
| Metal Scrap | 10% | 1 | Advanced | Trap/armor material. |
| Nails | 10% | 3 | Advanced | Reinforcement resource. |
| Duct Tape | 10% | 1 | Advanced | Repair adhesive. |
| Medicinal Herbs | 10% | 1 | Advanced | Healing supplies. |
| Fuel | 10% | 3–5 | Advanced | Generator/heater fuel. |
| Mechanical Parts | 10% | 1 | Advanced | Trap maintenance. |
| Electrical Parts | 10% | 1 | Advanced | Powered projects. |

## Inventory Catalog (`InventorySystem.bootstrap_defaults`)
| Item ID | Display Name | Food Units | Stack Limit |
| --- | --- | --- | --- |
| mushrooms | Mushrooms | 1.0 | 99 |
| berries | Berries | 1.0 | 99 |
| apples | Apples | 0.5 | 99 |
| oranges | Oranges | 0.5 | 99 |
| raspberries | Raspberries | 0.5 | 99 |
| blueberries | Blueberries | 0.5 | 99 |
| walnuts | Walnuts | 0.5 | 99 |
| grubs | Grubs | 0.5 | 99 |
| fishing_bait | Fishing Bait | 0.0 | 99 |
| fishing_rod | Fishing Rod | 0.0 | 1 |
| wood | Wood | 0.0 | 999 |
| spear | The Spear | 0.0 | 1 |
| spike_trap | Spike Trap | 0.0 | 10 |
| ripped_cloth | Ripped Cloth | 0.0 | 99 |
| string | String | 0.0 | 99 |
| rock | Rock | 0.0 | 99 |
| vines | Vines | 0.0 | 99 |
| rope | Rope | 0.0 | 99 |
| plastic_sheet | Plastic Sheet | 0.0 | 99 |
| metal_scrap | Metal Scrap | 0.0 | 99 |
| nails | Nails | 0.0 | 999 |
| duct_tape | Duct Tape | 0.0 | 99 |
| medicinal_herbs | Medicinal Herbs | 0.0 | 99 |
| fuel | Fuel | 0.0 | 99 |
| mechanical_parts | Mechanical Parts | 0.0 | 99 |
| electrical_parts | Electrical Parts | 0.0 | 99 |

## Nutrition & Weight Summary
* Awake baseline burn: 23 calories/hour via `SleepSystem.apply_awake_minutes` and `_spend_activity_time`.
* Sleep burn: 100 calories/hour plus +10% rest per hour.
* Repair bonus: +10% rest while burning 350 calories.
* Reinforce: -20% rest, +450 calories burned.
* Recon: +150 calories burned with no rest change.
* Weight adjustments: each 1,000 calorie deficit drops 1 lb; surpluses increase weight. Categories set time multiplier (malnourished x2.0, overweight x1.5, average x1.0).

## Weather States & Multipliers
| State | Label | Multiplier | Default Duration | Tower Damage/Hour |
| --- | --- | --- | --- | --- |
| clear | Clear Skies | x1.00 | N/A | 0 |
| sprinkling | Sprinkling | x1.25 | 1h | 1 |
| raining | Raining | x1.50 | 2h | 2 |
| heavy_storm | Heavy Storm | x1.75 | 5h | 3 |

## Zombie Threat Overview
* Daily planning at 6:00 AM resolves spawn quantity using RNG shared with recon previews.
* `get_pending_spawn()` returns `{day, minute, quantity}`; recon reports include `minutes_ahead` and clock timestamp when within six-hour horizon.
* Active zombie damage fires every 6 hours (360 minutes) of accumulated time after the last attack or spawn resolution.
* Lead Away is the only direct mitigation outside of tower defenses—each zombie has an independent 80% chance to leave per attempt.

## Radio & Narrative
* Radio interaction pulls `NewsBroadcastSystem` output for the current day. If the day's schedule misses its 25% roll (Day 11+), the player hears static text: "Only static crackles tonight.".
* Broadcast titles dynamically include the day: `"{Title} - Day {N}"`.

## Tower Layout & Player Control
* `Player` moves at 200 px/sec (recommended 150-275 tuning) and snaps to the living area center provided by `TowerManager` at start.
* `TowerManager` builds:
  - Catwalk border (approx. 5% width) surrounding three-room interior.
  - Living area (left half), kitchen (top-right 60%), bathroom (bottom-right 40%).
  - Fixtures: ladder, radio in living area, crafting table in kitchen.
* `CameraController` pins a 1280×720 full-tower shot with zoom 1×.

## Interaction Objects & UI
* **CraftingTable** – shows `Press [E] to craft` prompt, resolves `CraftingPanel` node, and opens panel on interaction. Leaves panel if player exits area.
* **Radio** – similar prompt, resolves `GameManager` and `RadioPanel`, displays broadcast text or static fallback.
* **HUD** – wires to all systems, exposes toggles like weight unit button (lbs/kg), and displays tower health, food, wood, zombie counts, weather, clock, and rest meter.
* **TaskMenu** – central action hub:
  - Sleep slider up to `max_sleep_hours` (default 12).
  - Meal sizes: Small (0.5), Normal (1.0), Large (1.5) food units.
  - Recon row indicates availability window and disables outside 6 AM–12 AM.
  - Lead Away displays zombie count feedback and success/failure states.
  - Forging row shows food totals and opens `ForgingResultsPanel` for loot summaries.
* **ForgingResultsPanel** – rotates flavor text pools for basic/advanced finds, lists each item with quantity and contextual description (e.g., nails show bundle size, fuel notes total units).

## Debug & Testing Utilities
* `debug_test.gd` runs viewport sanity checks for layout math and keeps formatting inline with project style.

---
Use this guide as the authoritative reference for mechanics, resources, and probabilities. Update it whenever systems or data tables change so gameplay documentation stays in sync with the code.
