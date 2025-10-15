# Fire Tower Survival Feature Concepts

## Core Loop Enhancements
- **Dynamic Weather Fronts**: Spawn storm cells with 3-5 min durations affecting visibility, fire spread, and scavenging risk.
- **Tower Integrity Meter**: Track structural health from 0-100%; repairing requires lumber + metal and unlocks new floors at 60/80 thresholds.
- **Roaming NPC Survivors**: Procedurally spawn allies every 2-4 days with unique perks, morale needs, and trade offers.

## Exploration & Progression
- **Fog-of-War Wilderness**: Reveal map sectors (0.5 km grid) via scouting missions unlocking rare supply caches.
- **Relic Blueprints**: Drop legendary tower mods (e.g., solar arrays, auto-turrets) with tiered crafting chains.
- **Seasonal Events**: Rotate bi-weekly events (meteor shower, toxic bloom) that alter enemy types and resource yields.

## Overland Expedition Loop
- **Prep Phase Milestones**: Gate expedition start behind tower quests requiring stockpiles (food 10-15 units, medkits 3-5, tools durability 80%+).
- **Route Planning Map**: Unlock hex-map routes (5-9 tiles per leg) with terrain tags affecting stamina drain and encounter odds.
- **Checkpoint Atlas**: Press `M` to open an 8-node trek map; each checkpoint branches into two randomized legs lasting 3-8 in-game hours.
- **Location Deck**: Shuffle Overgrown Path, Clearing, Small Stream, Thick Forest, Old Campsite, Old Cave, and Hunting Stand cards when presenting the two travel choices.
- **Location Stat Index**:
  | Location | Hours Min | Hours Max | Rest % | Calories | Hazard Tier | Temperature Band | Travel Note |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | Overgrown Path | 3.5 | 5.5 | 15.0 | 620 | Watchful | Temperate | Tangled brush slows pace but keeps cover high. |
  | Clearing | 3.0 | 4.5 | 13.5 | 560 | Hostile | Warm | Open patch boosts morale though visibility cuts stealth. |
  | Small Stream | 4.0 | 5.5 | 15.0 | 600 | Hostile | Temperate | Cold water banks require steady footing to avoid slips. |
  | Thick Forest | 5.0 | 6.5 | 16.5 | 640 | Calm | Cool | Dense pines force cautious steps while cover stays high. |
  | Old Campsite | 4.0 | 6.0 | 15.0 | 590 | Watchful | Cool | Lootable ruins trade time for extra salvage under tarps. |
| Old Cave | 4.5 | 6.0 | 17.0 | 610 | Calm | Cold | Narrow crawl shields travelers from storms and scouts. |
  | Hunting Stand | 3.5 | 4.5 | 14.0 | 570 | Watchful | Cool | Elevated sightlines ease scouting but invite aerial drafts. |
- **Daily Trek Rhythm**: Structure each travel day into morning break camp, midday event, and dusk campfire crafting with time-sliced decisions.
- **Portable Craft Station**: Assemble the roaming bench (Metal Scrap ×2, Wood ×4, Ripped Cloth ×1, Plastic Sheet ×2, Nails ×5, Rock ×2, Crafted Knife) to unlock tier-1 crafting while hiking.
- **Trail Hazards & Boons**: Roll events (ambush, weather shift, wildlife cache) with risk/reward modifiers scaling by player morale 0-100.
- **Route Danger Curves**: Let shorter legs raise human/zombie/wolf encounter odds 25-60%, mitigated by equipped weapons (knife, bow + arrows) that convert incoming damage to bruises or null outcomes.

### Encounter Banding Draft
- **Calm Tier (08-15%)**: Long, concealed routes (Thick Forest, Old Cave) start here; knives reduce residual damage to 1-2 HP.
- **Watchful Tier (18-32%)**: Balanced legs (Overgrown Path, Old Campsite, Hunting Stand) sit mid-risk; bows or pistols nullify 50-75% of contact harm.
- **Hostile Tier (35-55%)**: Short, exposed paths (Clearing, Small Stream) spike risk; firearms or reinforced melee negate all but bleed procs.
- **Mitigation Rules**: Compute base chance from tier, apply -10% per prepared weapon slot, -5% for armor layers, and +10% when traveling fatigued above 65%.

### Location Differentiation Notes
- **Small Stream**: Only travel node granting fishing attempts; requires fishing pole + bait for standard catch odds. Forage bundle includes Mushrooms (1.00), Berries (1.00), Apples (0.50), Oranges (0.50), Raspberries (0.50), Blueberries (0.50), Walnuts (0.50), Grubs (0.50), Wood (0.00), Ripped Cloth (0.00), Rock (0.00), Feathers (0.00). Elevated wolf presence due to watering hole behavior.
- **Overgrown Path**: Uses the standard forage pool; pace slowed by foliage yet encounter pressure drops thanks to dense cover.
- **Clearing**: Fast traversal and standard loot; lack of cover drives higher hostile survivor, wolf, and zombie contact. Sun exposure nudges temperature above temperate.
- **Thick Forest**: Travel takes longer than Overgrown Path but enemy encounters stay minimal; shade keeps the ambient temperature cooler.
- **Old Campsite**: Weighted loot skew toward Cloth, Wood, Mechanical Parts, Electrical Parts, Scrap Metal, Batteries, Flashlight, Backpack, plus the Small Stream forage bundle. Encounter mix favors zombies and hostile survivors; wolves are rare. Cooler due to tarp sheltering.
- **Old Cave**: Default loot profile, safest encounter tier, colder climate, and grants rain protection while occupied.
- **Camp Morale System**: Track party morale using shelter quality, meal variety, and story prompts; low morale triggers debuffs or disputes.

## Combat & Defense
- **Elemental Ammo Crafting**: Combine chemicals to craft incendiary, cryo, or shock rounds with 3-tier potency scaling.
- **Siege Pattern AI**: Introduce nightly boss assaults with telegraphed weak points and countermeasure crafting.
- **Trap Grid System**: Place modular traps (snare, spike, flame) with upgrade paths unlocking at player level 5/10/15.

## Economy & Live Ops
- **Daily Contract Board**: Offer rotating missions with escalating rewards and soft-currency payouts.
- **Premium Cosmetic Crates**: Sell purely visual tower skins and survivor outfits with transparent drop rates.
- **Season Pass Track**: Provide free + premium reward lanes with mission-based XP and exclusive cosmetics.

## Social & Retention
- **Asynchronous Rescue Calls**: Allow players to send/receive aid packages using friend codes and cooldown timers.
- **Weekly Leaderboards**: Rank survival days, contract score, and tower condition with tiered soft rewards.
- **Photo Mode & Share**: Enable stylized screenshots with overlays for social sharing incentives.

## Modes & Leaderboards Expansion
- **Dual Leaderboards**: Track `Top 100 Survival Days` for tower stayers and `Fastest Extraction Time` for speed runners to support divergent mastery goals.
- **Mode Unlock Flow**: Gate Adventure Mode behind a `Day 25-30` radio call that opens extraction windows for 10-14 in-game days, encouraging prep in Survival Mode first.
- **Prep Checklist Hooks**: Surface tower goals (crafting station, ration packs 8-12, knife, fire starters 2-3) to prime players before the extraction window.
- **Encounter Scaling**: Keep Survival Mode tower-centric with escalating sieges while Adventure Mode layers travel hazards + extraction deadlines.
- **Cinematic Story Beats**: Use radio chatter, campfire cut-ins, and departure flyovers to sell the shift from hunkering down to mobilizing.
- **Mobile Market Cues**: Borrow from top survival mobile titles—short cinematic intros, milestone recap reels, and auto-record highlights for social share boosts.
- **Alternate Competitive Hooks**: Offer rotating challenge modifiers (hardcore permadeath, resource drought weeks) plus co-op relay timers to keep boards fresh.
- **Extraction Variants**: Experiment with staggered evac convoys (truck, heli, boat) requiring different gear checks so Adventure runs stay replayable.

## Quality of Life & Accessibility
- **Guided Onboarding Flow**: Present step-based tutorials with skip toggles and tooltips locked to UI anchors.
- **Adaptive Difficulty Bands**: Monitor player survival time and adjust spawn intensity +/-20% dynamically.
- **Customization Presets**: Save/load control + HUD layouts, colorblind palettes, and vibration strengths (0-100).

## Task Additions
- **Travel to Next Location**: Expedition leg action consuming 3-8 hours, 15% energy, and 600 calories while locking in a chosen checkpoint route and refreshing morale rolls per travel day.

## Crafting Additions
- **Portable Craft Station Recipe**: 1.5 hour build taxing 17.5% energy, consumes Metal Scrap ×2, Wood ×4, Ripped Cloth ×1, Plastic Sheet ×2, Nails ×5, Rock ×2, and a Crafted Knife to seed roaming craft access.

## Survival Mode Onboarding Prompts
- **Welcome Briefing (Spawn +00:30)**: Friendly dispatcher introduces the tower post, highlights the radio console, crafting bench, ration prep, and lookout duties while hinting that sharper blades boost butchering yield.
- **Observation Deck Primer (First Ladder Climb)**: Explains spotting fires, scouting for smoke trails, and logging sightings; reminds that binocular upgrades widen the scan arc.
- **Supply Locker Overview (First Inventory Open)**: Lists accessible storage slots, notes that tidy stacks speed crafting, and teases reinforced packs for higher carry weight.
- **Workbench Coaching (First Craft Menu Access)**: Walks through selecting recipes, references the need for knives, cloth, and tinder, and nudges players toward keeping spare tool durability above 60-80%.
- **Cooking & Butchery Tip (First Raw Meat Pickup)**: Covers stove usage, drying racks, and food yields (small 0.5, medium 1.0, large 1.5) while musing that a honed cleaver trims waste.
- **Fishing Advisory (First Bait Looted)**: Clarifies that only the Small Stream supports fishing, reiterates pole + bait requirements, and warns of bait loss or line snaps if reels jam.
- **Hunting Safety Card (First Bow Equip)**: Mentions stalking wildlife, chance to break arrows on hard hits, and how clean shots reduce noise that might lure threats.
- **Water & Hygiene Memo (First Canteen Fill)**: Emphasizes boiling procedures, infection avoidance, and benefits of soap or filters to stretch supplies.
- **Nightfall Routine Reminder (First Sunset Event)**: Suggests lighting lanterns, boarding windows, and rationing firewood; hints that crafted shutters shield against nightly drafts.
- **Maintenance Checklist (Tower Integrity < 75%)**: Details repairing rails, patching leaks, and keeping nails ready; points out that upgraded hammers cut fix time.
- **Radio Dispatch Alert (Day 03 Morning)**: Encourages daily check-ins, logging weather, and listening for survivor distress calls that may lead to side objectives.
- **Morale Pulse (First Negative Mood Debuff)**: Explains social activities, music players, or journaling to recover morale, suggesting that better seating softens the blow.
- **Medical Bench Brief (First Injury Taken)**: Outlines bandage crafting, antiseptic use, and the risk of untreated wounds; hints that cleaner cloth reduces infection odds.
- **Defense Drill (First Siege Warning)**: Guides trap placement, tower door reinforcement, and ammo prep while teasing advanced barricades unlocked later.
- **Resource Scarcity Prompt (Any Core Resource < 20%)**: Advises on rationing plans, outlines viable scavenging hotspots, and reminds that planned excursions require rested stamina.
