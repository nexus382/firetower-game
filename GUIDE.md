# Firetower Survival Guide

## Core Loop Snapshot
* **Day Cycle**: Daybreak at 6:00 AM, 1,440 total minutes per day maintained by `TimeSystem`.
* **Action Flow**: `GameManager` advances the clock, burns calories, and updates rest using sleep/weather multipliers per activity.
* **Weather Cadence**: Hourly precipitation roll while clear (5% start chance). Successful rolls weight intensity heavy 15%, rain 35%, sprinkling 50% with default durations 5h/2h/1h.
* **Zombie Pressure**: Spawn checks start on Day 6. Successful day rolls schedule one wave (hour 0-23) and apply `0.5 * zombies` tower damage every 360 minutes while active.
* **Overland Trek Phase**: Unlocks after crafting the Portable Craft Station, exposing the 8-leg expedition map (`map_toggle` → `M`) with dual-route checkpoints controlled by `ExpeditionSystem`.
* **Wildlife Pressure**: Wolves roll a 15% daily arrival at dawn, reveal the scheduled hour during the 6 AM reset, linger 1–5 hours, and threaten outdoor tasks with a 30% 5–15 HP ambush until lured or defeated.
* **Recon Window**: Available 6:00 AM–12:00 AM. Costs 60 minutes + 150 calories and snapshots six-hour weather/zombie forecasts using the live RNG seed.
* **Thermal Pressure**: Warmth drifts hourly by daypart (6–10 AM -3/hr, 11 AM–5 PM +5/hr, 6–9 PM -3/hr, 10 PM–5 AM -10/hr); sleep blocks heat loss while allowing daytime gains so bedding keeps nights neutral and daylight rest restorative.

## Systems Reference

### GameManager (`scripts/GameManager.gd`)
* **Role**: survival coordinator that instantiates systems, owns task actions, and relays signals to UI.
* **Signals**
  - `day_changed(new_day)` – broadcast after `_on_day_rolled_over`.
  - `weather_changed(new_state, previous_state, hours_remaining)` – fired from `_on_weather_system_changed`.
  - `weather_multiplier_changed(new_multiplier, state)` – exposes weather activity scaling to UI.
  - `lure_status_changed(status)` – delivers pre-emptive lure readiness data to the HUD/task menu.
  - `trap_state_changed(active, state)` – announces trap deployment, arming, and trigger payloads to HUD/task panels.
  - `recon_alerts_changed(alerts)` – pushes upcoming weather/zombie notices to the HUD countdown banner.
  - `wolf_state_changed(state)` – publishes wolf schedule/active-state changes for task and recon updates.
* **Key constants**
  - `CALORIES_PER_FOOD_UNIT = 1000` (1 food unit equals 1,000 calories).
  - `LEAD_AWAY_ZOMBIE_CHANCE = 0.80` (80% success per zombie).
  - `RECON_CALORIE_COST = 150` (burned during recon).
  - Lure risk profile: `LURE_SUCCESS_INJURY_CHANCE = 10%` for 5 HP scrapes per diverted zombie, `LURE_FAILURE_INJURY_CHANCE = 25%` for 10 HP counter-hits from stragglers.
  - Trap profile: `TRAP_DEPLOY_HOURS = 2.0`, `TRAP_REST_COST_PERCENT = 15.0`, `TRAP_CALORIE_COST = 500`, `TRAP_BREAK_CHANCE = 0.5`, `TRAP_INJURY_CHANCE = 15%` for 10 HP mishaps while arming.
  - Crafting baseline: `CRAFT_ACTION_HOURS = 1.0` per recipe, `CRAFT_CALORIE_COST = 250` burned in addition to recipe-specific rest costs.
  - Recon window bounds: `start_minute = 0` (6:00 AM), `end_minute = 1080` (12:00 AM) relative to daybreak.
  - Wolf pressure: `WOLF_ATTACK_CHANCE = 30%` per outing while wolves surround the tower (damage roll 5–15 HP), `WOLF_LURE_SUCCESS_CHANCE = 75%` when spending the lure action on the pack.
  - Fight Back baseline: `FIGHT_BACK_REST_COST_PERCENT = 12.5` (rest drain on charge), `FIGHT_BACK_CALORIE_COST = 500` burned per sortie.
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
- `perform_forging()` – requires no active zombies, consumes 1 hour plus 10% energy, burns 300 calories, rolls `_roll_forging_loot()` (wood 45%, ripped cloth 30%, staple forage 20–25% bands), respects the 5-slot carry cap (12 with a Backpack), logs overflow drops, and, when wolves are posted outside, applies the 30% wolf strike (5–15 HP) before finalizing loot.
- `perform_campground_search()` – spends 4 hours plus 20% energy and 800 calories sweeping campsite loot (ripped cloth 55%, wood 45%, advanced bundles at 25%), honors carry-cap overflow handling, and rolls the same wolf strike chance whenever the pack is circling the tower.
- `perform_hunt()` – requires no active zombies, a crafted bow, and at least one arrow; consumes 2 hours plus 10% energy, burns 400 calories, fires up to three shots per trip (each with a 50% break chance) against a sequential animal table (Rabbit 30%/2 food, Squirrel 30%/2 food, Boar 20%/6 food, Doe 25%/5 food, Buck 20%/7 food), consumes broken arrows, adds food units, and banks raw game for Butcher/Cook Whole processing.
- `perform_butcher_and_cook()` – requires a crafted knife, a lit wood stove, and stored hunt/snare game; consumes 1 hour plus 5% energy, burns 150 calories, processes as much stored game food as remains in inventory, and grants a 25% food bonus rounded up to the nearest 0.5 while clearing processed game stock.
- `perform_cook_animals_whole()` – requires a lit wood stove and stored hunt/snare game; consumes 1 hour plus 5% energy, burns 150 calories, clears pending game stock without knife prep, and yields only the base food already stored.
- `perform_fishing()` – spends 1 hour, removes 10% energy, burns 650 calories, runs five 30% catch rolls (boosted to 45% during 6–9 AM or 5–8 PM prime time), applies grub loss, and grants food per fish size.
  - `perform_lure_incoming_zombies()` – triggers after recon scouts a zombie wave within 120 minutes or wolves occupy the clearing, consumes 4 hours plus 1,000 calories, cancels the pending wave or rolls the 75% wolf lure, and applies injury chances (10% per diverted zombie for 5 HP, 25% per straggler for 10 HP). The result includes tower threat counts, lure success/failure tallies, and total damage for the action popup.
  - `perform_lead_away_undead()` – spends 1 hour plus 15% energy, rolls each zombie at 80% success, and updates counts.
- `perform_fight_back()` – requires wolves or zombies outside and either a crafted knife or a bow with at least one arrow; spends 1 hour (scaled) plus 12.5% rest and 500 calories, guarantees kills on all threats, and applies gear-based damage bands (knife 5–15 HP, bow 3–7 HP, both equipped 0–5 HP).
- `perform_trap_deployment()` – consumes 2 scaled hours, burns 500 calories, spends 15% rest, converts one crafted spike trap into a deployed defense, flags HUD/task menu state updates, and has a 15% chance to inflict 10 HP self-injury with a dedicated popup.
- `perform_place_snare()` – requires no nearby zombies and at least one crafted Animal Snare; consumes 1 scaled hour, spends 5% rest, burns 250 calories, removes one snare from inventory, and tracks the deployment for hourly 40% rabbit/squirrel catch rolls (each worth 2 food units) until collected for cooking.
- `perform_check_snares()` – requires active snares and a clear area; consumes 0.5 scaled hours, spends 2% rest, burns 50 calories, retrieves any animals waiting in deployed snares (banking 2 food units per rabbit/squirrel into the same pending game stock used by Hunt processing), and reports when the lines are still empty.
- `perform_recon()` – restricted to recon window, consumes 1 hour plus 150 calories, snapshots RNG, returns six-hour weather and zombie forecasts, triggers the recon outlook popup, and seeds HUD countdown alerts for incoming rain or waves.
  - `repair_tower(materials)` – costs 1 hour and 1 wood, burns 350 calories, grants 10% energy bonus, restores 5 tower health (capped at 100).
  - `reinforce_tower(materials)` – costs 2 hours, 3 wood, 5 nails, burns 450 calories, spends 20% energy, adds 25 health up to 150 cap.
  - `craft_item(recipe_id)` – validates materials, spends a fixed 1 hour (scaled by multipliers), burns 250 calories, consumes recipe-specific rest, and adds crafted goods.
* **Internal helpers**
  - `_roll_forging_loot()` – iterates forging loot table (see Resource Catalog) using stored RNG.
  - `_on_day_rolled_over()` – increments `current_day`, resets calories, applies dry-day damage, refreshes news, and schedules the next zombie wave.
  - `_on_weather_system_changed()` / `_on_weather_hour_elapsed()` – rebroadcast weather and apply hourly precipitation wear.
  - `_on_time_advanced_by_minutes(minutes, rolled_over)` – feeds elapsed minutes into `ZombieSystem`, advances active snares, and applies resulting tower damage.
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

### PlayerHealthSystem (`scripts/systems/PlayerHealthSystem.gd`)
* **Role**: track survivor health (0–100 HP), clamp mutations, and raise injury/heal signals for UI reactions.
* **Signals**: `health_changed(new_health, previous)`, `damaged(amount, source, new_health)`, `healed(amount, source, new_health)`.
* **Public API**: `get_health()`, `get_max_health()`, `get_health_ratio()`, `get_health_percent()`, `apply_damage(amount, source)`, `apply_heal(amount, source)`, `set_health(value)`, `is_alive()`.
* **Usage**: Instantiated by `GameManager`, surfaced via `get_health_system()`, and consumed by HUD, lure/trap injuries, and healing items to keep the health bar synchronized.
### WarmthSystem (`scripts/systems/WarmthSystem.gd`)
* **Role**: track ambient warmth (0–100 range), apply hourly drift by daypart, and emit changes for HUD displays.
* **Core constants**
  - Bounds: `MIN_WARMTH = 0`, `MAX_WARMTH = 100`, `DEFAULT_WARMTH = 65` baseline comfort.
  - Drift rates per hour: early morning 6–10 AM `-3`, daytime 11 AM–5 PM `+5`, evening 6–9 PM `-3`, overnight 10 PM–5 AM `-10`.
  - Flashlight synergy placeholder: `FLASHLIGHT_WARMTH_BONUS = 0` reserved for future upgrades.
* **Signals** – `warmth_changed(new_warmth, previous_warmth)` keeps HUD meters synchronized with environment ticks.
* **Public API**
  - Queries: `get_warmth()`, `get_warmth_percent()` (already clamped within bounds).
  - Mutation: `set_warmth(value)` clamps and emits; `apply_warmth_delta(delta)` applies relative adjustments.
  - Environment ticks: `apply_environment_minutes(minutes, start_minutes_since_daybreak, is_sleeping)` batches per-hour drift, blocks heat loss while the survivor sleeps in bedding, and returns delta metadata for logs.
  - Forecast: `preview_hourly_rate(minute_of_day)` reveals upcoming hourly drift for planning.
* **Integration**: `GameManager` advances warmth whenever actions spend minutes; the HUD displays warmth percent alongside health, rest, and calories so night expeditions and sleep cycles expose thermal strain immediately.
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
* **Carry Limit**: `DEFAULT_CARRY_CAPACITY = 5` slots (12 when `backpack` is held); `_apply_carry_capacity` clips forging/camp loot and reports `dropped_loot` for UI summaries.
* **Internals**: `_apply_food_delta(delta)` clamps totals and raises change signals.
* **Portable Craft Station**: Register `portable_craft_station` as a crafted deployable with a stack limit of 1 and the `travel_crafting_enabled` flag so the expedition loop can authorize recipes while hiking.

### ExpeditionSystem (`scripts/systems/ExpeditionSystem.gd`)
* **Role**: Multi-day wilderness trek coordinator that sequences checkpoints, draws travel routes, and feeds UI summaries.
* **Checkpoint Schema**: Eight sequential legs (0–7) each store `available_routes` (two entries), `selected_route_index` (`null` until chosen), and `completed` (`false`/`true`).
* **Route Payload**: Every route defines `location_id`, `display_name`, `travel_hours` (baseline 4.0–12.0 window), and optional modifiers (`rest_delta`, `calorie_delta`, `morale_delta`) so balancing tweaks remain data-driven.
* **Location Deck**: Seed with the wilderness set (Overgrown Path, Clearing, Small Stream, Thick Forest, Old Campsite, Small Cave, Hunting Stand) and shuffle between checkpoints to keep legs fresh.
* **Progression Hooks**: `begin_expedition()` seeds RNG and draws first leg, `select_route(checkpoint_index, route_index)` commits a path, `advance_to_next_checkpoint()` flags completion, and `is_expedition_complete()` returns `true` once checkpoint 7 closes.
* **Task Integration**: Travel actions consume the selected route's payload, drive time advancement, and emit `expedition_progressed(checkpoint_index, route_data)` for HUD/map refreshes.

### MapPanel (`scripts/ui/MapPanel.gd`)
* **Role**: Toggleable expedition overlay bound to `map_toggle` (keyboard `M`) that reveals checkpoint status and available routes.
* **Layout**: Header row shows expedition day, carried supplies summary, and the currently highlighted checkpoint. A central grid renders checkpoint nodes with route cards listing location names, travel hours, and modifiers. Footer buttons expose `Select Route` and `Close Map` actions.
* **Input Flow**: `_process_input(event)` watches the map toggle, `_refresh_routes(checkpoint)` rebuilds route buttons using `ExpeditionSystem` data, and `_emit_route_selected(route_index)` delegates to `GameManager` once a choice is confirmed.
* **State Sync**: Listens for `expedition_progressed`, inventory change signals (for supply summaries), and task updates so the overlay mirrors live travel eligibility.

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

### WolfSystem (`scripts/systems/WolfSystem.gd`)
* **Role**: schedule daily wolf packs, track arrival/departure windows, and broadcast status for recon, lure, and fight workflows.
* **Core constants**: `DAILY_APPEAR_CHANCE = 0.15`, `MIN_DURATION_MINUTES = 60`, `MAX_DURATION_MINUTES = 300`; combat hooks reuse `WOLF_ATTACK_CHANCE = 0.30` (damage roll 5–15) and `WOLF_LURE_SUCCESS_CHANCE = 0.75`.
* **Signals** – `wolves_state_changed(state)` fires whenever a pack is scheduled, arrives, leaves, or is cleared.
* **Public API**: `start_day(day_index, rng)` rolls the day's schedule and emits the forecast, `advance_time(minutes, current_minutes_since_daybreak, rolled_over)` activates/deactivates packs as time advances, `has_active_wolves()` / `get_state()` surface presence details, `clear_wolves(reason)` removes the pack (Fight Back success, lure, etc.), `attempt_lure(chance, rng)` resolves diversion rolls, and `forecast_activity(hours_ahead, minutes_since_daybreak)` clones upcoming arrivals/departures for recon.
* **Internals** – `_activate_wolves(arrival_minute, current_minutes_since_daybreak)` and `_deactivate_wolves(reason)` mutate state dictionaries, `_did_cross_marker(...)` handles wrap-around detection, and `_emit_state()` deep-copies the payload before signaling.
### Weather-Aware Tower Interplay
* Precipitation ticks call `TowerHealthSystem.register_weather_hour(state)` each hour, applying wear according to intensity tables.
* Dry days leave `_had_precipitation_today` false; `on_day_completed()` then applies `5 HP` attrition to mimic structural fatigue.
* Recon weather forecast includes `events` with `minutes_ahead`, `state`, and `duration_hours` or `stop` entries for planning repairs or forging windows.

## Task & Action Catalog
| Action | Base Hours | Energy Impact | Calorie Impact | Requirements | Outcome |
| --- | --- | --- | --- | --- | --- |
| Sleep (`schedule_sleep`) | Input hours (auto-truncated) | +10% energy per hour (clamped 0-100) | -100 cal/hour (burn) | Open time before daybreak | Advances clock, refreshes energy %, burns calories, triggers awake calorie catch-up. |

### UI Reference
* **Task Menu Sleep Planner**: Shows queued versus usable rest when dawn would trim the request, including the exact hours applied, energy restored, calories burned, and the dawn-cut duration preview.
* **Crafting Panel Layout**: Recipe rows keep left-aligned buttons with padded margins and a dedicated cost column rendered as bullet rows (material stock, build time, rest tax, calorie burn) for quick scanning.
| Eat (`perform_eating`) | 1h | None | -`food_units*1000` (net calories gained) | Sufficient food units | Consumes food, updates daily calories, returns weight snapshot. |
| Forge (`perform_forging`) | 1h | -10% energy | +300 cal burned (plus awake burn) | No active zombies | Rolls loot table (wood 45%, ripped cloth 30%, staple forage 20–25%, advanced tech 5–15%), respects carry cap 5 (12 with Backpack), logs overflow, and applies a 30% wolf strike (5–15 HP) when a pack is active. |
| Search Campground (`perform_campground_search`) | 4h | -20% energy | +800 cal burned (plus awake burn) | No active zombies | Sweeps a campsite loot table (ripped cloth 55%, wood 45%, advanced bundles 25%), honors carry cap 5 (12 with Backpack), reports dropped overflow, and shares the same wolf strike risk while wolves surround the tower. |
| Hunt (`perform_hunt`) | 2h | -10% energy | +400 cal burned (plus awake burn) | No active zombies, Bow equipped, ≥1 Arrow | Up to three shots per trip (50% break chance each); sequential rolls Rabbit 30% (2 food), Squirrel 30% (2 food), Boar 20% (6 food), Doe 25% (5 food), Buck 20% (7 food). Broken arrows consumed, food added, raw game stored for Butcher/Cook Whole processing. |
| Butcher & Cook (`perform_butcher_and_cook`) | 1h | -5% energy | +150 cal burned | Crafted Knife, lit fire, stored hunt/snare game, sufficient food on hand | Converts available game into a 25% bonus rounded up to the nearest 0.5, deducts processed stock, and updates total food units. |
| Cook Animals Whole (`perform_cook_animals_whole`) | 1h | -5% energy | +150 cal burned | Lit fire, stored hunt/snare game | Clears pending game stock without a knife bonus, leaving base food totals untouched. |
| Fish (`perform_fishing`) | 1h | -10% energy | +650 cal burned | Fishing Rod & ≥1 Grub (50% loss chance) | 5 rolls @30% each (45% during 6–9 AM or 5–8 PM); Small 50% (0.5), Medium 35% (1.0), Large 15% (1.5); adds food on hits. |
| Lure (`perform_lure_incoming_zombies`) | 4h patrol | None | +1000 cal burned | Recon-scouted wave ≤120 min away, 4h window free | Cancels pending spawn, rolls 10%/zombie for 5 HP scrapes on each success, 25%/zombie for 10 HP hits on each failure, and reports totals through an action popup. |
| Lead Away (`perform_lead_away_undead`) | 1h | -15% energy | Awake burn only | Active zombies present | Rolls 80% per zombie to remove, updates counts. |
| Place Trap (`perform_trap_deployment`) | 2h setup | -15% energy | +500 cal burned | Spike Trap ×1 crafted, daylight remaining | Arms trap to auto-kill the next zombie, 50% break chance, 15% chance to take 10 HP self-injury (popup alerts on hurt). |
| Recon (`perform_recon`) | 1h | None | +150 cal burned (`adjust_daily_calories`) | Time within 6 AM–12 AM | Returns six-hour forecast for weather and zombie spawns. |
| Repair (`repair_tower`) | 1h | +10% energy bonus | +350 cal burned | ≥1 wood, tower below 100 HP | Restores 5 HP, records materials used, updates health. |
| Reinforce (`reinforce_tower`) | 2h | -20% energy | +450 cal burned | ≥3 wood & 5 nails, tower below 150 HP | Adds 25 HP up to 150 cap, logs material spend. |
| Craft (`craft_item`) | 1h baseline | Recipe energy cost % | +250 cal burned (fixed) | Materials per recipe | Consumes inputs, applies recipe rest cost, outputs item stack, and advances clock 1 scaled hour per craft. |
| Travel to Next Location (`perform_travel_to_next_location`) | Route-defined (default 4–12h) | -15% base plus route modifiers | Awake burn + route calorie delta | Expedition unlocked, route selected, supplies ≥ travel requirement | Spends the chosen route's travel hours, applies rest/calorie/morale adjustments, advances checkpoint progress, and unlocks the next leg on success. |

### Hunt & Snare Processing Flow
* **Catch Storage**: `perform_hunt` and `perform_check_snares` both add base food units immediately and bank totals in `_pending_game_food` for downstream cooking decisions.
* **Shared Readiness**: `_build_game_processing_context()` feeds `get_butcher_status()` and `get_cook_whole_status()` so the UI mirrors fire state, knife stock, carry totals, and cookable food in a single pass.
* **Action Gatekeeping**: `_prepare_game_processing()` enforces system availability, fire state, pending stock, and (when required) knife ownership before either cooking action spends time or energy.
* **Outcome Math**: `perform_butcher_and_cook()` awards a 25% bonus (rounded up to the nearest 0.5) while `perform_cook_animals_whole()` simply clears the stored game, keeping base food totals unchanged for players without a knife.

## Crafting Recipes (`GameManager.CRAFTING_RECIPES`)
| Recipe | Output Qty | Hours | Energy Cost % | Material Costs | Notes |
| --- | --- | --- | --- | --- | --- |
| Fishing Bait | 1 | 1.0 | 2.5 | Grubs ×1 | Zero food value output; burns 250 calories via craft action. |
| Fishing Rod | 1 | 1.0 | 7.5 | Rock ×1, String ×2, Wood ×2 | Stack limit 1 in inventory; burns 250 calories. |
| Rope | 1 | 1.0 | 5.0 | Vines ×3 | Utility rope; burns 250 calories. |
| Spike Trap | 1 | 1.0 | 12.5 | Wood ×6 | Defensive deployable; burns 250 calories. |
| The Spear | 1 | 1.0 | 5.0 | Wood ×1 | Close-defense tool; burns 250 calories. |
| String | 1 | 1.0 | 2.5 | Ripped Cloth ×1 | Intermediate crafting good; burns 250 calories. |
| Cloth Scraps | 2 | 1.0 | 2.5 | Ripped Cloth ×1 | Cuts fabric into pack-ready scraps; burns 250 calories. |
| Bandage | 1 | 1.0 | 5.0 | Ripped Cloth ×1 | Restores 10% health on use; burns 250 calories. |
| Herbal First Aid Kit | 1 | 1.0 | 12.5 | Mushrooms ×3, Ripped Cloth ×1, String ×1, Wood ×1, Medicinal Herbs ×2 | Heals 50 HP when used; burns 250 calories. |
| Medicated Bandage | 1 | 1.0 | 7.5 | Bandage ×1, Medicinal Herbs ×1 | Restores 25 HP on use; burns 250 calories. |
| Backpack | 1 | 1.0 | 15.0 | Wood ×4, String ×1, Rope ×1, Cloth Scraps ×3 | Expands carry limit to 12 slots for forging/camp loot; burns 250 calories. |
| Bow | 1 | 1.0 | 10.0 | Rope ×1, Wood ×1 | Flexible ranged base for Hunt (arrows have a 50% break chance per shot); burns 250 calories. |
| Arrow | 1 | 1.0 | 5.0 | Feather ×2, Rock ×1, Wood ×1 | Ammunition for Hunt; each shot rolls 50% to break (consumed) or returns to inventory. |
| Animal Snare | 1 | 1.0 | 10.0 | Rope ×2, Wood ×2 | Deployable loop trap for Place/Check Snare tasks; burns 250 calories. |
| Portable Craft Station | 1 | 1.0 | 12.5 | Metal Scrap ×2, Wood ×4, Cloth Scraps ×1, Plastic Sheet ×2, Nails ×5, Rock ×2, Crafted Knife ×1 | Grants on-the-go crafting access during expedition travel; consumes the listed materials and burns 250 calories. |

## Expedition Route Catalog
* **Overgrown Path**: Narrow trail with dense brush; moderate travel hours (5.0–8.0) and light morale drain due to constant clearing.
* **Clearing**: Open meadow segments; shorter travel hours (4.0–6.0) with minimal penalties but higher exposure to weather swings.
* **Small Stream**: Creekside detour; medium travel hours (6.0–8.0) with hydration bonus but cold checks if warmth is low.
* **Thick Forest**: Heavy canopy stretch; longer travel hours (7.0–11.0), rest tax, and stealth advantage versus roaming threats.
* **Old Campsite**: Abandoned rest stop; medium travel hours (5.5–7.5) with a loot roll for spare supplies and a minor infection risk.
* **Small Cave**: Rocky crawlspace; compact travel hours (4.5–6.5), warmth boost overnight, and chance to lose navigation time if light sources are absent.
* **Hunting Stand**: Elevated route; longer travel hours (6.5–9.5) but grants scouting intel that can reveal upcoming hazards on the next checkpoint.

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
| Wood | 40% | 1 | Basic | Repair & crafting staple. |
| Feather | 30% | 1 | Basic | Arrow fletching and bedding material. |
| Plastic Sheet | 10% | 1 | Advanced | Shelter upgrade material. |
| Metal Scrap | 10% | 1 | Advanced | Trap/armor material. |
| Nails | 10% | 3 | Advanced | Reinforcement resource. |
| Duct Tape | 10% | 1 | Advanced | Repair adhesive. |
| Medicinal Herbs | 10% | 1 | Advanced | Healing supplies. |
| Fuel | 10% | 3–5 | Advanced | Generator/heater fuel. |
| Mechanical Parts | 10% | 1 | Advanced | Trap maintenance. |
| Electrical Parts | 10% | 1 | Advanced | Powered projects. |
| Batteries | 15% | 1 | Advanced | Recharge consumable electronics. |
| Car Battery | 7.5% | 1 | Advanced | Heavy power core for large builds. |
| Flashlight | 5% | 1 | Advanced | Hand torch with battery upkeep. |

## Campground Loot Table (`_roll_campground_loot`)
* Independent rolls per entry with the same RNG as forging; successes respect the carry-cap limit (5 base, 12 with Backpack).

| Item | Chance | Quantity | Tier | Notes |
| --- | --- | --- | --- | --- |
| Mushrooms | 10% | 1 | Basic | +1.0 food unit. |
| Berries | 10% | 1 | Basic | +1.0 food unit. |
| Apples | 10% | 1 | Basic | +0.5 food unit. |
| Oranges | 10% | 1 | Basic | +0.5 food unit. |
| Raspberries | 10% | 1 | Basic | +0.5 food unit. |
| Blueberries | 10% | 1 | Basic | +0.5 food unit. |
| Walnuts | 10% | 1 | Basic | +0.5 food unit. |
| Grubs | 10% | 1 | Basic | +0.5 food unit. |
| Ripped Cloth | 40% | 1 | Basic | Raw textile for bandages or scraps. |
| Wood | 25% | 1 | Basic | Repair & crafting staple. |
| Plastic Sheet | 25% | 2 | Advanced | Shelter upgrade material. |
| Metal Scrap | 25% | 2 | Advanced | Trap/armor material. |
| Nails | 25% | 3 | Advanced | Reinforcement resource. |
| Duct Tape | 25% | 1 | Advanced | Repair adhesive. |
| Medicinal Herbs | 25% | 1 | Advanced | Healing supplies. |
| Fuel | 25% | 3–5 | Advanced | Generator/heater fuel. |
| Mechanical Parts | 25% | 2 | Advanced | Trap maintenance. |
| Electrical Parts | 25% | 2 | Advanced | Powered projects. |
| Canned Food | 15% | 1 | Provision | Counts as 1.5 food units. |
| Nails (5 Pack) | 20% | 5 | Advanced | Bulk reinforcement bundle. |
| Feather | 50% | 1 | Basic | Arrow fletching and bedding material. |

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
| feather | Feather | 0.0 | 99 |
| fishing_bait | Fishing Bait | 0.0 | 99 |
| fishing_rod | Fishing Rod | 0.0 | 1 |
| wood | Wood | 0.0 | 999 |
| bow | Bow | 0.0 | 1 |
| arrow | Arrow | 0.0 | 99 |
| animal_snare | Animal Snare | 0.0 | 20 |
| spear | The Spear | 0.0 | 1 |
| spike_trap | Spike Trap | 0.0 | 10 |
| ripped_cloth | Ripped Cloth | 0.0 | 99 |
| cloth_scraps | Cloth Scraps | 0.0 | 99 |
| string | String | 0.0 | 99 |
| rock | Rock | 0.0 | 99 |
| vines | Vines | 0.0 | 99 |
| rope | Rope | 0.0 | 99 |
| backpack | Backpack | 0.0 | 1 |
| plastic_sheet | Plastic Sheet | 0.0 | 99 |
| metal_scrap | Metal Scrap | 0.0 | 99 |
| nails | Nails | 0.0 | 999 |
| nails_pack | Nails (5 Pack) | 0.0 | 99 |
| duct_tape | Duct Tape | 0.0 | 99 |
| medicinal_herbs | Medicinal Herbs | 0.0 | 99 |
| canned_food | Canned Food | 1.5 | 99 |
| herbal_first_aid_kit | Herbal First Aid Kit | 0.0 | 10 |
| fuel | Fuel | 0.0 | 99 |
| mechanical_parts | Mechanical Parts | 0.0 | 99 |
| electrical_parts | Electrical Parts | 0.0 | 99 |
| batteries | Batteries | 0.0 | 99 |
| car_battery | Car Battery | 0.0 | 1 |
| flashlight | Flashlight | 0.0 | 1 |
| bandage | Bandage | 0.0 | 25 |
| medicated_bandage | Medicated Bandage | 0.0 | 10 |

### Healing Items & Usage
* Medicinal Herbs – use from the inventory panel to restore 10 HP (consumes one herb, no food value).
* Bandage – restores 10% health when used; crafted from 1 Ripped Cloth and flagged as a healing item in the inventory action column.
* Medicated Bandage – restores 25 HP when used; crafted from 1 Bandage plus 1 Medicinal Herb for a stronger emergency heal.
* Herbal First Aid Kit – use from the inventory panel to restore 50 HP (consumes one kit).

### Electrical Gear & Flashlight Upkeep
* Flashlight – advanced forging find (5% chance) with a dedicated inventory row showing battery percent and active state.
* Activation – selecting "Use" toggles the flashlight on; all action time while active drains `10%` battery per in-game hour (`FLASHLIGHT_BATTERY_DRAIN_PER_HOUR`).
* Battery swaps – selecting "Change Batteries" consumes 1× Batteries stack (if available), resets charge to 100%, and toggles the flashlight off so the next use starts fresh.
* Batteries – advanced forging consumable (15% chance) stored in stacks of 99 and required for flashlight maintenance; future electrical crafts can reuse this stockpile.
* Car Battery – heavy advanced drop (7.5% chance) reserved for generator-scale upgrades; currently stored in inventory with a stack cap of 1 for future systems.

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
* Recon lure workflow: when the forecast shows a wave arriving within 120 minutes, `get_lure_status()` unlocks the 4h lure action. Completing it spends 1,000 calories, cancels the pending spawn, rolls the injury profile, and resets lure readiness while showing a lure summary popup.
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
* **HUD** – wires to all systems and now uses a two-tier layout: the survivor panel on the left stacks rest/health/warmth bars, calorie totals, weight toggle, and category summary with consistent spacing, while the resource panel on the right keeps tower health, food, wood, zombie counts, and the 🪤 trap indicator aligned under the weight headline (shows current mass, category name, and the live range in the active unit); a bottom row hosts the day/time/weather block plus a dedicated recon alert card so countdowns never overlap other stats.
* **ActionPopupPanel** – shared popup surface for lure summaries, trap mishaps, recon forecasts, and other contextual alerts. Rich text supports multi-line stat readouts and injury/healing messaging.
* **TaskMenu** – central action hub:
  - Grid layout presents four columns (label, summary text, control column, action button) so rows align cleanly; summary fonts use 13pt to fit long descriptions while keeping everything left-aligned for quick scanning.
  - Sleep slider up to `max_sleep_hours` (default 12) with a dedicated summary line (`+10% rest/hr | -100 cal/hr`) that previews queued hours, finish time, and remaining daylight.
  - Meal sizes: Small (0.5), Normal (1.0), Large (1.5) food units.
  - Recon row indicates availability window, disables outside 6 AM–12 AM, and fires the recon outlook popup when complete.
  - Lead/Lure row swaps between lure readiness summaries (when scouted) and lead-away details, keeping zombie count feedback, success/failure states, and injury odds visible.
  - Trap row activates when at least one spike trap exists, summarizes rest/calorie cost, break chance, injury odds, and shows armed/triggered states via `trap_state_changed`.
  - Forging row shows food totals, carry slot usage, and opens `ForgingResultsPanel` for loot summaries.
  - Camp Search row mirrors forging, surfacing carry cap status, campsite loot odds, and pushing results through the same panel.
* **ForgingResultsPanel** – rotates flavor text pools for basic/advanced finds, lists each item with quantity and contextual description (e.g., nails show bundle size, fuel notes total units), and now highlights dropped overflow when the carry cap trims a haul.
* **Wood Stove** – sits along the living/kitchen seam with a raised hearth, door, ember window, and pipe cap so it reads clearly against the floor; interacting while inside its collision ring opens `WoodStovePanel` for fuel loads or fire-start attempts and the prompt auto-hides when you step away.

## Debug & Testing Utilities
* `debug_test.gd` runs viewport sanity checks for layout math and keeps formatting inline with project style.

---
Use this guide as the authoritative reference for mechanics, resources, and probabilities. Update it whenever systems or data tables change so gameplay documentation stays in sync with the code.
