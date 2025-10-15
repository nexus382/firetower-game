# Expedition Location Reference

This sheet summarizes every travel card currently wired into the expedition deck, the environment variables attached to each, and the special interactions players can expect when they venture out. Use it as a quick audit tool while tuning loot odds, encounter math, or tutorial copy.

| Location | Travel Hours (Min–Max) | Rest Cost % | Calorie Cost | Hazard Tier | Temperature Band | Encounter Focus (W/Z/S) | Forage Profile | Special Notes |
|----------|-----------------------:|------------:|-------------:|-------------|------------------|-------------------------|----------------|---------------|
| Overgrown Path | 3.5–5.5 | 15.0 | 620 | Calm | Temperate | 0.18 / 0.32 / 0.25 | wild_standard | Slow footing but thick brush keeps danger low; no rain cover.
| Clearing | 3.0–4.5 | 13.5 | 560 | Hostile | Warm | 0.33 / 0.35 / 0.32 | wild_standard | Fastest march yet exposed; expect daily radio chatter about ambushes.
| Small Stream | 4.0–5.5 | 15.0 | 600 | Hostile | Temperate | 0.55 / 0.25 / 0.20 | stream_banks | Wolves linger at the waterline; only node where fishing (pole + bait) is enabled.
| Thick Forest | 5.0–6.5 | 16.5 | 640 | Calm | Cool | 0.12 / 0.20 / 0.18 | wild_standard | Long slog under shade; great for stealthy travel but no rain shelter.
| Old Campsite | 4.0–6.0 | 15.0 | 590 | Watchful | Cool | 0.10 / 0.45 / 0.45 | camp_cache | Salvage-rich tents, higher human/zombie mix, and tarp cover from storms.
| Old Cave | 4.5–6.0 | 17.0 | 610 | Calm | Cold | 0.05 / 0.12 / 0.08 | cave_sparse | Safest refuge with rain protection; pack warmth for the chill crawlspace.
| Hunting Stand | 3.5–4.5 | 14.0 | 570 | Watchful | Cool | 0.28 / 0.36 / 0.36 | wild_standard | Raised blind, moderate risk, ideal for resetting stamina between pushes.

**Forage Profiles**

* `wild_standard`: Mixed wilderness loot — basic edibles, scrap essentials, and occasional advanced salvage.
* `stream_banks`: Fruit, nuts, grubs, and light materials gathered along the creek; supports fishing rewards.
* `camp_cache`: Salvage-heavy mix tuned toward cloth, lumber, mechanical and electrical gear, plus ration staples.
* `cave_sparse`: Minimal vegetation with stone, cloth scraps, and rare salvage tucked in dry recesses.

**Hazard Tiers & Mitigation Anchors**

* `calm`: 08–15% encounter odds. Knives reduce residual damage to 1–2 HP if danger triggers.
* `watchful`: 18–30% odds. Carrying both knife and bow trims 40% from incoming damage rolls.
* `hostile`: 35–55% odds. Firearms or reinforced melee gear required to avoid serious injury; mitigation caps at 60% reduction.

**Temperature Bands**

* `warm`: Sun exposure drives thirst and rest drain faster; use lighter clothing to avoid fatigue penalties.
* `temperate`: Baseline comfort range, minimal clothing checks.
* `cool`: Shade or elevation introduces chill; gloves and layered jackets keep morale steady.
* `cold`: Risk of hypothermia on long halts; bring fire starters or heated rations.

Keep this document in sync whenever route stats shift so designers, writers, and balance scripters have a single source of truth.
