# Firetower Survival Guide

## Core Loop Snapshot
* **Day Cycle**: Daybreak at 6:00 AM, 1,440 total minutes per day maintained by `TimeSystem`.
* **Action Flow**: `GameManager` advances the clock, burns calories, and updates rest using sleep/weather multipliers per activity.
* **Weather Cadence**: Hourly precipitation roll while clear (5% start chance). Successful rolls weight intensity heavy 15%, rain 35%, sprinkling 50% with default durations 5h/2h/1h.
* **Zombie Pressure**: Spawn checks start on Day 6. Successful day rolls schedule one wave (hour 0-23) and apply `0.5 * zombies` tower damage every 360 minutes while active.
* **Recon Window**: Available 6:00 AM–12:00 AM. Costs 60 minutes + 150 calories and snapshots six-hour weather/zombie forecasts using the live RNG seed.

## Systems Reference

### GameManager (`scripts/GameManager.gd`)
* **Role**: survival coordinator that instantiates systems, owns task actions, and relays signals to UI.
* **Signals**
  - `day_changed(new_day)` – broadcast after `_on_day_rolled_over`.
  - `weather_changed(new_state, previous_state, hours_remaining)` – fired from `_on_weather_system_changed`.
  - `weather_multiplier_changed(new_multiplier, state)` – exposes weather activity scaling to UI.
  - `lure_status_changed(status)` – delivers pre-emptive lure readiness data to the HUD/task menu.
  - `trap_state_changed(active, state)` – announces trap deployment, arming, and trigger payloads to HUD/task panels.
* **Key constants**
  - `CALORIES_PER_FOOD_UNIT = 1000` (1 food unit equals 1,000 calories).
  - `LEAD_AWAY_ZOMBIE_CHANCE = 0.80` (80% success per zombie).
  - `RECON_CALORIE_COST = 150` (burned during recon).
  - Trap profile: `TRAP_DEPLOY_HOURS = 2.0`, `TRAP_REST_COST_PERCENT = 15.0`, `TRAP_CALORIE_COST = 500`, `TRAP_BREAK_CHANCE = 0.5`.
  - Recon window bounds: `start_minute = 0` (6:00 AM), `end_minute = 1080` (12:00 AM) relative to daybreak.
* **Lifecycle**
  - `_ready()` – seeds RNG, spawns systems, hooks listeners, starts Day 1 spawn planning.
  - `pause_game()` / `resume_game()` – set `game_paused` flag.
* **System accessors**
  - `get_sleep_system()`, `get_time_system()`, `get_inventory_system()`, `get_weather_system()`, `get_tower_health_system()`, `get_news_system()`, `get_zombie_system()`.
  - `get_crafting_recipes()` – deep copy of crafting blueprint dictionary.
  - Recon helpers: `get_recon_window_status()` returns availability, cutoff, and resume timestamps.
  - Lure helpers: `get_lure_status()` exposes scouted spawn data, action availability, and failure reasons.
* **Player status getters**
  - `get_sleep_percent()`, `get_daily_calories_used()`, `get_player_weight_lbs()`, `get_player_weight_kg()`, `get_weight_unit()`.
  - `set_weight_unit(unit)` / `toggle_weight_unit()` – pass-through to `SleepSystem`.
  - Multipliers: `get_time_multiplier()`, `get_weather_activity_multiplier()`, `get_combined_activity_multiplier()`.
* **Radio & narrative**
  - `request_radio_broadcast()` – returns cached `NewsBroadcastSystem` message for the current day (or static when missing).
* **Task actions**
  - `perform_eating(portion_key)` – spends 1 activity hour, converts food units to calories, and updates weight.
  - `schedule_sleep(hours)` – restores energy (10% per hour), burns 100 calories/hour, and advances time using the combined multiplier. Duration auto-truncates if daybreak would be crossed.
  - `perform_forging()` – requires no active zombies, consumes 1 hour plus 12.5% energy, burns 500 calories, rolls `_roll_forging_loot()`, and awards inventory loot.
  - `perform_fishing()` – spends 1 hour, removes 10% energy, burns 650 calories, runs five 30% catch rolls, applies grub loss, and grants food per fish size.
  - `perform_lure_incoming_zombies()` – triggers only after recon scouts a spawn within 120 minutes, consumes 4 hours plus 1000 calories, cancels the pending wave, and clears lure state.
  - `perform_lead_away_undead()` – spends 1 hour plus 15% energy, rolls each zombie at 80% success, and updates counts.
  - `perform_trap_deployment()` – consumes 2 scaled hours, burns 500 calories, spends 15% rest, converts one crafted spike trap into a deployed defense, and flags HUD/task menu state updates.
  - `perform_recon()` – restricted to recon window, consumes 1 hour plus 150 calories, snapshots RNG, and returns six-hour weather and zombie forecasts.
  - `repair_tower(materials)` – costs 1 hour and 1 wood, burns 350 calories, grants 10% energy bonus, restores 5 tower health (capped at 100).
  - `reinforce_tower(materials)` – costs 2 hours, 3 wood, 5 nails, burns 450 calories, spends 20% energy, adds 25 health up to 150 cap.
  - `craft_item(recipe_id)` – validates materials, spends recipe time (scaled by multipliers), consumes optional energy %, and adds crafted goods.
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
  - `_broadcast_trap_state()` – synchronizes trap deployment/trigger dictionaries to HUD and action menu listeners.

### SleepSystem (`scripts/systems/SleepSystem.gd`)
* **Role**: track energy/rest %, daily calories, and weight-based activity multipliers.
* **Core constants**
  - Energy bounds: `MIN_SLEEP_PERCENT = 0`, `MAX_SLEEP_PERCENT = 100`, `SLEEP_PERCENT_PER_HOUR = 10` recovered via sleep.
  - Calorie costs: `CALORIES_PER_SLEEP_HOUR = 100`, `AWAKE_CALORIES_PER_HOUR = 23`.
  - Weight conversion: `CALORIES_PER_POUND = 1000`.
  - Weight thresholds (lbs): `<=149 malnourished`, `150-200 average`, `>=201 overweight`.
* **Signals** – `sleep_percent_changed`, `daily_calories_used_changed`, `weight_changed`, `weight_category_changed`, `weight_unit_changed`.
* **Public API**
  - Getters: `get_sleep_percent()`, `get_daily_calories_used()`, `get_player_weight_lbs()`, `get_player_weight_kg()`, `get_display_weight()`, `get_weight_unit()`, `get_weight_category()`, `get_time_multiplier()` (2.0 malnourished, 1.5 overweight, 1.0 average).
  - Unit controls: `set_weight_unit(unit)`, `toggle_weight_unit()`.
  - Energy management: `apply_sleep(hours)`, `consume_sleep(percent)`, `apply_rest_bonus(percent)`.
  - Calorie handling: `apply_awake_minutes(minutes)`, `adjust_daily_calories(delta)`, `reset_daily_counters()`.
* **Internals** – `_apply_calorie_delta(calorie_delta)` adjusts weight, `_update_weight(new_weight_lbs)` fires signals, `_determine_weight_category(weight_lbs)` maps thresholds.
### Task Blueprint: Lead Away (`GameManager.perform_lead_away_undead`)
* **Prerequisites**: Requires live `TimeSystem`, `SleepSystem`, `ZombieSystem`, and seeded RNG. Aborts with `systems_unavailable` when any link is absent.
* **Availability Check**: Fails fast if `ZombieSystem.has_active_zombies()` returns false, flagging `no_zombies` and recording pre-action totals for UI context.
* **Time Management**: Consumes 60 base minutes. `_spend_activity_time()` expands duration via `combined activity multiplier`, blocks execution if the scaled time would cross the 6:00 AM boundary, and records awake calorie burn.
* **Rest Cost**: Applies `consume_sleep(15.0)` on success. The rest delta is appended to the action payload for downstream displays and to drive fatigue effects.
* **Roll Resolution**:
  - Uses `LEAD_AWAY_ZOMBIE_CHANCE` (default 0.80) per active undead.
  - `ZombieSystem.attempt_lead_away(chance, rng)` rolls once per zombie, counts successes, mutates active total, and emits change signals when the horde shrinks.
  - The report captures attempts, successes, failures, and the resolved chance so UI logs can echo roll context (e.g., "80% per undead, 3 tried").
* **Post-Action Payload**:
  - Clones time-spent metadata returned by `_spend_activity_time()`.
  - Appends rest delta (`-15%`), zombie count before/after, and roll breakdown (`attempts`, `successes`, `failures`).
  - Includes `success` boolean (true when at least one undead departs) plus descriptive `reason` values such as `zombies_stayed` for zero-success outcomes.
* **Logging**: Emits debug prints summarizing zombies removed and attempts made to simplify QA verification.

### BodyWeightSystem (`scripts/systems/BodyWeightSystem.gd`)
* **Role**: Optional calorie-to-weight ledger for future health features (not wired into core loop yet).
* **Weight Bands**: Malnourished `<150 lbs`, skinny `150–179 lbs`, healthy `180–219 lbs`, overweight `≥220 lbs`.
* **Daily Tracking**: `consume_food(calories)`, `burn_calories(calories)`, `calculate_daily_weight_change()` (resets counters and yields net delta).
* **Display Helpers**: `set_display_unit(unit)`, `get_display_weight()`, `get_weight_display_string()`, `get_calorie_summary()`.
* **Category Helpers**: `get_weight_category()`, `get_weight_category_name()`, `get_weight_effects()` describe narrative modifiers.

### TimeSystem (`scripts/systems/TimeSystem.gd`)
* **Role**: Authoritative in-game clock anchored at 6:00 AM (`DAY_START_MINUTE = 360`).
* **Constants**: `MINUTES_PER_DAY = 1440`, `DAY_START_MINUTE = 360`.
* **Signals**: `time_advanced(minutes, crossed_daybreak)`, `day_rolled_over()` for multi-day ticks.
* **Public API**:
  - Time Queries: `get_minutes_since_daybreak()`, `get_minutes_until_daybreak()`, `get_minutes_since_midnight()`, `get_formatted_time()`, `get_formatted_time_after(minutes)`.
  - Mutation: `advance_minutes(duration)` clamps to `≥0`, emits rollover events per 24h crossed, and returns metadata for logging/UI.
* **Internals**: `_format_minutes(total_minutes)` renders 12-hour clock strings with AM/PM.

### WeatherSystem (`scripts/systems/WeatherSystem.gd`)
* **Role**: Hourly precipitation state machine with forecast cloning.
* **States**: `clear`, `sprinkling`, `raining`, `heavy_storm`.
* **Roll Profile**:
  - Start Chance: `RAIN_START_CHANCE = 0.05` while clear.
  - Intensity Weights: heavy `0.15`, raining `0.35`, sprinkling `0.50` (normalized when rain starts).
  - Default Durations: sprinkling `1h`, raining `2h`, heavy storm `5h` before re-roll.
* **Activity Multipliers**: `clear ×1.00`, `sprinkling ×1.25`, `raining ×1.50`, `heavy_storm ×1.75` applied to activity duration.
* **Signals**: `weather_changed(new_state, previous_state, hours_remaining)`, `weather_hour_elapsed(state)`.
* **Public API Highlights**: State queries, multipliers, precipitation checks, lifecycle hooks (`initialize_clock_offset`, `on_time_advanced`, `on_day_rolled_over`, `broadcast_state`), and forecast simulation (`forecast_precipitation(hours_ahead)`).
* **Internals**: `_process_hour_tick()`, `_begin_precipitation()`, `_set_state()`, `_format_state_debug()` govern state churn and debug output.

### TowerHealthSystem (`scripts/systems/TowerHealthSystem.gd`)
* **Role**: Manages base health, reinforcement cap, and environmental/zombie damage.
* **Health Ranges**: Base max `100 HP`, reinforced cap `150 HP`, dry-day decay `5 HP` when zero precipitation is logged.
* **Signals**: `tower_health_changed(new_health, previous)`, `tower_damaged(amount, source)`, `tower_repaired(amount, source)`.
* **Damage Profile**: Hourly precipitation wear `sprinkling 1`, `raining 2`, `heavy_storm 3` HP. Zombie damage routed via `GameManager` callbacks.
* **Public API**: Health queries, reinforcement/repair caps, weather state registration, day completion hook, and mutators (`apply_damage`, `apply_repair`, `apply_reinforcement`).
* **Internals**: `_is_precipitating_state(state)` mirrors `WeatherSystem` rules for consistent checks.

### InventorySystem (`scripts/systems/InventorySystem.gd`)
* **Role**: Item registry with stack, food, and signal management.
* **Signals**: `food_total_changed`, `item_added`, `item_consumed` emit after each mutation.
* **Bootstrap**: `bootstrap_defaults()` registers baseline item definitions (see Resource Catalog).
* **Definition Helpers**: `register_item_definition(item_id, definition)` ensures normalized display names, food units, stack limits; `ensure_item_definition(item_id)` auto-registers missing entries.
* **Query Surface**: `get_item_definition()`, `get_item_display_name()`, `get_item_count()`, `get_item_counts()`, `get_total_food_units()`.
* **Mutation Surface**:
  - Food: `set_total_food_units(amount)`, `add_food_units(delta)`, `has_food_units(amount)`, `consume_food_units(amount)`.
  - Items: `add_item(item_id, quantity)`, `consume_item(item_id, quantity)`, `clear()`.
* **Internals**: `_apply_food_delta(delta)` clamps totals and raises change signals.

### NewsBroadcastSystem (`scripts/systems/NewsBroadcastSystem.gd`)
* **Role**: Day-indexed radio feed generator with cached determinism.
* **Schedule Blocks**:
  - Days `1–3`: `mysterious_illness` (8 variants, 100%).
  - Days `4–7`: `supply_disruptions` (13 variants, 100%).
  - Days `8–10`: `martial_law` (5 variants, 100%).
  - Day `11+`: `collapse_alert` (3 variants, 25% chance; otherwise silence).
* **Signals**: `broadcast_selected(day, broadcast)` fires when caching a script.
* **Public API**: `reset_day(day)`, `get_broadcast_for_day(day)`, `clear_cache()` guarantee stable daily broadcasts.
* **Internals**: `_select_broadcast_for_day(day)` handles randomization, `_resolve_schedule_entry(day)` resolves the active block.

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
  - Pre-emption: `cancel_pending_spawn(day, minute)` removes a scheduled wave (returns event payload) and `restore_pending_spawn(event)` re-queues a cancelled wave.
  - Player actions: `attempt_lead_away(chance, rng)` – per-zombie roll with 0-1 outcome; `clear_zombies()` wipes active count; `remove_zombies(count)` deducts kills from traps or scripted events and emits `zombies_changed`.
  - Forecast: `preview_day_spawn(day_index, rng)` – mirrors `start_day` without mutating state.
* **Internals** – `_resolve_spawn_rolls(day)`, `_resolve_spawn_chance(day)`, `_pick_spawn_minute(rng)` (hour * 60), `_did_cross_marker(...)` handles wraparound, `_minutes_until_marker(...)`, `_resolve_pending_spawn(payload)` mutates counts.
### Weather-Aware Tower Interplay
* Precipitation ticks call `TowerHealthSystem.register_weather_hour(state)` each hour, applying wear according to intensity tables.
* Dry days leave `_had_precipitation_today` false; `on_day_completed()` then applies `5 HP` attrition to mimic structural fatigue.
* Recon weather forecast includes `events` with `minutes_ahead`, `state`, and `duration_hours` or `stop` entries for planning repairs or forging windows.

## Task & Action Catalog
| Action | Base Hours | Energy Impact | Calorie Impact | Requirements | Outcome |
| --- | --- | --- | --- | --- | --- |
| Sleep (`schedule_sleep`) | Input hours (auto-truncated) | +10% energy per hour (clamped 0-100) | -100 cal/hour (burn) | Open time before daybreak | Advances clock, refreshes energy %, burns calories, triggers awake calorie catch-up. |
| Eat (`perform_eating`) | 1h | None | -`food_units*1000` (net calories gained) | Sufficient food units | Consumes food, updates daily calories, returns weight snapshot. |
| Forge (`perform_forging`) | 1h | -12.5% energy | +500 cal burned (plus awake burn) | No active zombies | Rolls loot table, adds items, updates food totals. |
| Fish (`perform_fishing`) | 1h | -10% energy | +650 cal burned | Fishing Rod & ≥1 Grub (50% loss chance) | 5 rolls @30% each -> Small 50% (0.5), Medium 35% (1.0), Large 15% (1.5); adds food on hits. |
| Lure (`perform_lure_incoming_zombies`) | 4h | None | +1000 cal burned | Recon-scouted wave ≤120 min away, 4h window free | Cancels pending spawn at 100% success, clears lure target. |
| Lead Away (`perform_lead_away_undead`) | 1h | -15% energy | Awake burn only | Active zombies present | Rolls 80% per zombie to remove, updates counts. |
| Place Trap (`perform_trap_deployment`) | 2h | -15% energy | +500 cal burned | Spike Trap ×1 crafted, daylight remaining | Arms trap that kills the next zombie, 50% break chance, returns to inventory if intact, emits trap HUD status. |
| Recon (`perform_recon`) | 1h | None | +150 cal burned (`adjust_daily_calories`) | Time within 6 AM–12 AM | Returns six-hour forecast for weather and zombie spawns. |
| Repair (`repair_tower`) | 1h | +10% energy bonus | +350 cal burned | ≥1 wood, tower below 100 HP | Restores 5 HP, records materials used, updates health. |
| Reinforce (`reinforce_tower`) | 2h | -20% energy | +450 cal burned | ≥3 wood & 5 nails, tower below 150 HP | Adds 25 HP up to 150 cap, logs material spend. |
| Craft (varies) | Recipe hours | Recipe energy cost % | Awake burn; optional additional | Materials per recipe | Adds crafted item quantity, consumes inputs, tracks energy spend. |

## Crafting Recipes (`GameManager.CRAFTING_RECIPES`)
| Recipe | Output Qty | Hours | Energy Cost % | Material Costs | Notes |
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
* Sleep burn: 100 calories/hour plus +10% energy per hour restored.
* Repair bonus: +10% energy while burning 350 calories.
* Reinforce: -20% energy, +450 calories burned.
* Recon: +150 calories burned with no energy change.
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
* Recon lure workflow: when the forecast shows a wave arriving within 120 minutes, `get_lure_status()` unlocks the 4h lure action. Completing it spends 1,000 calories, cancels the pending spawn, and resets lure readiness.
* Active zombie damage fires every 6 hours (360 minutes) of accumulated time after the last attack or spawn resolution.
* Lead Away is the only direct mitigation outside of tower defenses—each zombie has an independent 80% chance to leave per attempt.
* Traps: `perform_trap_deployment()` arms a spike trap (2h, -15% rest, -500 cal); `GameManager._on_zombies_spawned` immediately calls `ZombieSystem.remove_zombies(1)` to kill the first zombie, rolls a 50% break chance, and returns the trap to inventory when intact.

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
* **HUD** – wires to all systems, exposes toggles like weight unit button (lbs/kg), displays tower health, food, wood, zombie counts, weather, clock, energy meter, and shows a 🪤 trap indicator while a trap is armed; the label surfaces break chance and deployment time straight from `trap_state_changed` payloads and hides automatically when traps are offline.
* **TaskMenu** – central action hub:
  - Grid layout presents four columns (label, summary text, control column, action button) so rows align cleanly; summary fonts use 13pt to fit long descriptions while keeping everything left-aligned for quick scanning.
  - Sleep slider up to `max_sleep_hours` (default 12) with a dedicated summary line (`+10% rest/hr | -100 cal/hr`) that previews queued hours, finish time, and remaining daylight.
  - Meal sizes: Small (0.5), Normal (1.0), Large (1.5) food units.
  - Recon row indicates availability window and disables outside 6 AM–12 AM.
  - Lead/Lure row swaps between lure readiness summaries (when scouted) and lead-away details, keeping zombie count feedback and success/failure states visible.
  - Trap row activates when at least one spike trap exists, summarizes rest/calorie cost, break chance, and shows armed/triggered states via `trap_state_changed`.
  - Forging row shows food totals and opens `ForgingResultsPanel` for loot summaries.
* **ForgingResultsPanel** – rotates flavor text pools for basic/advanced finds, lists each item with quantity and contextual description (e.g., nails show bundle size, fuel notes total units).

## Debug & Testing Utilities
* `debug_test.gd` runs viewport sanity checks for layout math and keeps formatting inline with project style.

---
Use this guide as the authoritative reference for mechanics, resources, and probabilities. Update it whenever systems or data tables change so gameplay documentation stays in sync with the code.
