# GameManager.gd overview:
# - Purpose: central survival coordinator wiring systems, player state, and UI accessors.
# - Sections: constants define recipes/meals, signals expose events, lifecycle hooks spawn systems, public getters share state.
extends Node
class_name GameManager

const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const WeatherSystem = preload("res://scripts/systems/WeatherSystem.gd")
const TowerHealthSystem = preload("res://scripts/systems/TowerHealthSystem.gd")
const NewsBroadcastSystem = preload("res://scripts/systems/NewsBroadcastSystem.gd")
const ZombieSystem = preload("res://scripts/systems/ZombieSystem.gd")
const WolfSystem = preload("res://scripts/systems/WolfSystem.gd")
const PlayerHealthSystem = preload("res://scripts/systems/PlayerHealthSystem.gd")
const WarmthSystem = preload("res://scripts/systems/WarmthSystem.gd")
const WoodStoveSystem = preload("res://scripts/systems/WoodStoveSystem.gd")
const ExpeditionSystem = preload("res://scripts/systems/ExpeditionSystem.gd")
const ActionPopupPanel = preload("res://scripts/ui/ActionPopupPanel.gd")

const CALORIES_PER_FOOD_UNIT: float = 1000.0
const LEAD_AWAY_ZOMBIE_CHANCE: float = ZombieSystem.DEFAULT_LEAD_AWAY_CHANCE
const RECON_CALORIE_COST: float = 150.0
const RECON_WINDOW_START_MINUTE: int = 0
const RECON_WINDOW_END_MINUTE: int = 18 * 60
const LURE_WINDOW_MINUTES: int = 120
const LURE_DURATION_HOURS: float = 4.0
const LURE_CALORIE_COST: float = 1000.0
const LURE_SUCCESS_INJURY_CHANCE: float = 0.10
const LURE_SUCCESS_INJURY_DAMAGE: float = 5.0
const LURE_FAILURE_INJURY_CHANCE: float = 0.25
const LURE_FAILURE_INJURY_DAMAGE: float = 10.0
const WOLF_ATTACK_CHANCE: float = 0.30
const WOLF_ATTACK_DAMAGE_MIN: int = 5
const WOLF_ATTACK_DAMAGE_MAX: int = 15
const WOLF_LURE_SUCCESS_CHANCE: float = 0.75
const FIGHT_BACK_HOURS: float = 1.0
const FIGHT_BACK_REST_COST_PERCENT: float = 12.5
const FIGHT_BACK_CALORIE_COST: float = 500.0
const FIGHT_BACK_KNIFE_DAMAGE_MIN: int = 5
const FIGHT_BACK_KNIFE_DAMAGE_MAX: int = 15
const FIGHT_BACK_BOW_DAMAGE_MIN: int = 3
const FIGHT_BACK_BOW_DAMAGE_MAX: int = 7
const FIGHT_BACK_COMBINED_DAMAGE_MIN: int = 0
const FIGHT_BACK_COMBINED_DAMAGE_MAX: int = 5
const FISHING_ROLLS_PER_HOUR: int = 5
const FISHING_ROLL_SUCCESS_CHANCE: float = 0.30
const FISHING_REST_COST_PERCENT: float = 10.0
const FISHING_CALORIE_COST: float = 650.0
const FISHING_GRUB_LOSS_CHANCE: float = 0.5
const FORGING_REST_COST_PERCENT: float = 10.0
const FORGING_CALORIE_COST: float = 300.0
const CAMP_SEARCH_HOURS: float = 4.0
const CAMP_SEARCH_REST_COST_PERCENT: float = 20.0
const CAMP_SEARCH_CALORIE_COST: float = 800.0
const HUNT_HOURS: float = 2.0
const HUNT_REST_COST_PERCENT: float = 10.0
const HUNT_CALORIE_COST: float = 400.0
const HUNT_ROLLS_PER_TRIP: int = 3
const HUNT_ARROW_BREAK_CHANCE: float = 0.5
const BUTCHER_HOURS: float = 1.0
const BUTCHER_REST_COST_PERCENT: float = 5.0
const BUTCHER_CALORIE_COST: float = 150.0
const COOK_WHOLE_HOURS: float = BUTCHER_HOURS
const COOK_WHOLE_REST_COST_PERCENT: float = BUTCHER_REST_COST_PERCENT
const COOK_WHOLE_CALORIE_COST: float = BUTCHER_CALORIE_COST
const FLASHLIGHT_BATTERY_MAX: float = 100.0
const FLASHLIGHT_BATTERY_DRAIN_PER_HOUR: float = 10.0
const TRAP_DEPLOY_HOURS: float = 2.0
const TRAP_CALORIE_COST: float = 500.0
const TRAP_REST_COST_PERCENT: float = 15.0
const TRAP_BREAK_CHANCE: float = 0.5
const TRAP_INJURY_CHANCE: float = 0.15
const TRAP_INJURY_DAMAGE: float = 10.0
const TRAP_ITEM_ID := "spike_trap"
const SNARE_ITEM_ID := "animal_snare"
const SNARE_PLACE_HOURS: float = 1.0
const SNARE_PLACE_CALORIE_COST: float = 250.0
const SNARE_PLACE_REST_COST_PERCENT: float = 5.0
const SNARE_CHECK_HOURS: float = 0.5
const SNARE_CHECK_CALORIE_COST: float = 50.0
const SNARE_CHECK_REST_COST_PERCENT: float = 2.0
const SNARE_CATCH_CHANCE: float = 0.40
const SNARE_ANIMAL_IDS := ["rabbit", "squirrel"]
const CRAFT_ACTION_HOURS: float = 1.0
const CRAFT_CALORIE_COST: float = 250.0
const FIRE_STARTING_BOW_ID := "fire_starting_bow"
const KINDLING_ID := "kindling"
const FLINT_AND_STEEL_ID := "flint_and_steel"
const CRAFTED_KNIFE_ID := "crafted_knife"
const PORTABLE_CRAFT_STATION_ID := "portable_craft_station"
const TRAVEL_REST_COST_PERCENT: float = 15.0
const TRAVEL_CALORIE_COST: float = 600.0
const TRAVEL_HOURS_MIN: float = 3.0
const TRAVEL_HOURS_MAX: float = 8.0
const FIRE_STARTING_BOW_SUCCESS_CHANCE: float = 0.75
const FIRE_STARTING_BOW_KINDLING_RETURN_CHANCE: float = 0.5
const FLINT_AND_STEEL_SUCCESS_CHANCE: float = 0.90
const HUNT_ANIMAL_TABLE := [
    {
        "id": "rabbit",
        "label": "Rabbit",
        "chance": 0.30,
        "food_units": 2.0
    },
    {
        "id": "squirrel",
        "label": "Squirrel",
        "chance": 0.30,
        "food_units": 2.0
    },
    {
        "id": "boar",
        "label": "Boar",
        "chance": 0.20,
        "food_units": 6.0
    },
    {
        "id": "doe",
        "label": "Doe",
        "chance": 0.25,
        "food_units": 5.0
    },
    {
        "id": "buck",
        "label": "Buck",
        "chance": 0.20,
        "food_units": 7.0
    }
]
const HUNT_ANIMAL_BASES := {
    "rabbit": 2.0,
    "squirrel": 2.0,
    "boar": 6.0,
    "doe": 5.0,
    "buck": 7.0
}
const HUNT_ANIMAL_LABELS := {
    "rabbit": "Rabbit",
    "squirrel": "Squirrel",
    "boar": "Boar",
    "doe": "Doe",
    "buck": "Buck"
}
const FISHING_SIZE_TABLE := [
    {
        "size": "small",
        "chance": 0.50,
        "food_units": 0.5
    },
    {
        "size": "medium",
        "chance": 0.35,
        "food_units": 1.0
    },
    {
        "size": "large",
        "chance": 0.15,
        "food_units": 1.5
    }
]

# Daily supply hamper keeps radio check-ins meaningful and stocked.
const DAILY_SUPPLY_MIN_ROLLS: int = 2
const DAILY_SUPPLY_MAX_ROLLS: int = 3
const DAILY_SUPPLY_EXPIRES_AFTER_DAYS: int = 1
const DAILY_SUPPLY_TABLE := [
    {
        "item_id": "berries",
        "quantity_range": [1, 2],
        "chance": 0.85,
        "category": "perishable"
    },
    {
        "item_id": "apples",
        "quantity_range": [1, 2],
        "chance": 0.75,
        "category": "perishable"
    },
    {
        "item_id": "oranges",
        "quantity_range": [1, 2],
        "chance": 0.75,
        "category": "perishable"
    },
    {
        "item_id": "raspberries",
        "quantity_range": [1, 3],
        "chance": 0.65,
        "category": "perishable"
    },
    {
        "item_id": "blueberries",
        "quantity_range": [1, 3],
        "chance": 0.65,
        "category": "perishable"
    },
    {
        "item_id": "walnuts",
        "quantity_range": [1, 3],
        "chance": 0.60,
        "category": "perishable"
    },
    {
        "item_id": "grubs",
        "quantity_range": [1, 2],
        "chance": 0.55,
        "category": "perishable"
    },
    {
        "item_id": "ripped_cloth",
        "quantity_range": [1, 2],
        "chance": 0.55,
        "category": "supply"
    },
    {
        "item_id": "wood",
        "quantity_range": [1, 3],
        "chance": 0.60,
        "category": "supply"
    },
    {
        "item_id": "fishing_bait",
        "quantity_range": [1, 2],
        "chance": 0.50,
        "category": "supply"
    },
    {
        "item_id": "nails",
        "quantity_range": [2, 4],
        "chance": 0.45,
        "category": "supply"
    }
]

# Travel hazard tiers define encounter chance ranges (0.0-1.0) for route rolls.
const TRAVEL_HAZARD_TIERS := {
    "calm": {
        "label": "Calm",
        "chance_min": 0.08,
        "chance_max": 0.15
    },
    "watchful": {
        "label": "Watchful",
        "chance_min": 0.18,
        "chance_max": 0.32
    },
    "hostile": {
        "label": "Hostile",
        "chance_min": 0.35,
        "chance_max": 0.55
    }
}

# Temperature bands shape warmth flavor for downstream systems.
const TEMPERATURE_BANDS := {
    "cold": {
        "label": "Cold",
        "modifier": -12.0
    },
    "cool": {
        "label": "Cool",
        "modifier": -6.0
    },
    "temperate": {
        "label": "Temperate",
        "modifier": 0.0
    },
    "warm": {
        "label": "Warm",
        "modifier": 4.0
    }
}

const DEFAULT_LOCATION_ID := "tower_base"

# Location profiles describe loot pools, climate, and access per route id.
const LOCATION_PROFILES := {
    "tower_base": {
        "label": "Fire Tower",
        "summary": "Home base overlooking the valley.",
        "hazard_tier": "calm",
        "temperature_band": "temperate",
        "forage_profile": "tower_standard",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.20,
            "zombies": 0.30,
            "survivors": 0.20
        },
        "shelter_from_rain": true
    },
    "overgrown_path": {
        "label": "Overgrown Path",
        "summary": "Tangled brush hides you while you creep along.",
        "hazard_tier": "calm",
        "temperature_band": "temperate",
        "forage_profile": "wild_standard",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.18,
            "zombies": 0.32,
            "survivors": 0.25
        },
        "shelter_from_rain": false
    },
    "clearing": {
        "label": "Clearing",
        "summary": "Open ground quickens the pace but exposes you.",
        "hazard_tier": "hostile",
        "temperature_band": "warm",
        "forage_profile": "wild_standard",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.33,
            "zombies": 0.35,
            "survivors": 0.32
        },
        "shelter_from_rain": false
    },
    "small_stream": {
        "label": "Small Stream",
        "summary": "Wolf-haunted banks with cold, steady water.",
        "hazard_tier": "hostile",
        "temperature_band": "temperate",
        "forage_profile": "stream_banks",
        "fishing_allowed": true,
        "encounter_focus": {
            "wolves": 0.55,
            "zombies": 0.25,
            "survivors": 0.20
        },
        "shelter_from_rain": false
    },
    "thick_forest": {
        "label": "Thick Forest",
        "summary": "Dense pines give cover but slow every step.",
        "hazard_tier": "calm",
        "temperature_band": "cool",
        "forage_profile": "wild_standard",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.12,
            "zombies": 0.20,
            "survivors": 0.18
        },
        "shelter_from_rain": false
    },
    "old_campsite": {
        "label": "Old Campsite",
        "summary": "Sheltered ruins stuffed with salvage and stories.",
        "hazard_tier": "watchful",
        "temperature_band": "cool",
        "forage_profile": "camp_cache",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.10,
            "zombies": 0.45,
            "survivors": 0.45
        },
        "shelter_from_rain": true
    },
    "old_cave": {
        "label": "Old Cave",
        "summary": "Cold, quiet shelter carved out of the ridge.",
        "hazard_tier": "calm",
        "temperature_band": "cold",
        "forage_profile": "cave_sparse",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.05,
            "zombies": 0.12,
            "survivors": 0.08
        },
        "shelter_from_rain": true
    },
    "hunting_stand": {
        "label": "Hunting Stand",
        "summary": "Raised blind with sweeping sightlines and drafts.",
        "hazard_tier": "watchful",
        "temperature_band": "cool",
        "forage_profile": "wild_standard",
        "fishing_allowed": false,
        "encounter_focus": {
            "wolves": 0.28,
            "zombies": 0.36,
            "survivors": 0.36
        },
        "shelter_from_rain": false
    }
}

# Forage profile tables define environment-specific loot rolls.
const FORAGE_PROFILE_TABLES := {
    "tower_standard": [
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
            "item_id": "apples",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "oranges",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "raspberries",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "blueberries",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "ripped_cloth",
            "chance": 0.30,
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
            "chance": 0.45,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "feather",
            "chance": 0.30,
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
        },
        {
            "item_id": "batteries",
            "chance": 0.15,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "car_battery",
            "chance": 0.075,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "flashlight",
            "chance": 0.05,
            "quantity": 1,
            "tier": "advanced"
        }
    ],
    "stream_banks": [
        {
            "item_id": "mushrooms",
            "chance": 0.40,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "berries",
            "chance": 0.40,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "apples",
            "chance": 0.30,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "oranges",
            "chance": 0.30,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "raspberries",
            "chance": 0.30,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "blueberries",
            "chance": 0.30,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "walnuts",
            "chance": 0.30,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "grubs",
            "chance": 0.35,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "wood",
            "chance": 0.45,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "ripped_cloth",
            "chance": 0.28,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "rock",
            "chance": 0.40,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "feather",
            "chance": 0.32,
            "quantity": 1,
            "tier": "basic"
        }
    ],
    "camp_cache": [
        {
            "item_id": "ripped_cloth",
            "chance": 0.62,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "wood",
            "chance": 0.55,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "mushrooms",
            "chance": 0.24,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "berries",
            "chance": 0.24,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "apples",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "oranges",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "raspberries",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "blueberries",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "walnuts",
            "chance": 0.20,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "grubs",
            "chance": 0.26,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "rock",
            "chance": 0.24,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "feather",
            "chance": 0.22,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "metal_scrap",
            "chance": 0.36,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "mechanical_parts",
            "chance": 0.34,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "electrical_parts",
            "chance": 0.32,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "batteries",
            "chance": 0.26,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "flashlight",
            "chance": 0.18,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": InventorySystem.BACKPACK_ITEM_ID,
            "chance": 0.14,
            "quantity": 1,
            "tier": "advanced"
        }
    ],
    "cave_sparse": [
        {
            "item_id": "mushrooms",
            "chance": 0.22,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "berries",
            "chance": 0.22,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "ripped_cloth",
            "chance": 0.25,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "wood",
            "chance": 0.32,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "rock",
            "chance": 0.45,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "grubs",
            "chance": 0.25,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "feather",
            "chance": 0.18,
            "quantity": 1,
            "tier": "basic"
        },
        {
            "item_id": "plastic_sheet",
            "chance": 0.06,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "metal_scrap",
            "chance": 0.08,
            "quantity": 1,
            "tier": "advanced"
        },
        {
            "item_id": "mechanical_parts",
            "chance": 0.08,
            "quantity": 1,
            "tier": "advanced"
        }
    ]
}

# Travel encounter damage ranges (min-max HP) per hostile type.
const TRAVEL_ENCOUNTER_DAMAGE := {
    "wolves": {
        "min": 5,
        "max": 15
    },
    "zombies": {
        "min": 8,
        "max": 18
    },
    "survivors": {
        "min": 10,
        "max": 22
    }
}

const TRAVEL_ENCOUNTER_TYPES := ["wolves", "zombies", "survivors"]

# Travel prep modifiers applied to encounter chance and damage resolution.
const TRAVEL_WEAPON_CHANCE_REDUCTION := {
    "knife": 0.12,
    "ranged": 0.15
}

const TRAVEL_ENCOUNTER_MITIGATION := {
    "none": 1.0,
    "single": 0.60,
    "dual": 0.25
}

# Crafting recipes advertised to the UI with pre-baked cost and time data.
const CRAFTING_RECIPES := {
    "fishing_bait": {
        "item_id": "fishing_bait",
        "display_name": "Fishing Bait",
        "description": "Fresh bait to tempt nearby fish.",
        "tips": [
            "Pair with a fishing rod at the small stream to hook fish worth 0.5-1.5 food units.",
            "Bait can wash away on a rough cast, so craft a few spares before dawn."
        ],
        "cost": {
            "grubs": 1
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 2.5,
        "quantity": 1
    },
    "fishing_rod": {
        "item_id": "fishing_rod",
        "display_name": "Fishing Rod",
        "description": "Simple pole ready for shoreline casting.",
        "tips": [
            "Needs bait each attempt and only the small stream currently supports fishing.",
            "Check your tackle every morning so you are ready when the radio hints at calm water."
        ],
        "cost": {
            "rock": 1,
            "string": 2,
            "wood": 2
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 7.5,
        "quantity": 1
    },
    "rope": {
        "item_id": "rope",
        "display_name": "Rope",
        "description": "Braided vines for tying or climbing.",
        "tips": [
            "Feeds bows, snares, and backpacks, so keep a small reserve for emergencies.",
            "Vines dry quickly indoors, making refills easy during stormy days."
        ],
        "cost": {
            "vines": 3
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 5.0,
        "quantity": 1
    },
    "spike_trap": {
        "item_id": "spike_trap",
        "display_name": "Spike Trap",
        "description": "Sturdy spikes to slow unwanted guests.",
        "tips": [
            "Stage near tower choke points so raiders bleed momentum before reaching you.",
            "Inspect after each skirmish; a quick reset keeps the trap lethal."
        ],
        "cost": {
            "wood": 6
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 12.5,
        "quantity": 1
    },
    "kindling": {
        "item_id": KINDLING_ID,
        "display_name": "Kindling",
        "description": "Dry shavings that boost fire starting odds.",
        "tips": [
            "Store beside the stove so every fire attempt begins with warm, dry tinder.",
            "Rainy streaks chew through bundles quickly; budget extras when storms roll in."
        ],
        "cost": {
            "wood": 1
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 2.5,
        "quantity": 3
    },
    "crafted_knife": {
        "item_id": CRAFTED_KNIFE_ID,
        "display_name": "Crafted Knife",
        "description": "Sharp edge for prepping fuel and projects.",
        "tips": [
            "Unlocks cleaner butchering and helps slice meat before cooking.",
            "Keep it honed so crafting benches and forage tasks finish faster."
        ],
        "cost": {
            "wood": 1,
            "metal_scrap": 2
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 7.5,
        "quantity": 1
    },
    "fire_starting_bow": {
        "item_id": FIRE_STARTING_BOW_ID,
        "display_name": "Fire Starting Bow",
        "description": "Bow drill offering 75% spark chance.",
        "tips": [
            "Performs best with fresh kindling; craft extra bundles before a cold night.",
            "Great fallback once flint is gone, but expect tired arms after long sessions."
        ],
        "cost": {
            "string": 2,
            "wood": 2
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 10.0,
        "quantity": 1
    },
    "flint_and_steel": {
        "item_id": FLINT_AND_STEEL_ID,
        "display_name": "Flint and Steel",
        "description": "Reliable sparks (5 uses, 90% success).",
        "tips": [
            "Carries five strong strikes; swap sets once the sparks grow weak.",
            "Shave tinder with a knife first so embers have something to bite."
        ],
        "cost": {
            CRAFTED_KNIFE_ID: 1,
            "rock": 2
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 10.0,
        "quantity": 5
    },
    "portable_craft_station": {
        "item_id": PORTABLE_CRAFT_STATION_ID,
        "display_name": "Portable Craft Station",
        "description": "Fold-out bench for on-foot crafting stops.",
        "tips": [
            "Pack it for expeditions so you can craft repairs away from the tower.",
            "Adds weight, so pair it with an upgraded backpack before long trips."
        ],
        "cost": {
            "metal_scrap": 2,
            "wood": 4,
            "ripped_cloth": 1,
            "plastic_sheet": 2,
            "nails": 5,
            "rock": 2,
            CRAFTED_KNIFE_ID: 1
        },
        "hours": 1.5,
        "rest_cost_percent": 17.5,
        "quantity": 1
    },
    "spear": {
        "item_id": "spear",
        "display_name": "The Spear",
        "description": "A sharpened pole for close defense.",
        "tips": [
            "Reliable backup when wolves close the distance at water sources.",
            "Combine with traps to finish wounded foes without wasting arrows."
        ],
        "cost": {
            "wood": 1
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 5.0,
        "quantity": 1
    },
    "string": {
        "item_id": "string",
        "display_name": "String",
        "description": "Twisted cloth cord for light bindings.",
        "tips": [
            "Critical for bows, snares, and med kits, so keep a few spares on hand.",
            "Spins from ripped cloth, letting you convert wardrobe scraps into utility."
        ],
        "cost": {
            "ripped_cloth": 1
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 2.5,
        "quantity": 1
    },
    "bandage": {
        "item_id": "bandage",
        "display_name": "Bandage",
        "description": "Clean wrap that restores 10% health.",
        "tips": [
            "Stops bleeding fast, making it perfect for post-fight triage.",
            "Combine with herbs later to brew stronger medical kits."
        ],
        "cost": {
            "ripped_cloth": 1
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 5.0,
        "quantity": 1
    },
    "herbal_first_aid_kit": {
        "item_id": "herbal_first_aid_kit",
        "display_name": "Herbal First Aid Kit",
        "description": "Bundle of salves and wraps to restore health.",
        "tips": [
            "Treats tougher wounds than a lone bandage—save one for rough expeditions.",
            "Forage herbs whenever the travel board opens to restock ingredients."
        ],
        "cost": {
            "mushrooms": 3,
            "ripped_cloth": 1,
            "string": 1,
            "wood": 1,
            "medicinal_herbs": 2
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 12.5,
        "quantity": 1
    },
    "medicated_bandage": {
        "item_id": "medicated_bandage",
        "display_name": "Medicated Bandage",
        "description": "Infused wrap that restores 25 health.",
        "tips": [
            "Layers a bandage with herbs for heavy recovery—ideal before boss fights.",
            "Keep one in reserve so you can bounce back after a bad ambush."
        ],
        "cost": {
            "bandage": 1,
            "medicinal_herbs": 1
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 7.5,
        "quantity": 1
    },
    "backpack": {
        "item_id": "backpack",
        "display_name": "Backpack",
        "description": "Rugged pack expanding carry slots to 12.",
        "tips": [
            "Extra slots let you haul more rations and ammo on long trips.",
            "Pairs nicely with the portable craft station and spare arrows."
        ],
        "cost": {
            "wood": 4,
            "string": 1,
            "rope": 1,
            "ripped_cloth": 3
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 15.0,
        "quantity": 1
    },
    "bow": {
        "item_id": "bow",
        "display_name": "Bow",
        "description": "Flexible bow for silent ranged attacks.",
        "tips": [
            "Requires arrows in your pack; silent shots keep you hidden while hunting.",
            "Bring a knife or spear to finish anything that closes the gap."
        ],
        "cost": {
            "rope": 1,
            "wood": 1
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 10.0,
        "quantity": 1
    },
    "arrow": {
        "item_id": "arrow",
        "display_name": "Arrow",
        "description": "Straight shaft for the crafted bow.",
        "tips": [
            "Shots can snap arrows, so craft backups before each hunt or raid.",
            "Track your targets—recovered arrows save cloth, wood, and feathers."
        ],
        "cost": {
            "feather": 2,
            "rock": 1,
            "wood": 1
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 5.0,
        "quantity": 1
    },
    "animal_snare": {
        "item_id": SNARE_ITEM_ID,
        "display_name": "Animal Snare",
        "description": "Loop trap fit for rabbits or squirrels.",
        "tips": [
            "Works best along quiet trails—ideal for overgrown paths and forest edges.",
            "Check snares daily so predators do not steal the catch."
        ],
        "cost": {
            "rope": 2,
            "wood": 2
        },
        "hours": CRAFT_ACTION_HOURS,
        "rest_cost_percent": 10.0,
        "quantity": 1
    }
}

# Meal size presets so UI and systems agree on food unit costs.
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

# Signals surfaced for UI widgets listening for macro-state changes.
signal day_changed(new_day: int)
signal weather_changed(new_state: String, previous_state: String, hours_remaining: int)
signal weather_multiplier_changed(new_multiplier: float, state: String)
signal lure_status_changed(status: Dictionary)
signal trap_state_changed(active: bool, state: Dictionary)
signal recon_alerts_changed(alerts: Dictionary)
signal wood_stove_state_changed(state: Dictionary)
signal hunt_stock_changed(stock: Dictionary)
signal snare_state_changed(state: Dictionary)
signal wolf_state_changed(state: Dictionary)
signal expedition_state_changed(state: Dictionary)
signal radio_attention_changed(active: bool)

# Core game state values shared between systems and UI.
var current_day: int = 1
var game_paused: bool = false

# Player reference cached once so interaction helpers can fetch it quickly.
var player: CharacterBody2D

# Simulation systems
# Instantiated immediately so UI elements resolving GameManager during their own _ready callbacks
# always see live systems instead of a null placeholder.
var sleep_system: SleepSystem = SleepSystem.new()
var inventory_system: InventorySystem = InventorySystem.new()
var time_system: TimeSystem = TimeSystem.new()
var weather_system: WeatherSystem = WeatherSystem.new()
var tower_health_system: TowerHealthSystem = TowerHealthSystem.new()
var health_system: PlayerHealthSystem = PlayerHealthSystem.new()
var news_system: NewsBroadcastSystem = NewsBroadcastSystem.new()
var zombie_system: ZombieSystem = ZombieSystem.new()
var wolf_system: WolfSystem = WolfSystem.new()
var warmth_system: WarmthSystem = WarmthSystem.new()
var wood_stove_system: WoodStoveSystem = WoodStoveSystem.new()
var expedition_system: ExpeditionSystem = ExpeditionSystem.new()
var _last_awake_minute_stamp: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lure_target: Dictionary = {}
var _last_lure_status: Dictionary = {}
var _trap_state: Dictionary = {
    "active": false,
    "status": "idle",
    "break_chance": TRAP_BREAK_CHANCE,
    "kills": 0,
    "deployed_day": 0,
    "deployed_at_minutes": -1,
    "deployed_at_time": ""
}
var _snare_deployments: Array = []
var _snare_state: Dictionary = {
    "total_deployed": 0,
    "active_snares": 0,
    "caught_snares": 0,
    "animals_ready": 0,
    "waiting_animals": [],
    "roll_chance": SNARE_CATCH_CHANCE
}
var _next_snare_id: int = 1
var _recon_alerts: Dictionary = {}
var _wolf_state: Dictionary = {}
var flashlight_battery_percent: float = 0.0
var flashlight_active: bool = false
var _pending_game_food: Dictionary = {}
var _radio_last_ack_day: int = 0
var _radio_tip_shown: bool = false
var _active_location: Dictionary = {}
var _tutorial_popup: ActionPopupPanel
var _tutorial_flags: Dictionary = {}
var _daily_supply_state: Dictionary = {}
var _daily_supply_spoil_notice: Dictionary = {}

# Wire together systems, seed defaults, and make sure listeners are ready before play begins.
func _ready():
    print("🎮 GameManager initialized - Day %d" % current_day)
    player = get_node("../Player")
    if player:
        print("✅ Player found and connected")
    else:
        print("❌ Player not found!")

    _active_location = _resolve_location_profile(DEFAULT_LOCATION_ID)
    _tutorial_flags.clear()

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
    if health_system == null:
        health_system = PlayerHealthSystem.new()
    if news_system == null:
        news_system = NewsBroadcastSystem.new()
    if zombie_system == null:
        zombie_system = ZombieSystem.new()
    if wolf_system == null:
        wolf_system = WolfSystem.new()
    if warmth_system == null:
        warmth_system = WarmthSystem.new()
    if wood_stove_system == null:
        wood_stove_system = WoodStoveSystem.new()
    if expedition_system == null:
        expedition_system = ExpeditionSystem.new()
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
    _spawn_daily_supply_drop("startup")
    _refresh_radio_attention("startup")
    if zombie_system:
        zombie_system.zombies_damaged_tower.connect(_on_zombie_damage_tower)
        zombie_system.zombies_spawned.connect(_on_zombies_spawned)
        zombie_system.start_day(current_day, _rng)
    if wolf_system:
        wolf_system.wolves_state_changed.connect(_on_wolves_state_changed)
        wolf_system.start_day(current_day, _rng)
    if wood_stove_system:
        wood_stove_system.stove_state_changed.connect(_on_wood_stove_state_changed)

    if expedition_system:
        expedition_system.expedition_state_changed.connect(_on_expedition_system_state_changed)
        expedition_system.initialize(_rng)
        _emit_expedition_state()

    _refresh_lure_status(true)
    _broadcast_trap_state()
    _emit_hunt_stock_changed()
    _rebuild_snare_state()
    if wood_stove_system:
        _on_wood_stove_state_changed(wood_stove_system.get_state())

    _resolve_tutorial_popup()
    call_deferred("_trigger_spawn_tutorial")

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

func get_carry_capacity() -> int:
    if inventory_system:
        return inventory_system.get_carry_capacity()
    return InventorySystem.DEFAULT_CARRY_CAPACITY

func get_hunt_animals() -> Array:
    return HUNT_ANIMAL_TABLE.duplicate(true)

func get_pending_game_stock() -> Dictionary:
    var animals: Dictionary = {}
    for key in _pending_game_food.keys():
        var stored = float(_pending_game_food.get(key, 0.0))
        var base = float(HUNT_ANIMAL_BASES.get(key, 0.0))
        var count = 0
        if base > 0.0:
            count = int(round(stored / base))
        animals[key] = {
            "label": HUNT_ANIMAL_LABELS.get(key, key.capitalize()),
            "food_units": stored,
            "count": count
        }
    return {
        "total_food_units": _get_pending_game_food_units(),
        "animals": animals
    }

func get_active_location() -> Dictionary:
    """Expose the current travel location context."""
    if _active_location.is_empty():
        return _resolve_location_profile(DEFAULT_LOCATION_ID)
    return _active_location.duplicate(true)

func _resolve_location_profile(location_id: String) -> Dictionary:
    var key = location_id.to_lower()
    var profile = LOCATION_PROFILES.get(key, LOCATION_PROFILES.get(DEFAULT_LOCATION_ID, {}))
    if typeof(profile) == TYPE_DICTIONARY:
        return profile.duplicate(true)
    return {}

func _apply_active_location(option: Dictionary) -> Dictionary:
    var location_id = String(option.get("id", DEFAULT_LOCATION_ID))
    var profile = _resolve_location_profile(location_id)
    profile["id"] = location_id
    profile["label"] = option.get("label", profile.get("label", location_id.capitalize()))
    profile["summary"] = option.get("summary", profile.get("summary", ""))
    profile["hazard_tier"] = String(option.get("hazard_tier", profile.get("hazard_tier", "watchful"))).to_lower()
    profile["temperature_band"] = String(option.get("temperature_band", profile.get("temperature_band", "temperate"))).to_lower()
    profile["forage_profile"] = String(option.get("forage_profile", profile.get("forage_profile", "tower_standard"))).to_lower()
    profile["fishing_allowed"] = bool(option.get("fishing_allowed", profile.get("fishing_allowed", false)))
    profile["shelter_from_rain"] = bool(option.get("shelter_from_rain", profile.get("shelter_from_rain", false)))
    var base_focus: Dictionary = profile.get("encounter_focus", {}) if typeof(profile.get("encounter_focus", {})) == TYPE_DICTIONARY else {}
    var option_focus: Dictionary = option.get("encounter_focus", base_focus)
    if typeof(option_focus) == TYPE_DICTIONARY:
        profile["encounter_focus"] = option_focus.duplicate(true)
    else:
        profile["encounter_focus"] = base_focus.duplicate(true) if typeof(base_focus) == TYPE_DICTIONARY else {}
    profile["travel_hours"] = float(option.get("travel_hours", profile.get("travel_hours", 0.0)))
    profile["rest_cost_percent"] = float(option.get("rest_cost_percent", profile.get("rest_cost_percent", TRAVEL_REST_COST_PERCENT)))
    profile["calorie_cost"] = float(option.get("calorie_cost", profile.get("calorie_cost", TRAVEL_CALORIE_COST)))
    profile["checkpoint_index"] = int(option.get("checkpoint_index", profile.get("checkpoint_index", 1)))
    _active_location = profile.duplicate(true)
    return profile.duplicate(true)

func get_hunt_status() -> Dictionary:
    var pending_stock = get_pending_game_stock()
    var status := {
        "hours": HUNT_HOURS,
        "rest_cost_percent": HUNT_REST_COST_PERCENT,
        "calorie_cost": HUNT_CALORIE_COST,
        "shots_per_trip": HUNT_ROLLS_PER_TRIP,
        "arrow_break_chance": HUNT_ARROW_BREAK_CHANCE,
        "pending_stock": pending_stock
    }
    if inventory_system:
        var bow_stock = inventory_system.get_item_count("bow")
        var arrow_stock = inventory_system.get_item_count("arrow")
        status["bow_stock"] = bow_stock
        status["arrow_stock"] = arrow_stock
        status["shots_planned"] = min(HUNT_ROLLS_PER_TRIP, max(arrow_stock, 0))
        status["shots_possible"] = status["shots_planned"]
    if zombie_system:
        status["zombies_nearby"] = zombie_system.get_active_zombies()
    return status

func get_snare_state() -> Dictionary:
    return _snare_state.duplicate(true)

func get_snare_status() -> Dictionary:
    var status := get_snare_state()
    status["place_hours"] = SNARE_PLACE_HOURS
    status["place_rest_cost_percent"] = SNARE_PLACE_REST_COST_PERCENT
    status["place_calorie_cost"] = SNARE_PLACE_CALORIE_COST
    status["check_hours"] = SNARE_CHECK_HOURS
    status["check_rest_cost_percent"] = SNARE_CHECK_REST_COST_PERCENT
    status["check_calorie_cost"] = SNARE_CHECK_CALORIE_COST
    status["catch_chance"] = SNARE_CATCH_CHANCE
    if inventory_system:
        status["snare_stock"] = inventory_system.get_item_count(SNARE_ITEM_ID)
    if time_system:
        status["current_time"] = time_system.get_formatted_time()
    return status

func has_deployed_snares() -> bool:
    return int(_snare_state.get("total_deployed", 0)) > 0

func get_butcher_status() -> Dictionary:
    var context = _build_game_processing_context()
    return {
        "hours": BUTCHER_HOURS,
        "rest_cost_percent": BUTCHER_REST_COST_PERCENT,
        "calorie_cost": BUTCHER_CALORIE_COST,
        "pending_stock": context.get("pending_stock", {}),
        "fire_lit": context.get("fire_lit", false),
        "processable_food_units": float(context.get("processable", 0.0)),
        "knife_stock": int(context.get("knife_stock", 0)),
        "total_food_units": float(context.get("total_food_units", 0.0))
    }

func get_cook_whole_status() -> Dictionary:
    var context = _build_game_processing_context()
    return {
        "hours": COOK_WHOLE_HOURS,
        "rest_cost_percent": COOK_WHOLE_REST_COST_PERCENT,
        "calorie_cost": COOK_WHOLE_CALORIE_COST,
        "pending_stock": context.get("pending_stock", {}),
        "fire_lit": context.get("fire_lit", false),
        "processable_food_units": float(context.get("processable", 0.0)),
        "total_food_units": float(context.get("total_food_units", 0.0))
    }

func _build_game_processing_context() -> Dictionary:
    var pending_stock = get_pending_game_stock()
    var pending_total = float(pending_stock.get("total_food_units", 0.0))
    var total_food_units: float = 0.0
    var knife_stock: int = 0
    if inventory_system:
        total_food_units = inventory_system.get_total_food_units()
        knife_stock = inventory_system.get_item_count(CRAFTED_KNIFE_ID)
    var context := {
        "pending_stock": pending_stock,
        "pending_total": pending_total,
        "total_food_units": total_food_units,
        "processable": min(pending_total, total_food_units),
        "fire_lit": wood_stove_system.is_lit() if wood_stove_system else false,
        "knife_stock": knife_stock
    }
    return context

func _prepare_game_processing(action: String, require_knife: bool) -> Dictionary:
    if inventory_system == null or time_system == null or sleep_system == null or wood_stove_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": action
        }

    var context = _build_game_processing_context()
    var payload := context.duplicate(true)
    payload["action"] = action
    payload["ready"] = false

    var knife_stock = int(payload.get("knife_stock", 0))
    if require_knife and knife_stock <= 0:
        payload["success"] = false
        payload["reason"] = "no_knife"
        return payload

    var fire_lit = bool(payload.get("fire_lit", false))
    if !fire_lit:
        payload["success"] = false
        payload["reason"] = "fire_unlit"
        payload["stove_state"] = wood_stove_system.get_state() if wood_stove_system else {}
        return payload

    var pending_total = float(payload.get("pending_total", 0.0))
    if pending_total <= 0.0:
        payload["success"] = false
        payload["reason"] = "no_game"
        return payload

    var processable = float(payload.get("processable", 0.0))
    if processable <= 0.0:
        payload["success"] = false
        payload["reason"] = "no_food"
        return payload

    payload["ready"] = true
    return payload

func get_wood_stove_system() -> WoodStoveSystem:
    return wood_stove_system

func get_wood_stove_state() -> Dictionary:
    return wood_stove_system.get_state() if wood_stove_system else {}

func get_recon_window_status() -> Dictionary:
    var status := {
        "available": false,
        "start_minute": RECON_WINDOW_START_MINUTE,
        "end_minute": RECON_WINDOW_END_MINUTE
    }
    if time_system == null:
        status["reason"] = "systems_unavailable"
        return status

    var minutes_since = time_system.get_minutes_since_daybreak()
    status["current_minute"] = minutes_since
    if minutes_since < RECON_WINDOW_START_MINUTE:
        status["reason"] = "before_window"
        status["minutes_until_window"] = RECON_WINDOW_START_MINUTE - minutes_since
        status["resumes_in_minutes"] = status["minutes_until_window"]
        status["resumes_at"] = time_system.get_formatted_time_after(status["minutes_until_window"])
        return status

    if minutes_since > RECON_WINDOW_END_MINUTE:
        var until_dawn = time_system.get_minutes_until_daybreak()
        status["reason"] = "after_window"
        status["minutes_until_window"] = until_dawn
        status["resumes_in_minutes"] = until_dawn
        status["resumes_at"] = time_system.get_formatted_time_after(until_dawn)
        return status

    status["available"] = true
    status["reason"] = "window_open"
    status["minutes_until_cutoff"] = max(RECON_WINDOW_END_MINUTE - minutes_since, 0)
    status["cutoff_at"] = time_system.get_formatted_time_after(status["minutes_until_cutoff"])
    return status

func get_weather_system() -> WeatherSystem:
    """Expose the weather system for UI consumers."""
    return weather_system

func get_tower_health_system() -> TowerHealthSystem:
    return tower_health_system

func get_warmth_system() -> WarmthSystem:
    return warmth_system

func get_flashlight_status() -> Dictionary:
    var has_flashlight = inventory_system != null and inventory_system.get_item_count("flashlight") > 0
    if !has_flashlight:
        flashlight_active = false
        return {
            "has_flashlight": false,
            "battery_percent": 0.0,
            "active": false,
            "batteries_available": inventory_system.get_item_count("batteries") if inventory_system else 0
        }
    flashlight_battery_percent = clamp(flashlight_battery_percent, 0.0, FLASHLIGHT_BATTERY_MAX)
    if flashlight_battery_percent <= 0.0:
        flashlight_active = false
    return {
        "has_flashlight": true,
        "battery_percent": flashlight_battery_percent,
        "active": flashlight_active,
        "batteries_available": inventory_system.get_item_count("batteries") if inventory_system else 0
    }

func get_news_system() -> NewsBroadcastSystem:
    return news_system

func get_zombie_system() -> ZombieSystem:
    return zombie_system

func get_wolf_system() -> WolfSystem:
    return wolf_system

func get_wolf_state() -> Dictionary:
    return _wolf_state.duplicate(true)

func has_active_wolves() -> bool:
    return wolf_system != null and wolf_system.has_active_wolves()

func get_lure_status() -> Dictionary:
    return _refresh_lure_status(false).duplicate(true)

func has_active_trap() -> bool:
    return _trap_state.get("active", false)

func get_trap_state() -> Dictionary:
    return _trap_state.duplicate(true)

func _broadcast_trap_state():
    trap_state_changed.emit(_trap_state.get("active", false), _trap_state.duplicate(true))

func _broadcast_snare_state():
    snare_state_changed.emit(get_snare_state())

func get_expedition_state() -> Dictionary:
    return expedition_system.get_state() if expedition_system else {}

func get_selected_travel_option() -> Dictionary:
    return expedition_system.get_selected_option() if expedition_system else {}

func select_travel_option(index: int) -> Dictionary:
    if expedition_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "travel_select"
        }
    var result = expedition_system.select_option(index)
    if !result.get("success", false):
        _emit_expedition_state()
    return result

func _emit_expedition_state():
    if expedition_system:
        expedition_state_changed.emit(expedition_system.get_state())
    else:
        expedition_state_changed.emit({})

func _on_expedition_system_state_changed(state: Dictionary) -> void:
    expedition_state_changed.emit(state)

func _rebuild_snare_state():
    var waiting: Array = []
    var active: int = 0
    var caught: int = 0
    var total_food: float = 0.0
    for entry in _snare_deployments:
        if entry.get("has_animal", false):
            caught += 1
            var animal: Dictionary = entry.get("animal", {})
            var snapshot = animal.duplicate(true)
            waiting.append(snapshot)
            total_food += float(snapshot.get("food_units", 0.0))
        else:
            active += 1
    _snare_state = {
        "total_deployed": _snare_deployments.size(),
        "active_snares": active,
        "caught_snares": caught,
        "animals_ready": waiting.size(),
        "waiting_animals": waiting,
        "roll_chance": SNARE_CATCH_CHANCE,
        "total_food_units_ready": total_food,
        "pending_stock": get_pending_game_stock()
    }
    if time_system:
        _snare_state["last_updated_time"] = time_system.get_formatted_time()
        _snare_state["last_updated_minutes"] = time_system.get_minutes_since_daybreak()
    _snare_state["current_day"] = current_day
    _broadcast_snare_state()

func get_recon_alerts() -> Dictionary:
    return _recon_alerts.duplicate(true)

func get_health_system() -> PlayerHealthSystem:
    return health_system

func get_crafting_recipes() -> Dictionary:
    var copy := {}
    for key in CRAFTING_RECIPES.keys():
        copy[key] = CRAFTING_RECIPES[key].duplicate(true)
    return copy

func add_wood_to_stove(quantity: int = 1) -> Dictionary:
    if wood_stove_system == null or inventory_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "requested": max(quantity, 0)
        }

    var request = max(quantity, 0)
    if request <= 0:
        request = 1
    var capacity = wood_stove_system.get_capacity_remaining()
    if capacity <= 0:
        return {
            "success": false,
            "reason": "no_capacity",
            "state": wood_stove_system.get_state()
        }

    var wood_stock = inventory_system.get_item_count("wood")
    if wood_stock <= 0:
        return {
            "success": false,
            "reason": "no_wood",
            "state": wood_stove_system.get_state()
        }

    var amount = min(request, capacity, wood_stock)
    if amount <= 0:
        return {
            "success": false,
            "reason": "no_amount",
            "state": wood_stove_system.get_state()
        }

    var consume_report = inventory_system.consume_item("wood", amount)
    if !consume_report.get("success", false):
        return {
            "success": false,
            "reason": "consume_failed",
            "required": amount,
            "available": wood_stock,
            "state": wood_stove_system.get_state()
        }

    var stove_report = wood_stove_system.add_logs(amount)
    var state: Dictionary = stove_report.get("state", wood_stove_system.get_state())
    return {
        "success": true,
        "added": stove_report.get("accepted", amount),
        "state": state,
        "wood_remaining": inventory_system.get_item_count("wood")
    }

func light_wood_stove(tool_id: String) -> Dictionary:
    var key = tool_id.to_lower()
    if wood_stove_system == null or inventory_system == null or _rng == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "tool": key,
            "state": wood_stove_system.get_state() if wood_stove_system else {}
        }

    if wood_stove_system.is_lit():
        return {
            "success": false,
            "reason": "already_lit",
            "tool": key,
            "state": wood_stove_system.get_state()
        }

    if wood_stove_system.get_logs_loaded() <= 0:
        return {
            "success": false,
            "reason": "no_fuel",
            "tool": key,
            "state": wood_stove_system.get_state()
        }

    if inventory_system.get_item_count(KINDLING_ID) <= 0:
        return {
            "success": false,
            "reason": "no_kindling",
            "tool": key,
            "state": wood_stove_system.get_state()
        }

    var chance = 0.0
    match key:
        FIRE_STARTING_BOW_ID:
            if inventory_system.get_item_count(FIRE_STARTING_BOW_ID) <= 0:
                return {
                    "success": false,
                    "reason": "missing_tool",
                    "tool": key,
                    "state": wood_stove_system.get_state()
                }
            chance = FIRE_STARTING_BOW_SUCCESS_CHANCE
        FLINT_AND_STEEL_ID:
            if inventory_system.get_item_count(FLINT_AND_STEEL_ID) <= 0:
                return {
                    "success": false,
                    "reason": "missing_tool",
                    "tool": key,
                    "state": wood_stove_system.get_state()
                }
            chance = FLINT_AND_STEEL_SUCCESS_CHANCE
        _:
            return {
                "success": false,
                "reason": "unsupported_tool",
                "tool": key,
                "state": wood_stove_system.get_state()
            }

    var kindling_spent = inventory_system.consume_item(KINDLING_ID, 1)
    if !kindling_spent.get("success", false):
        return {
            "success": false,
            "reason": "kindling_consume_failed",
            "tool": key,
            "state": wood_stove_system.get_state()
        }

    var roll = _rng.randf()
    var success = roll < chance
    var reason = "lit" if success else "failed_roll"
    var kindling_returned = false
    var tool_use_spent = 0

    if key == FLINT_AND_STEEL_ID:
        var flint_report = inventory_system.consume_item(FLINT_AND_STEEL_ID, 1)
        tool_use_spent = flint_report.get("quantity_removed", 0) if flint_report.get("success", false) else 0
        if !flint_report.get("success", false):
            reason = "flint_consume_failed"
            success = false
            inventory_system.add_item(KINDLING_ID, 1)
            kindling_returned = true

    if success:
        var ignite_report = wood_stove_system.ignite()
        success = ignite_report.get("success", false)
        reason = ignite_report.get("reason", reason) if !success else "lit"
        if !success:
            inventory_system.add_item(KINDLING_ID, 1)
            kindling_returned = true
    else:
        if key == FIRE_STARTING_BOW_ID:
            if _rng.randf() < FIRE_STARTING_BOW_KINDLING_RETURN_CHANCE:
                inventory_system.add_item(KINDLING_ID, 1)
                kindling_returned = true

    var state = wood_stove_system.get_state()
    return {
        "success": success,
        "reason": reason,
        "tool": key,
        "chance": chance,
        "roll": roll,
        "state": state,
        "kindling_spent": 1,
        "kindling_returned": kindling_returned,
        "kindling_remaining": inventory_system.get_item_count(KINDLING_ID),
        "tool_uses_spent": tool_use_spent,
        "tool_stock_remaining": inventory_system.get_item_count(key)
    }

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
    var broadcast: Dictionary = {}
    var has_message := false
    if news_system:
        broadcast = news_system.get_broadcast_for_day(current_day)
        has_message = !broadcast.is_empty() and !String(broadcast.get("text", "")).is_empty()
    if broadcast.is_empty():
        broadcast = {
            "title": "Tower Dispatch",
            "text": ""
        }

    var supply_note = _build_daily_supply_radio_note()
    if !supply_note.is_empty():
        var existing_text = String(broadcast.get("text", ""))
        if existing_text.is_empty():
            existing_text = supply_note
        else:
            existing_text = "{0}\n\n{1}".format([existing_text, supply_note])
        broadcast["text"] = existing_text
        has_message = true

    var result := {
        "success": true,
        "day": current_day,
        "has_message": has_message,
        "broadcast": broadcast,
        "daily_supply_status": _resolve_daily_supply_status()
    }
    if !has_message:
        result["reason"] = "no_broadcast"
    return result

func has_unheard_radio_message() -> bool:
    if _daily_supply_requires_attention():
        return true
    if news_system == null:
        return false
    var broadcast = news_system.get_broadcast_for_day(current_day)
    var text = String(broadcast.get("text", ""))
    if text.is_empty():
        return false
    return current_day > _radio_last_ack_day

func mark_radio_message_heard():
    if current_day <= _radio_last_ack_day:
        _acknowledge_daily_supply_notice()
        return
    _radio_last_ack_day = current_day
    _acknowledge_daily_supply_notice()
    _refresh_radio_attention("acknowledged")

func should_show_radio_tip() -> bool:
    return !_radio_tip_shown

func mark_radio_tip_shown():
    if _radio_tip_shown:
        return
    _radio_tip_shown = true

func claim_daily_supply_drop() -> Dictionary:
    var result := {
        "had_cache": false,
        "claimed": false,
        "items": [],
        "summary_text": "",
        "day": current_day,
        "reason": ""
    }
    if _daily_supply_state.is_empty():
        return result

    result["had_cache"] = true
    var hamper: Dictionary = _daily_supply_state.duplicate(true)
    _daily_supply_state.clear()

    if inventory_system == null:
        _daily_supply_state = hamper
        result["reason"] = "inventory_unavailable"
        return result

    var hamper_day = int(hamper.get("day", current_day))
    result["day"] = hamper_day

    var items: Array = hamper.get("items", [])
    var reports: Array = []
    for entry in items:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var item_id = String(entry.get("item_id", ""))
        var quantity = int(entry.get("quantity", 0))
        if item_id.is_empty() or quantity <= 0:
            continue
        var add_report = inventory_system.add_item(item_id, quantity)
        reports.append(add_report)

    if reports.is_empty():
        result["reason"] = "empty_cache"
        return result

    result["claimed"] = true
    result["items"] = reports
    result["summary_text"] = _format_daily_supply_summary(reports)
    print("📦 Daily hamper claimed ->\n%s" % result["summary_text"])
    return result

func _resolve_daily_supply_status() -> String:
    if !_daily_supply_state.is_empty():
        return "available"
    if !_daily_supply_spoil_notice.is_empty():
        return "spoiled_notice"
    return "none"

func _daily_supply_requires_attention() -> bool:
    return !_daily_supply_state.is_empty() or !_daily_supply_spoil_notice.is_empty()

func _acknowledge_daily_supply_notice():
    if !_daily_supply_spoil_notice.is_empty():
        _daily_supply_spoil_notice.clear()

func _build_daily_supply_radio_note() -> String:
    var lines: PackedStringArray = []

    if !_daily_supply_spoil_notice.is_empty():
        var spoil_summary = String(_daily_supply_spoil_notice.get("summary", ""))
        if spoil_summary.is_empty():
            spoil_summary = _format_daily_supply_summary(_daily_supply_spoil_notice.get("items", []))
        if spoil_summary.is_empty():
            lines.append("Yesterday's hamper spoiled before you checked in. Make time each morning so nothing rots.")
        else:
            lines.append("Yesterday's hamper spoiled before you checked in:\n{0}\nMake time each morning so nothing rots.".format([spoil_summary]))

    if !_daily_supply_state.is_empty():
        var items: Array = _daily_supply_state.get("items", [])
        var summary_text = _format_daily_supply_summary(items)
        if summary_text.is_empty():
            lines.append("Dispatch left a fresh hamper at the base door—claim it before dusk or it spoils.")
        else:
            lines.append("Dispatch left a fresh hamper at the base door—claim it before dusk or it spoils.\n{0}".format([summary_text]))

    if lines.is_empty():
        return ""

    return "Supply Cache Update:\n%s" % "\n\n".join(lines)

func _spawn_daily_supply_drop(source: String = ""):
    var items = _roll_daily_supply_items()
    if items.is_empty():
        _daily_supply_state.clear()
        return
    _daily_supply_state = {
        "day": current_day,
        "items": items,
        "source": source
    }
    var summary = _format_daily_supply_summary(items)
    if !summary.is_empty():
        print("🎒 Daily hamper staged (%s) ->\n%s" % [source, summary])

func _handle_daily_supply_decay(source: String = ""):
    if _daily_supply_state.is_empty():
        return
    var hamper_day = int(_daily_supply_state.get("day", current_day))
    if current_day - hamper_day < DAILY_SUPPLY_EXPIRES_AFTER_DAYS:
        return

    var preserved_items: Array = []
    for entry in _daily_supply_state.get("items", []):
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        preserved_items.append(entry.duplicate(true))

    var summary = _format_daily_supply_summary(preserved_items)
    _daily_supply_spoil_notice = {
        "day": hamper_day,
        "items": preserved_items,
        "summary": summary,
        "source": source
    }
    _daily_supply_state.clear()
    if summary.is_empty():
        print("⚠️ Daily hamper spoiled with no salvageable goods")
    else:
        print("⚠️ Daily hamper spoiled ->\n%s" % summary)

func _roll_daily_supply_items() -> Array:
    if DAILY_SUPPLY_TABLE.is_empty():
        return []

    var picks: Array = []
    var perishable_entries: Array = []
    for entry in DAILY_SUPPLY_TABLE:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        if String(entry.get("category", "")) == "perishable":
            perishable_entries.append(entry)

    var perishable_added := false
    if !perishable_entries.is_empty():
        for attempt in range(3):
            var forced = perishable_entries[_rng.randi_range(0, perishable_entries.size() - 1)]
            var forced_entry = _roll_daily_supply_entry(forced)
            if forced_entry.is_empty():
                continue
            _append_daily_supply_entry(picks, forced_entry)
            perishable_added = true
            break

    var total_rolls = _rng.randi_range(DAILY_SUPPLY_MIN_ROLLS, DAILY_SUPPLY_MAX_ROLLS)
    while picks.size() < total_rolls:
        var source = DAILY_SUPPLY_TABLE[_rng.randi_range(0, DAILY_SUPPLY_TABLE.size() - 1)]
        var rolled = _roll_daily_supply_entry(source)
        if rolled.is_empty():
            continue
        _append_daily_supply_entry(picks, rolled)
        if String(rolled.get("category", "")) == "perishable":
            perishable_added = true

    if !perishable_added:
        _append_daily_supply_entry(picks, {
            "item_id": "berries",
            "quantity": 1,
            "category": "perishable"
        })

    return picks

func _roll_daily_supply_entry(entry: Dictionary) -> Dictionary:
    var item_id = String(entry.get("item_id", ""))
    if item_id.is_empty():
        return {}

    var chance = clamp(float(entry.get("chance", 1.0)), 0.0, 1.0)
    if _rng.randf() > chance:
        return {}

    var quantity := 1
    var range = entry.get("quantity_range")
    if range is Array and range.size() >= 2:
        var min_q = int(range[0])
        var max_q = int(range[1])
        if min_q > max_q:
            var temp = min_q
            min_q = max_q
            max_q = temp
        quantity = _rng.randi_range(min_q, max_q)
    else:
        quantity = max(int(entry.get("quantity", 1)), 1)

    return {
        "item_id": item_id,
        "quantity": quantity,
        "category": entry.get("category", "supply")
    }

func _append_daily_supply_entry(picks: Array, entry: Dictionary):
    var item_id = String(entry.get("item_id", ""))
    var quantity = int(entry.get("quantity", 0))
    if item_id.is_empty() or quantity <= 0:
        return

    for existing in picks:
        if typeof(existing) != TYPE_DICTIONARY:
            continue
        if String(existing.get("item_id", "")) == item_id:
            existing["quantity"] = int(existing.get("quantity", 0)) + quantity
            return

    picks.append({
        "item_id": item_id,
        "quantity": quantity,
        "category": entry.get("category", "supply")
    })

func _format_daily_supply_summary(entries: Array) -> String:
    if entries.is_empty():
        return ""

    var lines: PackedStringArray = []
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var item_id = String(entry.get("item_id", ""))
        var display = String(entry.get("display_name", ""))
        if display.is_empty() and inventory_system:
            display = inventory_system.get_item_display_name(item_id)
        if display.is_empty() and !item_id.is_empty():
            display = item_id.capitalize()

        var quantity = 0
        if entry.has("quantity"):
            quantity = int(entry.get("quantity", 0))
        elif entry.has("quantity_added"):
            quantity = int(entry.get("quantity_added", 0))
        if quantity <= 0 or display.is_empty():
            continue

        lines.append("• %s ×%d" % [display, quantity])

    return "\n".join(lines)

func _refresh_radio_attention(_source: String = ""):
    radio_attention_changed.emit(has_unheard_radio_message())

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
    if warmth_system:
        warmth_system.apply_environment_minutes(requested_minutes, current_minutes, true)

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

func perform_fishing() -> Dictionary:
    if inventory_system == null or _rng == null or time_system == null or sleep_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "fishing"
        }

    var location = get_active_location()
    if !bool(location.get("fishing_allowed", false)):
        return {
            "success": false,
            "reason": "location_blocked",
            "action": "fishing",
            "location": location
        }

    var rod_stock = inventory_system.get_item_count("fishing_rod") if inventory_system else 0
    if rod_stock <= 0:
        return {
            "success": false,
            "reason": "missing_rod",
            "action": "fishing",
            "rod_stock": rod_stock
        }

    var grub_stock = inventory_system.get_item_count("grubs") if inventory_system else 0
    if grub_stock <= 0:
        return {
            "success": false,
            "reason": "no_grubs",
            "action": "fishing",
            "grub_stock": grub_stock
        }

    var time_report = _spend_activity_time(1.0, "fishing")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "fishing"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(FISHING_REST_COST_PERCENT)
    var calorie_total = sleep_system.adjust_daily_calories(FISHING_CALORIE_COST)

    var catches: Array = []
    var total_food: float = 0.0
    var success_chance = FISHING_ROLL_SUCCESS_CHANCE
    var prime_time_bonus: float = 0.0
    if time_system:
        var minute_of_day = time_system.get_minutes_since_midnight()
        if _is_fishing_prime_time(minute_of_day):
            prime_time_bonus = 0.15
            success_chance = min(success_chance + prime_time_bonus, 1.0)
    for i in range(FISHING_ROLLS_PER_HOUR):
        var roll = _rng.randf()
        if roll < success_chance:
            var size_roll = _rng.randf()
            var size_entry = _pick_fishing_size(size_roll)
            var catch_report := {
                "size": size_entry.get("size", "small"),
                "food_units": float(size_entry.get("food_units", 0.5)),
                "chance": success_chance,
                "roll": roll,
                "size_roll": size_roll,
                "size_chance": float(size_entry.get("chance", 0.0))
            }
            catches.append(catch_report)
            total_food += float(size_entry.get("food_units", 0.5))

    if total_food > 0.0:
        inventory_system.add_food_units(total_food)

    var grub_roll = _rng.randf()
    var grub_lost = false
    var grubs_consumed = 0
    var grub_consume_report: Dictionary = {}
    if grub_roll < FISHING_GRUB_LOSS_CHANCE:
        grub_consume_report = inventory_system.consume_item("grubs", 1)
        if grub_consume_report.get("success", false):
            grub_lost = true
            grubs_consumed = 1
        else:
            grub_consume_report["requested"] = 1
            grub_consume_report["stock_before"] = grub_stock

    var result := time_report.duplicate()
    result["action"] = "fishing"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["calories_spent"] = FISHING_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["rolls"] = FISHING_ROLLS_PER_HOUR
    result["roll_chance"] = success_chance
    result["prime_time_bonus"] = prime_time_bonus
    result["successful_rolls"] = catches.size()
    result["grub_loss_chance"] = FISHING_GRUB_LOSS_CHANCE
    result["catches"] = catches
    result["food_units_gained"] = total_food
    result["total_food_units"] = inventory_system.get_total_food_units()
    result["grub_roll"] = grub_roll
    result["grub_lost"] = grub_lost
    result["grubs_consumed"] = grubs_consumed
    result["grubs_before"] = grub_stock
    result["grubs_remaining"] = inventory_system.get_item_count("grubs") if inventory_system else 0
    result["location"] = location
    if !grub_consume_report.is_empty():
        result["grub_consume_report"] = grub_consume_report
        result["grub_consume_failed"] = !grub_consume_report.get("success", false)

    if catches.is_empty():
        result["success"] = false
        result["reason"] = "no_catch"
        print("🎣 Fishing trip yielded no catch (rolls %d @ %.0f%%)" % [FISHING_ROLLS_PER_HOUR, success_chance * 100.0])
    else:
        result["success"] = true
        print("🎣 Fishing caught %d fish (+%.1f food)" % [catches.size(), total_food])

    if grub_lost:
        print("🐛 Grub consumed (stock %d)" % result.get("grubs_remaining", 0))

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

    var rest_spent = sleep_system.consume_sleep(FORGING_REST_COST_PERCENT)
    var calorie_burn = sleep_system.adjust_daily_calories(FORGING_CALORIE_COST)
    var loot_roll = _roll_forging_loot_for_location()
    var result := time_report.duplicate()
    result["action"] = "forging"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["calories_spent"] = FORGING_CALORIE_COST
    result["daily_calories_used"] = calorie_burn

    var wolf_encounter = _apply_wolf_encounter("forging")
    if !wolf_encounter.is_empty():
        result["wolf_encounter"] = wolf_encounter

    if loot_roll.is_empty():
        result["success"] = false
        result["reason"] = "nothing_found"
        print("🌲 Forging yielded nothing")
        return result

    var capacity_report = _apply_carry_capacity(loot_roll)
    var carried_entries: Array = capacity_report.get("retained", loot_roll)
    var dropped_entries: Array = capacity_report.get("dropped", [])
    var capacity = int(capacity_report.get("capacity", get_carry_capacity()))
    result["carry_capacity"] = capacity

    if carried_entries.is_empty():
        result["success"] = false
        result["reason"] = "carry_limit_reached"
        if !dropped_entries.is_empty():
            var dropped_only = _format_dropped_entries(dropped_entries)
            if !dropped_only.is_empty():
                result["dropped_loot"] = dropped_only
                result["items_dropped"] = dropped_only.size()
        print("🌲 Forging haul dropped (capacity %d)" % capacity)
        return result

    var loot_reports: Array = []
    for item in carried_entries:
        var report = inventory_system.add_item(item.get("item_id", ""), item.get("quantity", 1))
        report["roll"] = item.get("roll", 0.0)
        report["chance"] = item.get("chance", 0.0)
        report["tier"] = item.get("tier", "basic")
        report["quantity_rolled"] = item.get("quantity", report.get("quantity_added", 1))
        if String(item.get("item_id", "")) == "flashlight":
            var previous_quantity = int(report.get("new_quantity", 0)) - int(report.get("quantity_added", 0))
            if previous_quantity <= 0:
                flashlight_battery_percent = FLASHLIGHT_BATTERY_MAX
                flashlight_active = false
        loot_reports.append(report)

    result["loot"] = loot_reports
    result["items_found"] = loot_reports.size()
    result["total_food_units"] = inventory_system.get_total_food_units()
    result["flashlight_status"] = get_flashlight_status()
    result["items_carried"] = carried_entries.size()
    if !dropped_entries.is_empty():
        var dropped_reports = _format_dropped_entries(dropped_entries)
        if !dropped_reports.is_empty():
            result["dropped_loot"] = dropped_reports
            result["items_dropped"] = dropped_reports.size()
    result["success"] = true
    print("🌲 Forging success: %s" % result)
    return result

func perform_campground_search() -> Dictionary:
    if inventory_system == null or _rng == null or time_system == null or sleep_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "camp_search"
        }

    if zombie_system and zombie_system.has_active_zombies():
        return {
            "success": false,
            "reason": "zombies_present",
            "action": "camp_search",
            "zombie_count": zombie_system.get_active_zombies()
        }

    var time_report = _spend_activity_time(CAMP_SEARCH_HOURS, "camp_search")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["success"] = false
        failure["action"] = "camp_search"
        failure["reason"] = failure.get("reason", "time_rejected")
        failure["status"] = failure.get("status", "rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(CAMP_SEARCH_REST_COST_PERCENT)
    var calorie_burn = sleep_system.adjust_daily_calories(CAMP_SEARCH_CALORIE_COST)
    var loot_roll = _roll_campground_loot()
    var result := time_report.duplicate()
    result["action"] = "camp_search"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["calories_spent"] = CAMP_SEARCH_CALORIE_COST
    result["daily_calories_used"] = calorie_burn

    var wolf_encounter = _apply_wolf_encounter("camp_search")
    if !wolf_encounter.is_empty():
        result["wolf_encounter"] = wolf_encounter

    if loot_roll.is_empty():
        result["success"] = false
        result["reason"] = "nothing_found"
        print("⛺ Camp search yielded nothing")
        return result

    var capacity_report = _apply_carry_capacity(loot_roll)
    var carried_entries: Array = capacity_report.get("retained", loot_roll)
    var dropped_entries: Array = capacity_report.get("dropped", [])
    var capacity = int(capacity_report.get("capacity", get_carry_capacity()))
    result["carry_capacity"] = capacity

    if carried_entries.is_empty():
        result["success"] = false
        result["reason"] = "carry_limit_reached"
        if !dropped_entries.is_empty():
            var dropped_only = _format_dropped_entries(dropped_entries)
            if !dropped_only.is_empty():
                result["dropped_loot"] = dropped_only
                result["items_dropped"] = dropped_only.size()
        print("⛺ Camp search haul dropped (capacity %d)" % capacity)
        return result

    var loot_reports: Array = []
    for item in carried_entries:
        var report = inventory_system.add_item(item.get("item_id", ""), item.get("quantity", 1))
        report["roll"] = item.get("roll", 0.0)
        report["chance"] = item.get("chance", 0.0)
        report["tier"] = item.get("tier", "basic")
        report["quantity_rolled"] = item.get("quantity", report.get("quantity_added", 1))
        loot_reports.append(report)

    result["loot"] = loot_reports
    result["items_found"] = loot_reports.size()
    result["total_food_units"] = inventory_system.get_total_food_units()
    result["items_carried"] = carried_entries.size()
    if !dropped_entries.is_empty():
        var dropped_reports = _format_dropped_entries(dropped_entries)
        if !dropped_reports.is_empty():
            result["dropped_loot"] = dropped_reports
            result["items_dropped"] = dropped_reports.size()
    result["success"] = true
    print("⛺ Camp search success: %s" % result)
    return result

func perform_hunt() -> Dictionary:
    if inventory_system == null or _rng == null or time_system == null or sleep_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "hunt"
        }

    if zombie_system and zombie_system.has_active_zombies():
        return {
            "success": false,
            "reason": "zombies_present",
            "action": "hunt",
            "zombie_count": zombie_system.get_active_zombies()
        }

    var bow_stock = inventory_system.get_item_count("bow") if inventory_system else 0
    if bow_stock <= 0:
        return {
            "success": false,
            "reason": "no_bow",
            "action": "hunt",
            "bow_stock": bow_stock
        }

    var arrow_stock = inventory_system.get_item_count("arrow") if inventory_system else 0
    if arrow_stock <= 0:
        return {
            "success": false,
            "reason": "no_arrows",
            "action": "hunt",
            "arrow_stock": arrow_stock
        }

    var time_report = _spend_activity_time(HUNT_HOURS, "hunt")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "hunt"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(HUNT_REST_COST_PERCENT)
    var calorie_total = sleep_system.adjust_daily_calories(HUNT_CALORIE_COST)

    var planned_shots = min(HUNT_ROLLS_PER_TRIP, max(arrow_stock, 0))
    var arrow_runtime = arrow_stock
    var shots: Array = []
    var animals: Array = []
    var animal_counts: Dictionary = {}
    var total_food: float = 0.0
    var arrow_breaks: int = 0
    var arrow_returns: int = 0

    for index in range(HUNT_ROLLS_PER_TRIP):
        if arrow_runtime <= 0:
            break
        var shot_index = index + 1
        var shot_report := {
            "index": shot_index,
            "arrows_before": arrow_runtime,
            "arrow_break_chance": HUNT_ARROW_BREAK_CHANCE
        }
        var catch_report = _roll_hunt_animal()
        if !catch_report.is_empty():
            animals.append(catch_report)
            shot_report["animal"] = catch_report
            var animal_id = String(catch_report.get("id", ""))
            if !animal_id.is_empty():
                animal_counts[animal_id] = int(animal_counts.get(animal_id, 0)) + 1
                _add_pending_game_food(animal_id, float(catch_report.get("food_units", 0.0)))
            total_food += float(catch_report.get("food_units", 0.0))
        var break_roll = _rng.randf()
        var broke = break_roll < HUNT_ARROW_BREAK_CHANCE
        shot_report["break_roll"] = break_roll
        shot_report["arrow_broke"] = broke
        if broke:
            arrow_runtime -= 1
            arrow_breaks += 1
        else:
            arrow_returns += 1
            shot_report["arrow_returned"] = true
        shot_report["arrows_after"] = max(arrow_runtime, 0)
        shots.append(shot_report)

    var consume_report: Dictionary = {}
    if arrow_breaks > 0:
        consume_report = inventory_system.consume_item("arrow", arrow_breaks)
        if !consume_report.get("success", false):
            consume_report["requested"] = arrow_breaks
            consume_report["stock_before"] = arrow_stock

    var food_delta: float = 0.0
    if total_food > 0.0:
        inventory_system.add_food_units(total_food)
        food_delta = total_food

    _emit_hunt_stock_changed()

    var result := time_report.duplicate()
    result["action"] = "hunt"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["calories_spent"] = HUNT_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["shots_requested"] = HUNT_ROLLS_PER_TRIP
    result["shots_planned"] = planned_shots
    result["shots_possible"] = planned_shots
    result["shots_taken"] = shots.size()
    result["shots"] = shots
    result["animals"] = animals
    result["animal_counts"] = animal_counts
    result["food_units_gained"] = food_delta
    result["total_food_units"] = inventory_system.get_total_food_units()
    result["arrow_stock_before"] = arrow_stock
    result["arrow_breaks"] = arrow_breaks
    result["arrow_returns"] = arrow_returns
    result["arrow_break_chance"] = HUNT_ARROW_BREAK_CHANCE
    result["arrows_remaining"] = inventory_system.get_item_count("arrow") if inventory_system else 0
    result["bow_stock"] = bow_stock
    result["pending_stock"] = get_pending_game_stock()
    if !consume_report.is_empty():
        result["arrow_consume_report"] = consume_report
        result["arrow_consume_failed"] = !consume_report.get("success", false)

    if animals.is_empty():
        result["success"] = false
        result["reason"] = "no_game"
        print("🎯 Hunt returned empty-handed")
    else:
        result["success"] = true
        print("🎯 Hunt success: %s" % result)

    return result

func perform_butcher_and_cook() -> Dictionary:
    var prep = _prepare_game_processing("butcher", true)
    if !prep.get("ready", false):
        return prep

    var time_report = _spend_activity_time(BUTCHER_HOURS, "butcher")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "butcher"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(BUTCHER_REST_COST_PERCENT)
    var calorie_total = sleep_system.adjust_daily_calories(BUTCHER_CALORIE_COST)
    var processable = float(prep.get("processable", 0.0))
    var desired_total = processable * 1.25
    var rounded_total = _round_up_to_half(desired_total)
    var bonus = max(rounded_total - processable, 0.0)

    if bonus > 0.0:
        inventory_system.add_food_units(bonus)

    _consume_pending_game_food(processable)

    var result := time_report.duplicate()
    result["action"] = "butcher"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["calories_spent"] = BUTCHER_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["processable_food_units"] = processable
    result["bonus_food_units"] = bonus
    result["rounded_total_food_units"] = rounded_total
    result["knife_stock"] = int(prep.get("knife_stock", 0))
    result["fire_lit"] = prep.get("fire_lit", false)
    result["total_food_units"] = inventory_system.get_total_food_units()
    result["pending_stock"] = get_pending_game_stock()

    result["success"] = true
    print("🍖 Butcher & Cook success: %s" % result)
    return result

func perform_cook_animals_whole() -> Dictionary:
    var prep = _prepare_game_processing("cook_whole", false)
    if !prep.get("ready", false):
        return prep

    var time_report = _spend_activity_time(COOK_WHOLE_HOURS, "cook_whole")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "cook_whole"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(COOK_WHOLE_REST_COST_PERCENT)
    var calorie_total = sleep_system.adjust_daily_calories(COOK_WHOLE_CALORIE_COST)

    var processable = float(prep.get("processable", 0.0))

    _consume_pending_game_food(processable)

    var result := time_report.duplicate()
    result["action"] = "cook_whole"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["calories_spent"] = COOK_WHOLE_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["processable_food_units"] = processable
    result["total_food_units"] = inventory_system.get_total_food_units()
    result["pending_stock"] = get_pending_game_stock()
    result["fire_lit"] = prep.get("fire_lit", false)

    result["success"] = true
    print("🔥 Cook Animals Whole success: %s" % result)
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

    _refresh_lure_status(true)
    return result

func perform_lure_incoming_zombies() -> Dictionary:
    var wolves_present = wolf_system != null and wolf_system.has_active_wolves()
    if time_system == null or sleep_system == null or _rng == null:
        var failure := {
            "success": false,
            "reason": "systems_unavailable",
            "action": "lure"
        }
        _refresh_lure_status(true)
        return failure

    if wolves_present:
        var preview = _preview_activity_time(LURE_DURATION_HOURS)
        if !preview.get("success", false):
            preview["action"] = "lure"
            preview["success"] = false
            preview["reason"] = preview.get("reason", "time_rejected")
            preview["threat"] = "wolves"
            _refresh_lure_status(true)
            return preview

        var time_report = _spend_activity_time(LURE_DURATION_HOURS, "lure")
        if !time_report.get("success", false):
            var failure := time_report.duplicate(true)
            failure["action"] = "lure"
            failure["reason"] = failure.get("reason", "time_rejected")
            failure["threat"] = "wolves"
            _refresh_lure_status(true)
            return failure

        var calorie_total = sleep_system.adjust_daily_calories(LURE_CALORIE_COST)
        var lure_attempt = wolf_system.attempt_lure(WOLF_LURE_SUCCESS_CHANCE, _rng) if wolf_system else {"success": false}
        var success = bool(lure_attempt.get("success", false))
        var result := time_report.duplicate()
        result["action"] = "lure"
        result["status"] = result.get("status", "applied")
        result["threat"] = "wolves"
        result["calories_spent"] = LURE_CALORIE_COST
        result["daily_calories_used"] = calorie_total
        result["minutes_required"] = int(preview.get("requested_minutes", result.get("minutes_spent", 0)))
        result["chance"] = WOLF_LURE_SUCCESS_CHANCE
        result["roll"] = float(lure_attempt.get("roll", 1.0))
        result["success"] = success
        var lure_reason = "wolves_cleared" if success else "wolves_stayed"
        result["reason"] = String(lure_attempt.get("reason", lure_reason))
        result["wolves_removed"] = success
        result["wolves_present"] = true
        result["window_minutes"] = LURE_WINDOW_MINUTES
        result["calorie_cost"] = LURE_CALORIE_COST
        _refresh_lure_status(true)
        if success:
            print("🪤 Lure success -> wolves scattered")
        else:
            print("🪤 Lure failed -> wolves linger")
        return result

    if zombie_system == null:
        var offline := {
            "success": false,
            "reason": "systems_unavailable",
            "action": "lure"
        }
        _refresh_lure_status(true)
        return offline

    var status = get_lure_status()
    if !status.get("scouted", false):
        status["success"] = false
        status["action"] = "lure"
        status["reason"] = status.get("reason", "no_target")
        _refresh_lure_status(true)
        return status

    if !status.get("available", false):
        var failure := status.duplicate(true)
        failure["success"] = false
        failure["action"] = "lure"
        failure["reason"] = status.get("reason", "not_ready")
        _refresh_lure_status(true)
        return failure

    var preview = _preview_activity_time(LURE_DURATION_HOURS)
    if !preview.get("success", false):
        preview["action"] = "lure"
        preview["success"] = false
        preview["reason"] = preview.get("reason", "time_rejected")
        _refresh_lure_status(true)
        return preview

    var expected_day = int(status.get("spawn_day", current_day))
    var expected_minute = int(status.get("spawn_minute", -1))
    var cancel_report = zombie_system.cancel_pending_spawn(expected_day, expected_minute)
    if !cancel_report.get("success", false):
        var failure := status.duplicate(true)
        failure["success"] = false
        failure["action"] = "lure"
        failure["reason"] = String(cancel_report.get("reason", "cancel_failed"))
        _refresh_lure_status(true)
        return failure

    var cancelled_event: Dictionary = cancel_report.get("event", {})
    var time_report = _spend_activity_time(LURE_DURATION_HOURS, "lure")
    if !time_report.get("success", false):
        if !cancelled_event.is_empty():
            zombie_system.restore_pending_spawn(cancelled_event)
        var failure := time_report.duplicate(true)
        failure["action"] = "lure"
        failure["reason"] = failure.get("reason", "time_rejected")
        _refresh_lure_status(true)
        return failure

    var calorie_total = sleep_system.adjust_daily_calories(LURE_CALORIE_COST)
    var prevented = int(status.get("quantity", cancelled_event.get("quantity", cancelled_event.get("spawns", 0))))
    var minutes_remaining = int(status.get("minutes_remaining", 0))
    var result := time_report.duplicate()
    result["action"] = "lure"
    result["status"] = result.get("status", "applied")
    result["success"] = true
    result["calories_spent"] = LURE_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["minutes_required"] = int(preview.get("requested_minutes", result.get("minutes_spent", 0)))
    result["zombies_prevented"] = max(prevented, 0)
    result["spawn_minutes_remaining"] = minutes_remaining
    result["spawn_prevented_clock"] = status.get("clock_time", time_report.get("ended_at_time", ""))
    result["window_minutes"] = LURE_WINDOW_MINUTES
    result["calorie_cost"] = LURE_CALORIE_COST
    var attempted = int(status.get("quantity", cancelled_event.get("quantity", prevented)))
    if attempted < prevented:
        attempted = prevented
    var failed = max(attempted - prevented, 0)
    result["lure_attempted"] = max(attempted, 0)
    result["lure_failed"] = failed
    result["zombies_at_tower"] = zombie_system.get_active_zombies() if zombie_system else 0
    var injury_report = _apply_lure_injury(prevented, failed)
    if !injury_report.is_empty():
        result["injury_report"] = injury_report

    _clear_lure_target("completed")
    print("🪤 Lure success -> diverted %d approaching undead" % max(prevented, 0))
    return result

func perform_fight_back() -> Dictionary:
    var wolves_present = wolf_system != null and wolf_system.has_active_wolves()
    var zombies_present = zombie_system != null and zombie_system.has_active_zombies()

    if time_system == null or sleep_system == null or inventory_system == null or _rng == null or health_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "fight_back"
        }

    if !wolves_present and !zombies_present:
        return {
            "success": false,
            "reason": "no_threat",
            "action": "fight_back"
        }

    var has_knife = inventory_system.get_item_count(CRAFTED_KNIFE_ID) > 0
    var has_bow = inventory_system.get_item_count("bow") > 0
    var has_arrow = inventory_system.get_item_count("arrow") > 0
    if !has_knife and !(has_bow and has_arrow):
        return {
            "success": false,
            "reason": "no_weapons",
            "action": "fight_back",
            "wolves_present": wolves_present,
            "zombies_present": zombies_present
        }

    var preview = _preview_activity_time(FIGHT_BACK_HOURS)
    if !preview.get("success", false):
        preview["action"] = "fight_back"
        preview["success"] = false
        preview["reason"] = preview.get("reason", "time_rejected")
        return preview

    var time_report = _spend_activity_time(FIGHT_BACK_HOURS, "fight_back")
    if !time_report.get("success", false):
        var failure := time_report.duplicate(true)
        failure["action"] = "fight_back"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(FIGHT_BACK_REST_COST_PERCENT)
    var calorie_total = sleep_system.adjust_daily_calories(FIGHT_BACK_CALORIE_COST)

    var damage_min = FIGHT_BACK_KNIFE_DAMAGE_MIN
    var damage_max = FIGHT_BACK_KNIFE_DAMAGE_MAX
    if has_bow and has_arrow and has_knife:
        damage_min = FIGHT_BACK_COMBINED_DAMAGE_MIN
        damage_max = FIGHT_BACK_COMBINED_DAMAGE_MAX
    elif has_bow and has_arrow:
        damage_min = FIGHT_BACK_BOW_DAMAGE_MIN
        damage_max = FIGHT_BACK_BOW_DAMAGE_MAX

    var damage_roll = _rng.randi_range(damage_min, damage_max)
    var result := time_report.duplicate()
    result["action"] = "fight_back"
    result["status"] = result.get("status", "applied")
    result["success"] = true
    result["rest_spent_percent"] = rest_spent
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["calories_spent"] = FIGHT_BACK_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["minutes_required"] = int(preview.get("requested_minutes", result.get("minutes_spent", 0)))
    result["wolves_present"] = wolves_present
    result["zombies_present"] = zombies_present
    result["has_knife"] = has_knife
    result["has_bow"] = has_bow
    result["has_arrow"] = has_arrow
    result["damage_roll"] = damage_roll
    result["damage_min"] = damage_min
    result["damage_max"] = damage_max

    if damage_roll > 0:
        var damage_report = health_system.apply_damage(damage_roll, "fight_back")
        result["damage_report"] = damage_report
        result["damage_applied"] = float(damage_report.get("applied", damage_roll))
        result["health_before"] = damage_report.get("previous_health", damage_report.get("health_before", health_system.get_health()))
        result["health_after"] = damage_report.get("new_health", damage_report.get("health_after", health_system.get_health()))
    else:
        result["damage_applied"] = 0.0
        result["health_before"] = health_system.get_health()
        result["health_after"] = result["health_before"]

    var zombies_cleared = false
    var wolves_removed = !wolves_present
    if wolves_present and wolf_system:
        var wolf_clear = wolf_system.clear_wolves("fight_back")
        wolves_removed = bool(wolf_clear.get("success", false))
        result["wolf_clear_report"] = wolf_clear
    if zombies_present and zombie_system:
        zombie_system.clear_zombies()
        zombies_cleared = true

    result["zombies_removed"] = zombies_cleared or !zombies_present
    result["wolves_removed"] = wolves_removed

    _refresh_lure_status(true)
    print("🗡️ Fight Back -> neutralized threats (wolves %s | zombies %s)" % [str(wolves_present), str(zombies_present)])
    return result

func perform_trap_deployment() -> Dictionary:
    if time_system == null or sleep_system == null or inventory_system == null or _rng == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "trap"
        }

    if has_active_trap():
        return {
            "success": false,
            "reason": "trap_active",
            "action": "trap",
            "state": get_trap_state()
        }

    var trap_stock = inventory_system.get_item_count(TRAP_ITEM_ID) if inventory_system else 0
    if trap_stock <= 0:
        return {
            "success": false,
            "reason": "no_traps",
            "action": "trap",
            "trap_stock": trap_stock
        }

    var time_report = _spend_activity_time(TRAP_DEPLOY_HOURS, "trap_deploy")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "trap"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(TRAP_REST_COST_PERCENT)
    var calorie_total = sleep_system.adjust_daily_calories(TRAP_CALORIE_COST)
    var consume_report = inventory_system.consume_item(TRAP_ITEM_ID, 1)
    if !consume_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "trap"
        failure["success"] = false
        failure["reason"] = "consume_failed"
        failure["trap_stock"] = trap_stock
        failure["consume_report"] = consume_report
        return failure

    var snapshot := _trap_state.duplicate(true)
    snapshot["active"] = true
    snapshot["status"] = "deployed"
    snapshot["kills"] = 0
    snapshot["deployed_day"] = current_day
    snapshot["deployed_at_minutes"] = time_system.get_minutes_since_daybreak() if time_system else -1
    snapshot["deployed_at_time"] = time_system.get_formatted_time() if time_system else ""
    snapshot["trap_stock_before"] = trap_stock
    snapshot["trap_stock_after"] = inventory_system.get_item_count(TRAP_ITEM_ID)
    snapshot["rest_spent_percent"] = rest_spent
    snapshot["calories_spent"] = TRAP_CALORIE_COST
    snapshot["daily_calories_used"] = calorie_total
    snapshot["break_chance"] = TRAP_BREAK_CHANCE
    snapshot.erase("last_kill_day")
    snapshot.erase("last_kill_time")
    snapshot.erase("last_kill_minutes")
    snapshot.erase("break_roll")
    snapshot.erase("broken")
    snapshot.erase("returned_to_inventory")
    _trap_state = snapshot
    _broadcast_trap_state()

    var result := time_report.duplicate()
    result["success"] = true
    result["action"] = "trap"
    result["rest_spent_percent"] = rest_spent
    result["calories_spent"] = TRAP_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["trap_stock_before"] = trap_stock
    result["trap_stock_after"] = snapshot.get("trap_stock_after", trap_stock - 1)
    result["break_chance"] = TRAP_BREAK_CHANCE
    result["trap_consume_report"] = consume_report

    var injury = _roll_injury(TRAP_INJURY_CHANCE, TRAP_INJURY_DAMAGE, "trap_setup", "trap")
    if injury.get("triggered", false):
        result["injury_report"] = injury

    print("🪤 Trap deployed -> stock %d" % int(result.get("trap_stock_after", 0)))
    return result

func perform_place_snare() -> Dictionary:
    if time_system == null or sleep_system == null or inventory_system == null or _rng == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "snare_place"
        }

    var snare_stock = inventory_system.get_item_count(SNARE_ITEM_ID)
    if snare_stock <= 0:
        return {
            "success": false,
            "reason": "no_snares",
            "action": "snare_place",
            "snare_stock": snare_stock
        }

    if zombie_system and zombie_system.has_active_zombies():
        return {
            "success": false,
            "reason": "zombies_present",
            "action": "snare_place",
            "zombie_count": zombie_system.get_active_zombies()
        }

    var time_report = _spend_activity_time(SNARE_PLACE_HOURS, "snare_place")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "snare_place"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(SNARE_PLACE_REST_COST_PERCENT)
    var calorie_total = sleep_system.adjust_daily_calories(SNARE_PLACE_CALORIE_COST)

    var consume_report = inventory_system.consume_item(SNARE_ITEM_ID, 1)
    if !consume_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "snare_place"
        failure["success"] = false
        failure["reason"] = "consume_failed"
        failure["snare_stock"] = snare_stock
        failure["consume_report"] = consume_report
        return failure

    var snare_id = _next_snare_id
    _next_snare_id += 1
    var minutes_now = time_system.get_minutes_since_daybreak() if time_system else -1
    var placement := {
        "id": snare_id,
        "placed_day": current_day,
        "placed_minutes": minutes_now,
        "placed_time": time_system.get_formatted_time() if time_system else "",
        "has_animal": false,
        "minutes_buffer": 0.0,
        "animal": {},
        "last_progress_day": current_day,
        "last_progress_minutes": minutes_now
    }
    _snare_deployments.append(placement)
    _rebuild_snare_state()

    var result := time_report.duplicate()
    result["success"] = true
    result["action"] = "snare_place"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["calories_spent"] = SNARE_PLACE_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["snare_stock_before"] = snare_stock
    result["snare_stock_after"] = inventory_system.get_item_count(SNARE_ITEM_ID)
    result["snare_consume_report"] = consume_report
    result["snare_id"] = snare_id
    result["total_deployed"] = _snare_state.get("total_deployed", _snare_deployments.size())
    result["snare_state"] = get_snare_state()
    print("🪢 Snare #%d placed -> %d active" % [snare_id, int(result.get("total_deployed", 0))])
    return result

func perform_check_snares() -> Dictionary:
    if time_system == null or sleep_system == null or inventory_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "snare_check"
        }

    if _snare_deployments.is_empty():
        return {
            "success": false,
            "reason": "no_snares",
            "action": "snare_check",
            "snare_state": get_snare_state()
        }

    if zombie_system and zombie_system.has_active_zombies():
        return {
            "success": false,
            "reason": "zombies_present",
            "action": "snare_check",
            "zombie_count": zombie_system.get_active_zombies()
        }

    var time_report = _spend_activity_time(SNARE_CHECK_HOURS, "snare_check")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "snare_check"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var rest_spent = sleep_system.consume_sleep(SNARE_CHECK_REST_COST_PERCENT)
    var calorie_total = sleep_system.adjust_daily_calories(SNARE_CHECK_CALORIE_COST)

    var animals_collected: Array = []
    var total_food: float = 0.0
    for entry in _snare_deployments:
        if !entry.get("has_animal", false):
            continue
        var animal: Dictionary = entry.get("animal", {})
        if animal.is_empty():
            continue
        var food_units = float(animal.get("food_units", 0.0))
        var animal_id = String(animal.get("id", ""))
        if !animal_id.is_empty() and food_units > 0.0:
            _add_pending_game_food(animal_id, food_units)
            if inventory_system:
                inventory_system.add_food_units(food_units)
        animals_collected.append(animal.duplicate(true))
        total_food += food_units
        entry["animal"] = {}
        entry["has_animal"] = false
        entry["minutes_buffer"] = 0.0
        entry["last_progress_day"] = current_day
        entry["last_progress_minutes"] = time_system.get_minutes_since_daybreak() if time_system else -1

    _rebuild_snare_state()
    _emit_hunt_stock_changed()

    var result := time_report.duplicate()
    result["action"] = "snare_check"
    result["status"] = result.get("status", "applied")
    result["rest_spent_percent"] = rest_spent
    result["calories_spent"] = SNARE_CHECK_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["animals_collected"] = animals_collected
    result["animals_found"] = animals_collected.size()
    result["food_units_gained"] = total_food
    result["pending_stock"] = get_pending_game_stock()
    result["snare_state"] = get_snare_state()
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["total_food_units"] = inventory_system.get_total_food_units()

    if animals_collected.is_empty():
        result["success"] = false
        result["reason"] = "empty"
        result["message"] = "The snare is empty still, try again later."
        print("🪢 Snare check empty-handed")
    else:
        result["success"] = true
        print("🪢 Snare check collected %d animal(s) (+%.1f food)" % [animals_collected.size(), total_food])
    return result

func perform_recon() -> Dictionary:
    if time_system == null or sleep_system == null or weather_system == null or zombie_system == null or _rng == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "recon"
        }

    var window_status = get_recon_window_status()
    if !window_status.get("available", false):
        return {
            "success": false,
            "reason": String(window_status.get("reason", "recon_blocked")),
            "action": "recon",
            "window": window_status
        }

    var time_report = _spend_activity_time(1.0, "recon")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "recon"
        failure["reason"] = failure.get("reason", "time_rejected")
        return failure

    var calorie_total = sleep_system.adjust_daily_calories(RECON_CALORIE_COST)

    var rng_copy = RandomNumberGenerator.new()
    rng_copy.seed = _rng.seed
    rng_copy.state = _rng.state

    var weather_outlook = weather_system.forecast_precipitation(6)
    var zombie_outlook = _forecast_zombie_activity(6 * 60, rng_copy)
    var wolf_outlook: Dictionary = {}
    if wolf_system:
        var minutes_since = time_system.get_minutes_since_daybreak()
        wolf_outlook = wolf_system.forecast_activity(6, minutes_since)

    var result := time_report.duplicate()
    result["action"] = "recon"
    result["status"] = result.get("status", "applied")
    result["success"] = true
    result["hours_scanned"] = 6
    result["calories_spent"] = RECON_CALORIE_COST
    result["daily_calories_used"] = calorie_total
    result["weather_forecast"] = weather_outlook
    result["zombie_forecast"] = zombie_outlook
    result["wolf_forecast"] = wolf_outlook
    result["window_status"] = get_recon_window_status()
    _update_recon_alerts_from_forecast(weather_outlook, zombie_outlook, wolf_outlook)
    result["alerts"] = _recon_alerts.duplicate(true)

    _update_lure_target_from_forecast(result.get("zombie_forecast", {}))
    print("🔭 Recon outlook -> %s" % result)
    return result

func perform_travel_to_next_location() -> Dictionary:
    if expedition_system == null or time_system == null or sleep_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "action": "travel"
        }

    var state = expedition_system.get_state()
    if state.get("journey_complete", false):
        return {
            "success": false,
            "reason": "journey_complete",
            "action": "travel",
            "state": state
        }

    var option = expedition_system.get_selected_option()
    if option.is_empty():
        return {
            "success": false,
            "reason": "no_selection",
            "action": "travel",
            "state": state
        }

    var hours = float(option.get("travel_hours", TRAVEL_HOURS_MIN))
    if hours <= 0.0:
        hours = max(TRAVEL_HOURS_MIN, 0.5)
    hours = clamp(hours, TRAVEL_HOURS_MIN, TRAVEL_HOURS_MAX)

    var time_report = _spend_activity_time(hours, "travel")
    if !time_report.get("success", false):
        var failure := time_report.duplicate()
        failure["action"] = "travel"
        return failure

    var rest_cost = float(option.get("rest_cost_percent", TRAVEL_REST_COST_PERCENT))
    var calorie_cost = float(option.get("calorie_cost", TRAVEL_CALORIE_COST))
    var rest_spent = sleep_system.consume_sleep(rest_cost)
    var calorie_burn = sleep_system.adjust_daily_calories(calorie_cost)

    var journey_report = expedition_system.commit_selected_route()
    if !journey_report.get("success", false):
        var rollback := time_report.duplicate()
        rollback["action"] = "travel"
        rollback["success"] = false
        rollback["reason"] = journey_report.get("reason", "journey_blocked")
        rollback["state"] = expedition_system.get_state()
        return rollback

    var location = _apply_active_location(option)
    var encounter = _roll_travel_encounter(option)

    var result := time_report.duplicate()
    result["action"] = "travel"
    result["status"] = result.get("status", "applied")
    result["success"] = true
    result["option"] = option.duplicate(true)
    result["journey"] = journey_report.duplicate(true)
    result["rest_spent_percent"] = rest_spent
    result["rest_cost_percent"] = rest_cost
    result["calories_spent"] = calorie_cost
    result["daily_calories_used"] = calorie_burn
    result["sleep_percent_remaining"] = sleep_system.get_sleep_percent()
    result["travel_hours"] = hours
    result["minutes_required"] = time_report.get("minutes_required", result.get("minutes_spent", 0))
    result["state"] = expedition_system.get_state()
    result["location"] = location
    if !encounter.is_empty():
        result["encounter"] = encounter
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

    var hours = CRAFT_ACTION_HOURS
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

    var calorie_total = sleep_system.adjust_daily_calories(CRAFT_CALORIE_COST)

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
    result["calories_spent"] = CRAFT_CALORIE_COST
    result["daily_calories_used"] = calorie_total

    var material_summary: PackedStringArray = []
    for entry in materials_spent:
        var label = entry.get("display_name", entry.get("item_id", "Material"))
        var qty = int(entry.get("quantity", 0))
        material_summary.append("%s -%d" % [label, max(qty, 0)])
    if material_summary.is_empty():
        material_summary.append("No materials")
    print("🛠️ Crafted %s -> +%d (%s)" % [result.get("display_name", key.capitalize()), result.get("quantity_added", quantity), ", ".join(material_summary)])
    return result

func perform_inventory_action(item_id: String, action: String = "use") -> Dictionary:
    var key = item_id.to_lower()
    var normalized_action = action.to_lower()
    if inventory_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "item_id": key,
            "action": normalized_action
        }
    if key == "flashlight":
        return _handle_flashlight_action(normalized_action)
    if normalized_action != "use":
        return {
            "success": false,
            "reason": "unsupported_item",
            "item_id": key,
            "action": normalized_action
        }
    if health_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "item_id": key,
            "action": normalized_action
        }
    if key == "medicinal_herbs":
        return _consume_health_item(key, 1, 10.0, "medicinal_herb_use")
    if key == "herbal_first_aid_kit":
        return _consume_health_item(key, 1, 50.0, "herbal_first_aid")
    if key == "bandage":
        return _consume_health_item(key, 1, 10.0, "bandage_use")
    if key == "medicated_bandage":
        return _consume_health_item(key, 1, 25.0, "medicated_bandage_use")
    return {
        "success": false,
        "reason": "unsupported_item",
        "item_id": key,
        "action": normalized_action
    }

func use_inventory_item(item_id: String) -> Dictionary:
    return perform_inventory_action(item_id, "use")

func _is_fishing_prime_time(minute_of_day: int) -> bool:
    var normalized = (minute_of_day % TimeSystem.MINUTES_PER_DAY + TimeSystem.MINUTES_PER_DAY) % TimeSystem.MINUTES_PER_DAY
    return (normalized >= 6 * 60 and normalized < 9 * 60) or (normalized >= 17 * 60 and normalized < 20 * 60)

func _pick_fishing_size(roll: float) -> Dictionary:
    roll = clamp(roll, 0.0, 1.0)
    var cumulative = 0.0
    for entry in FISHING_SIZE_TABLE:
        var chance = float(entry.get("chance", 0.0))
        if chance <= 0.0:
            continue
        cumulative += chance
        if roll <= cumulative + 0.00001:
            return entry
    if FISHING_SIZE_TABLE.size() > 0:
        return FISHING_SIZE_TABLE[FISHING_SIZE_TABLE.size() - 1]
    return {}


func _roll_forging_loot_for_location() -> Array:
    var profile_id = _get_active_forage_profile()
    var table = _get_forage_table(profile_id)
    return _roll_loot_from_table(table)

func _roll_campground_loot() -> Array:
    var profile_id = _get_active_forage_profile()
    if profile_id == "stream_banks":
        profile_id = "camp_cache"
    var table = _get_forage_table(profile_id)
    return _roll_loot_from_table(table)

func _get_active_forage_profile() -> String:
    var location = get_active_location()
    var profile = String(location.get("forage_profile", "tower_standard"))
    if profile.is_empty():
        return "tower_standard"
    return profile.to_lower()

func _get_forage_table(profile_id: String) -> Array:
    var key = profile_id.to_lower()
    if key == "wild_standard":
        key = "tower_standard"
    if !FORAGE_PROFILE_TABLES.has(key):
        key = "tower_standard"
    var source: Array = FORAGE_PROFILE_TABLES.get(key, [])
    var cloned: Array = []
    for entry in source:
        if typeof(entry) == TYPE_DICTIONARY:
            cloned.append(entry.duplicate(true))
        else:
            cloned.append(entry)
    return cloned

func _roll_travel_encounter(option: Dictionary) -> Dictionary:
    if _rng == null or health_system == null:
        return {}
    var location = get_active_location()
    var hazard = String(location.get("hazard_tier", option.get("hazard_tier", "watchful"))).to_lower()
    var tier: Dictionary = TRAVEL_HAZARD_TIERS.get(hazard, TRAVEL_HAZARD_TIERS.get("watchful", {}))
    var min_chance = float(tier.get("chance_min", 0.18))
    var max_chance = float(tier.get("chance_max", 0.32))
    if max_chance < min_chance:
        var swap = min_chance
        min_chance = max_chance
        max_chance = swap
    var base_roll = _rng.randf_range(min_chance, max_chance)
    var fatigue_penalty = 0.0
    if sleep_system and sleep_system.get_sleep_percent() <= 35.0:
        fatigue_penalty = 0.10
    var has_knife = inventory_system and inventory_system.get_item_count(CRAFTED_KNIFE_ID) > 0
    var has_bow = inventory_system and inventory_system.get_item_count("bow") > 0
    var has_arrows = inventory_system and inventory_system.get_item_count("arrow") > 0
    var weapon_reduction = 0.0
    if has_knife:
        weapon_reduction += float(TRAVEL_WEAPON_CHANCE_REDUCTION.get("knife", 0.0))
    if has_bow and has_arrows:
        weapon_reduction += float(TRAVEL_WEAPON_CHANCE_REDUCTION.get("ranged", 0.0))
    weapon_reduction = clamp(weapon_reduction, 0.0, 0.95)
    var chance = clamp(base_roll + fatigue_penalty - weapon_reduction, 0.0, 1.0)
    var roll = _rng.randf()
    var encounter := {
        "hazard_tier": hazard,
        "chance": chance,
        "base_roll": base_roll,
        "roll": roll,
        "fatigue_penalty": fatigue_penalty,
        "weapon_reduction": weapon_reduction,
        "has_knife": has_knife,
        "has_bow": has_bow,
        "has_arrows": has_arrows,
        "triggered": roll < chance
    }
    if !encounter.get("triggered", false):
        return encounter
    var focus: Dictionary = location.get("encounter_focus", option.get("encounter_focus", {}))
    var threat = _pick_travel_encounter_type(focus)
    encounter["type"] = threat
    var damage_report = _resolve_encounter_damage(threat, has_knife, has_bow and has_arrows)
    if !damage_report.is_empty():
        for key in damage_report.keys():
            encounter[key] = damage_report[key]
    return encounter

func _pick_travel_encounter_type(focus: Dictionary) -> String:
    var weights: Dictionary = {}
    var total := 0.0
    for entry in TRAVEL_ENCOUNTER_TYPES:
        var weight = float(focus.get(entry, 0.0))
        if weight < 0.0:
            weight = 0.0
        weights[entry] = weight
        total += weight
    if total <= 0.0:
        return TRAVEL_ENCOUNTER_TYPES[_rng.randi_range(0, TRAVEL_ENCOUNTER_TYPES.size() - 1)]
    var roll = _rng.randf() * total
    var cumulative := 0.0
    for entry in TRAVEL_ENCOUNTER_TYPES:
        cumulative += float(weights.get(entry, 0.0))
        if roll <= cumulative:
            return entry
    return TRAVEL_ENCOUNTER_TYPES.back()

func _resolve_encounter_damage(threat: String, has_knife: bool, has_ranged: bool) -> Dictionary:
    var key = threat.to_lower()
    var ranges: Dictionary = TRAVEL_ENCOUNTER_DAMAGE.get(key, {})
    if ranges.is_empty() or _rng == null or health_system == null:
        return {}
    var min_damage = int(ranges.get("min", 0))
    var max_damage = int(ranges.get("max", min_damage))
    if max_damage < min_damage:
        var swap = min_damage
        min_damage = max_damage
        max_damage = swap
    var rolled = _rng.randi_range(min_damage, max_damage)
    var mitigation_key := "none"
    if has_knife and has_ranged:
        mitigation_key = "dual"
    elif has_knife or has_ranged:
        mitigation_key = "single"
    var mitigation_factor = float(TRAVEL_ENCOUNTER_MITIGATION.get(mitigation_key, 1.0))
    var mitigated = mitigation_key != "none"
    var adjusted = int(round(rolled * mitigation_factor)) if mitigation_factor > 0.0 else 0
    var report := {
        "damage_roll": rolled,
        "damage_min": min_damage,
        "damage_max": max_damage,
        "mitigated": mitigated,
        "mitigation_factor": mitigation_factor,
        "mitigation_tier": mitigation_key,
        "damage_applied": 0.0
    }
    if adjusted <= 0:
        report["health_before"] = health_system.get_health()
        report["health_after"] = report["health_before"]
        return report
    var damage_report = health_system.apply_damage(adjusted, "travel_%s" % key)
    report["damage_report"] = damage_report
    report["damage_applied"] = float(damage_report.get("applied", adjusted))
    report["health_before"] = damage_report.get("previous_health", damage_report.get("health_before", health_system.get_health()))
    report["health_after"] = damage_report.get("new_health", damage_report.get("health_after", health_system.get_health()))
    return report

func _emit_hunt_stock_changed():
    hunt_stock_changed.emit(get_pending_game_stock())

func _round_up_to_half(value: float) -> float:
    if value <= 0.0:
        return 0.0
    return ceil(value * 2.0) / 2.0

func _roll_loot_from_table(table: Array) -> Array:
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

func _apply_carry_capacity(entries: Array) -> Dictionary:
    var capacity = get_carry_capacity()
    var retained: Array = []
    var dropped: Array = []
    if capacity <= 0:
        for entry in entries:
            dropped.append(entry)
    else:
        for entry in entries:
            if retained.size() < capacity:
                retained.append(entry)
            else:
                dropped.append(entry)
    return {
        "capacity": capacity,
        "retained": retained,
        "dropped": dropped
    }

func _format_dropped_entries(entries: Array) -> Array:
    var formatted: Array = []
    for entry in entries:
        var item_id = String(entry.get("item_id", ""))
        if item_id.is_empty():
            continue
        var display = inventory_system.get_item_display_name(item_id) if inventory_system else item_id.capitalize()
        formatted.append({
            "item_id": item_id,
            "display_name": display,
            "quantity": int(entry.get("quantity", 1)),
            "chance": float(entry.get("chance", 0.0)),
            "roll": float(entry.get("roll", 0.0))
        })
    return formatted

func _ensure_tutorial_popup() -> bool:
    if is_instance_valid(_tutorial_popup):
        return true
    var tree = get_tree()
    if tree == null:
        return false
    var root = tree.get_root()
    if root == null:
        return false
    var node = root.get_node_or_null("Main/UI/ActionPopupPanel")
    if node is ActionPopupPanel:
        _tutorial_popup = node
    return is_instance_valid(_tutorial_popup)

func _resolve_tutorial_popup():
    _ensure_tutorial_popup()

func _trigger_spawn_tutorial():
    request_tutorial("tower_welcome")

func request_tutorial(tutorial_id: String) -> bool:
    var key = tutorial_id.to_lower()
    if _tutorial_flags.get(key, false):
        return false
    var payload = _build_tutorial_payload(key)
    if payload.is_empty():
        _tutorial_flags[key] = true
        return false
    if !_ensure_tutorial_popup():
        return false
    var title = String(payload.get("title", ""))
    var lines: PackedStringArray = payload.get("lines", PackedStringArray([]))
    if lines.is_empty():
        _tutorial_flags[key] = true
        return false
    _tutorial_popup.show_message(title, lines)
    _tutorial_flags[key] = true
    return true

func _build_tutorial_payload(key: String) -> Dictionary:
    match key:
        "tower_welcome":
            return {
                "title": "Welcome to Lone Pine",
                "lines": PackedStringArray([
                    "Hey lookout! Dispatch here—we've got the tower ready for your watch.",
                    "Start each morning with the radio, keep the stove humming, and scan the horizon from the deck.",
                    "Forge supplies, cook rations, and patch the tower—tidy packs make every job quicker.",
                    "When you're carving meat you might think, 'If I had a sharper tool though…'—a honed knife saves precious bites."
                ])
            }
        "inventory_intro":
            return {
                "title": "Supply Locker Primer",
                "lines": PackedStringArray([
                    "Your locker sorts gear by stack so you can spot tools at a glance.",
                    "Keep materials grouped; clean shelves mean the crafting bench grabs what it needs without fuss.",
                    "Snag a backpack when you find one—extra carry space buys longer scavenges between trips."
                ])
            }
        "crafting_intro":
            return {
                "title": "Workbench Brief",
                "lines": PackedStringArray([
                    "Highlight any blueprint to see the resource list and my scribbled hints.",
                    "Pair bows with fresh arrows, knives with butchering, and keep spare tinder ready for fire kits.",
                    "Build a portable craft station once you're roaming so trail repairs stay on schedule."
                ])
            }
    return {}

func _on_day_rolled_over():
    current_day += 1
    print("🌅 New day begins: Day %d" % current_day)
    if sleep_system:
        sleep_system.reset_daily_counters()
    _last_awake_minute_stamp = 0
    if tower_health_system:
        var current_state = weather_system.get_state() if weather_system else WeatherSystem.WEATHER_CLEAR
        tower_health_system.on_day_completed(current_state)
    _handle_daily_supply_decay("day_rollover")
    if news_system:
        news_system.reset_day(current_day)
    _spawn_daily_supply_drop("day_rollover")
    _refresh_radio_attention("day_rollover")
    if zombie_system:
        zombie_system.start_day(current_day, _rng)
    if wolf_system:
        wolf_system.start_day(current_day, _rng)
    _clear_lure_target("day_rollover")
    day_changed.emit(current_day)

func _on_weather_system_changed(new_state: String, previous_state: String, hours_remaining: int):
    var multiplier = get_weather_activity_multiplier()
    weather_changed.emit(new_state, previous_state, hours_remaining)
    weather_multiplier_changed.emit(multiplier, new_state)

func _on_weather_hour_elapsed(state: String):
    if tower_health_system:
        tower_health_system.register_weather_hour(state)

func _on_time_advanced_by_minutes(minutes: int, rolled_over: bool):
    if time_system == null:
        return
    _advance_wood_stove(minutes)
    _advance_snares(minutes, rolled_over)
    var current_minutes = time_system.get_minutes_since_daybreak()
    if wolf_system:
        var wolf_report = wolf_system.advance_time(minutes, current_minutes, rolled_over)
        if typeof(wolf_report) == TYPE_DICTIONARY:
            if wolf_report.has("arrived"):
                print("🐺 Wolves spotted near the tower")
            if wolf_report.has("departed"):
                print("🐺 Wolves left the perimeter")
    if zombie_system == null or tower_health_system == null:
        return
    var report = zombie_system.advance_time(minutes, current_minutes, rolled_over)
    var spawn_event = report.get("spawn_event")
    if spawn_event is Dictionary:
        var added = int(spawn_event.get("spawns", 0))
        var total = int(spawn_event.get("total", zombie_system.get_active_zombies()))
        if added > 0:
            print("🧟 Wave sighted -> +%d (%d total)" % [added, total])
    if report.get("ticks", 0) <= 0:
        return
    var damage = float(report.get("total_damage", 0.0))
    if damage > 0.0:
        tower_health_system.apply_damage(damage, "zombie_presence")
    _advance_recon_alerts(minutes)
    _refresh_lure_status(true)

func _on_zombies_spawned(added: int, _total: int, day: int):
    if added <= 0:
        return
    if !_trap_state.get("active", false):
        return
    if zombie_system == null:
        return

    var removed = zombie_system.remove_zombies(1)
    if removed <= 0:
        return

    var roll = _rng.randf() if _rng else 1.0
    var broke = roll < TRAP_BREAK_CHANCE
    var snapshot := _trap_state.duplicate(true)
    snapshot["active"] = false
    snapshot["status"] = "triggered"
    snapshot["kills"] = snapshot.get("kills", 0) + removed
    snapshot["last_kill_day"] = day
    snapshot["last_kill_minutes"] = time_system.get_minutes_since_daybreak() if time_system else -1
    snapshot["last_kill_time"] = time_system.get_formatted_time() if time_system else ""
    snapshot["break_roll"] = roll
    snapshot["broken"] = broke
    snapshot["zombies_after"] = zombie_system.get_active_zombies()
    var stock_before = inventory_system.get_item_count(TRAP_ITEM_ID) if inventory_system else 0
    snapshot["trap_stock_before_trigger"] = stock_before
    if !broke and inventory_system:
        var add_report = inventory_system.add_item(TRAP_ITEM_ID, 1)
        snapshot["trap_return_report"] = add_report
        snapshot["returned_to_inventory"] = true
        snapshot["trap_stock_after"] = inventory_system.get_item_count(TRAP_ITEM_ID)
    else:
        snapshot["returned_to_inventory"] = false
        snapshot["trap_stock_after"] = stock_before
    _trap_state = snapshot
    _broadcast_trap_state()

    if broke:
        print("🪤 Trap snapped after intercept (roll %.2f)" % roll)
    else:
        print("🪤 Trap held, returned to inventory (roll %.2f)" % roll)

func _on_wolves_state_changed(state: Dictionary):
    if typeof(state) == TYPE_DICTIONARY:
        _wolf_state = state.duplicate(true)
    else:
        _wolf_state = {}
    wolf_state_changed.emit(_wolf_state.duplicate(true))
    _refresh_lure_status(true)

func _on_zombie_damage_tower(damage: float, count: int):
    print("🧟 Zombies inflicted %.2f damage (%d active)" % [damage, count])

func _on_wood_stove_state_changed(state: Dictionary):
    wood_stove_state_changed.emit(state.duplicate(true))

func _apply_awake_time_up_to(current_minutes: int):
    if not sleep_system or not time_system:
        return

    var delta = current_minutes - _last_awake_minute_stamp
    if delta < 0:
        delta += TimeSystem.MINUTES_PER_DAY
    if delta > 0:
        sleep_system.apply_awake_minutes(delta)
        if warmth_system:
            warmth_system.apply_environment_minutes(delta, _last_awake_minute_stamp, false)
        _advance_wood_stove(delta)
    _last_awake_minute_stamp = current_minutes

func _advance_wood_stove(minutes: int):
    if wood_stove_system == null or minutes <= 0:
        return
    wood_stove_system.advance_minutes(minutes, warmth_system)

func _advance_snares(minutes: int, rolled_over: bool):
    if minutes <= 0:
        return
    if _snare_deployments.is_empty():
        if rolled_over:
            _rebuild_snare_state()
        return
    if _rng == null:
        return
    var changed: bool = false
    var time_now = time_system.get_minutes_since_daybreak() if time_system else -1
    for entry in _snare_deployments:
        entry["last_progress_day"] = current_day
        entry["last_progress_minutes"] = time_now
        if entry.get("has_animal", false):
            continue
        var buffer = float(entry.get("minutes_buffer", 0.0)) + float(minutes)
        var caught = false
        while buffer >= 60.0 and !caught:
            buffer -= 60.0
            var roll = _rng.randf()
            entry["last_roll"] = {
                "roll": roll,
                "chance": SNARE_CATCH_CHANCE,
                "minutes": time_now,
                "day": current_day
            }
            if roll < SNARE_CATCH_CHANCE:
                var animal = _choose_snare_animal()
                if animal.is_empty():
                    continue
                var snare_id = int(entry.get("id", 0))
                animal["snare_id"] = snare_id
                animal["caught_day"] = current_day
                animal["caught_at_minutes"] = time_system.get_minutes_since_daybreak() if time_system else -1
                animal["caught_at_time"] = time_system.get_formatted_time() if time_system else ""
                animal["catch_roll"] = roll
                animal["catch_chance"] = SNARE_CATCH_CHANCE
                entry["animal"] = animal
                entry["has_animal"] = true
                buffer = max(buffer, 0.0)
                caught = true
                changed = true
                print("🪢 Snare #%d caught %s (roll %.2f)" % [snare_id, animal.get("label", "Game"), roll])
        entry["minutes_buffer"] = buffer
    if changed or minutes >= 60 or rolled_over:
        _rebuild_snare_state()

func _resolve_meal_portion(portion_key: String) -> Dictionary:
    var key = portion_key.to_lower()
    if key.is_empty() or !MEAL_PORTIONS.has(key):
        key = "normal"
    var definition: Dictionary = MEAL_PORTIONS.get(key, MEAL_PORTIONS["normal"])
    var resolved := definition.duplicate()
    resolved["key"] = key
    resolved["calories"] = resolved.get("food_units", 1.0) * CALORIES_PER_FOOD_UNIT
    return resolved

func _forecast_zombie_activity(minutes_horizon: int, rng: RandomNumberGenerator) -> Dictionary:
    minutes_horizon = max(minutes_horizon, 0)
    var forecast := {
        "minutes_horizon": minutes_horizon,
        "current_day": current_day,
        "active_now": zombie_system.get_active_zombies() if zombie_system else 0,
        "events": []
    }

    if time_system == null or zombie_system == null:
        forecast["reason"] = "systems_unavailable"
        return forecast

    forecast["current_clock"] = time_system.get_formatted_time()
    var minutes_since = time_system.get_minutes_since_daybreak()
    var minutes_until_daybreak = time_system.get_minutes_until_daybreak()
    forecast["minutes_until_daybreak"] = minutes_until_daybreak

    var pending = zombie_system.get_pending_spawn()
    if typeof(pending) == TYPE_DICTIONARY and !pending.is_empty():
        var spawn_day = int(pending.get("day", current_day))
        var spawn_minute = int(pending.get("minute", -1))
        if spawn_day == current_day and spawn_minute >= 0:
            var minutes_until_spawn = spawn_minute - minutes_since
            if minutes_until_spawn < 0:
                minutes_until_spawn += TimeSystem.MINUTES_PER_DAY
            if minutes_until_spawn <= minutes_horizon:
                var event = pending.duplicate(true)
                event["minutes_ahead"] = minutes_until_spawn
                event["clock_time"] = time_system.get_formatted_time_after(minutes_until_spawn)
                event["type"] = "scheduled_spawn"
                forecast["events"].append(event)

    if rng == null:
        return forecast

    if minutes_horizon > minutes_until_daybreak:
        var preview_rng = RandomNumberGenerator.new()
        preview_rng.seed = rng.seed
        preview_rng.state = rng.state

        var next_day = current_day + 1
        var projection = zombie_system.preview_day_spawn(next_day, preview_rng)
        if int(projection.get("spawns", 0)) > 0:
            var scheduled_minute = int(projection.get("scheduled_minute", -1))
            if scheduled_minute >= 0:
                var total_minutes = minutes_until_daybreak + scheduled_minute
                if total_minutes <= minutes_horizon:
                    projection["minutes_ahead"] = total_minutes
                    projection["clock_time"] = time_system.get_formatted_time_after(total_minutes)
                    projection["type"] = "next_day_spawn"
                    forecast["events"].append(projection)
    return forecast

func _apply_lure_injury(successes: int, failures: int) -> Dictionary:
    var safe_successes = max(successes, 0)
    var safe_failures = max(failures, 0)
    if health_system == null or _rng == null:
        return {
            "successes": safe_successes,
            "failures": safe_failures,
            "triggered_successes": 0,
            "triggered_failures": 0,
            "events": [],
            "total_damage": 0.0,
            "health_before": 0.0,
            "health_after": 0.0,
            "triggered": false
        }

    var health_before = health_system.get_health()
    var triggered_successes = 0
    var triggered_failures = 0
    var total_damage = 0.0
    var events: Array = []

    for _i in range(safe_successes):
        var outcome = _roll_injury(LURE_SUCCESS_INJURY_CHANCE, LURE_SUCCESS_INJURY_DAMAGE, "lure_success", "success")
        if outcome.get("triggered", false):
            triggered_successes += 1
            total_damage += float(outcome.get("damage", 0.0))
            events.append(outcome)

    for _j in range(safe_failures):
        var outcome = _roll_injury(LURE_FAILURE_INJURY_CHANCE, LURE_FAILURE_INJURY_DAMAGE, "lure_failure", "failure")
        if outcome.get("triggered", false):
            triggered_failures += 1
            total_damage += float(outcome.get("damage", 0.0))
            events.append(outcome)

    var health_after = health_system.get_health()
    return {
        "successes": safe_successes,
        "failures": safe_failures,
        "triggered_successes": triggered_successes,
        "triggered_failures": triggered_failures,
        "events": events,
        "total_damage": total_damage,
        "health_before": health_before,
        "health_after": health_after,
        "triggered": total_damage > 0.0
    }

func _roll_injury(chance: float, damage: float, source: String, tag: String) -> Dictionary:
    var normalized_chance = clamp(chance, 0.0, 1.0)
    if health_system == null or _rng == null or normalized_chance <= 0.0 or damage <= 0.0:
        return {
            "triggered": false,
            "damage": 0.0,
            "chance": normalized_chance,
            "roll": 1.0,
            "source": source,
            "tag": tag,
            "health_before": health_system.get_health() if health_system else 0.0,
            "health_after": health_system.get_health() if health_system else 0.0
        }

    var before = health_system.get_health()
    var roll = _rng.randf()
    var outcome := {
        "triggered": false,
        "damage": 0.0,
        "chance": normalized_chance,
        "roll": roll,
        "source": source,
        "tag": tag,
        "health_before": before,
        "health_after": before
    }

    if roll >= normalized_chance:
        return outcome

    var damage_report = health_system.apply_damage(damage, source)
    var applied = float(damage_report.get("applied", 0.0))
    var after = float(damage_report.get("new_health", health_system.get_health()))
    outcome["triggered"] = applied > 0.0
    outcome["damage"] = applied
    outcome["health_after"] = after
    return outcome

func _apply_wolf_encounter(action: String) -> Dictionary:
    if wolf_system == null or _rng == null or health_system == null:
        return {}
    if !wolf_system.has_active_wolves():
        return {}

    var roll = _rng.randf()
    var encounter := {
        "action": action,
        "chance": WOLF_ATTACK_CHANCE,
        "roll": roll,
        "wolves_present": true,
        "wolf_state": wolf_system.get_state(),
        "triggered": roll < WOLF_ATTACK_CHANCE
    }

    encounter["damage_applied"] = 0.0
    encounter["health_before"] = health_system.get_health()
    encounter["health_after"] = encounter["health_before"]

    if !encounter.get("triggered", false):
        return encounter

    var damage = _rng.randi_range(WOLF_ATTACK_DAMAGE_MIN, WOLF_ATTACK_DAMAGE_MAX)
    encounter["damage_roll"] = damage
    if damage > 0:
        var report = health_system.apply_damage(damage, "%s_wolves" % action)
        encounter["damage_report"] = report
        encounter["damage_applied"] = float(report.get("applied", damage))
        encounter["health_before"] = report.get("previous_health", report.get("health_before", health_system.get_health()))
        encounter["health_after"] = report.get("new_health", report.get("health_after", health_system.get_health()))
    else:
        encounter["damage_applied"] = 0.0
    return encounter

func _update_recon_alerts_from_forecast(weather_forecast: Dictionary, zombie_forecast: Dictionary, wolf_forecast: Dictionary = {}):
    var alerts: Dictionary = {}
    var weather_alert = _resolve_weather_alert(weather_forecast)
    if !weather_alert.is_empty():
        alerts["weather"] = weather_alert
    var zombie_alert = _resolve_zombie_alert(zombie_forecast)
    if !zombie_alert.is_empty():
        alerts["zombies"] = zombie_alert
    var wolf_alert = _resolve_wolf_alert(wolf_forecast)
    if !wolf_alert.is_empty():
        alerts["wolves"] = wolf_alert
    _set_recon_alerts(alerts)

func _resolve_weather_alert(forecast: Dictionary) -> Dictionary:
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return {}
    var events: Array = forecast.get("events", [])
    if events.is_empty():
        return {}
    var best_minutes = -1
    var best_state = ""
    for event in events:
        if typeof(event) != TYPE_DICTIONARY:
            continue
        if String(event.get("type", "")) != "start":
            continue
        var minutes = int(event.get("minutes_ahead", 0))
        if minutes <= 0:
            continue
        var state = String(event.get("state", WeatherSystem.WEATHER_SPRINKLING))
        var precipitating = weather_system.is_precipitating_state(state) if weather_system else state != WeatherSystem.WEATHER_CLEAR
        if !precipitating:
            continue
        if best_minutes < 0 or minutes < best_minutes:
            best_minutes = minutes
            best_state = state
    if best_minutes < 0:
        return {}
    var label = weather_system.get_state_display_name_for(best_state) if weather_system else best_state.capitalize()
    return {
        "type": "weather",
        "minutes_until": float(best_minutes),
        "state": best_state,
        "label": label,
        "active": true,
        "clock_time": time_system.get_formatted_time_after(best_minutes) if time_system else ""
    }

func _resolve_zombie_alert(forecast: Dictionary) -> Dictionary:
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return {}
    var events: Array = forecast.get("events", [])
    if events.is_empty():
        return {}
    var best_event: Dictionary = {}
    var best_minutes = -1
    for event in events:
        if typeof(event) != TYPE_DICTIONARY:
            continue
        var minutes = int(event.get("minutes_ahead", 0))
        if minutes <= 0:
            continue
        if best_minutes < 0 or minutes < best_minutes:
            best_minutes = minutes
            best_event = event
    if best_minutes < 0 or best_event.is_empty():
        return {}
    var quantity = int(best_event.get("quantity", best_event.get("spawns", best_event.get("added", 0))))
    return {
        "type": "zombies",
        "minutes_until": float(best_minutes),
        "quantity": max(quantity, 0),
        "active": true,
        "clock_time": String(best_event.get("clock_time", time_system.get_formatted_time_after(best_minutes) if time_system else "")),
        "label": "Zombies"
    }

func _resolve_wolf_alert(forecast: Dictionary) -> Dictionary:
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return {}
    var events: Array = forecast.get("events", [])
    if events.is_empty():
        return {}

    var arrival_minutes = -1
    var active_event: Dictionary = {}
    for event in events:
        if typeof(event) != TYPE_DICTIONARY:
            continue
        var event_type = String(event.get("type", ""))
        if event_type == "arrival":
            var minutes = int(event.get("minutes_ahead", 0))
            if minutes < 0:
                continue
            if arrival_minutes < 0 or minutes < arrival_minutes:
                arrival_minutes = minutes
        elif event_type == "active":
            active_event = event.duplicate(true)

    if !active_event.is_empty():
        var remaining = int(active_event.get("minutes_remaining", 0))
        return {
            "type": "wolves",
            "minutes_until": 0.0,
            "minutes_remaining": max(remaining, 0),
            "active": true,
            "label": "Wolves",
            "clock_time": time_system.get_formatted_time() if time_system else ""
        }

    if arrival_minutes < 0:
        return {}

    return {
        "type": "wolves",
        "minutes_until": float(arrival_minutes),
        "active": true,
        "label": "Wolves",
        "clock_time": time_system.get_formatted_time_after(arrival_minutes) if time_system else ""
    }

func _set_recon_alerts(alerts: Dictionary):
    var normalized: Dictionary = {}
    for key in alerts.keys():
        var entry = alerts.get(key, {})
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        normalized[key] = entry.duplicate(true)
    _recon_alerts = normalized
    _emit_recon_alerts_changed()

func _advance_recon_alerts(minutes: int):
    if minutes <= 0 or _recon_alerts.is_empty():
        return
    var changed = false
    for key in _recon_alerts.keys():
        var entry = _recon_alerts.get(key, {})
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var remaining = float(entry.get("minutes_until", -1))
        if remaining < 0.0:
            continue
        var updated = max(remaining - minutes, 0.0)
        if !is_equal_approx(updated, remaining):
            entry["minutes_until"] = updated
            if updated <= 0.0:
                entry["active"] = false
            _recon_alerts[key] = entry
            changed = true
    if changed:
        _emit_recon_alerts_changed()

func _emit_recon_alerts_changed():
    recon_alerts_changed.emit(_recon_alerts.duplicate(true))

func _handle_flashlight_action(action: String) -> Dictionary:
    var normalized = action.to_lower()
    if inventory_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "item_id": "flashlight",
            "action": normalized
        }
    var has_flashlight = inventory_system.get_item_count("flashlight") > 0
    if !has_flashlight:
        flashlight_active = false
        flashlight_battery_percent = clamp(flashlight_battery_percent, 0.0, FLASHLIGHT_BATTERY_MAX)
        return {
            "success": false,
            "reason": "missing_flashlight",
            "item_id": "flashlight",
            "action": normalized
        }
    match normalized:
        "use":
            return _toggle_flashlight_active()
        "change_batteries":
            return _change_flashlight_batteries()
        _:
            return {
                "success": false,
                "reason": "unsupported_item",
                "item_id": "flashlight",
                "action": normalized
            }

func _toggle_flashlight_active() -> Dictionary:
    flashlight_battery_percent = clamp(flashlight_battery_percent, 0.0, FLASHLIGHT_BATTERY_MAX)
    if flashlight_battery_percent <= 0.0:
        flashlight_active = false
        return {
            "success": false,
            "reason": "no_battery",
            "item_id": "flashlight",
            "action": "use",
            "flashlight_active": flashlight_active,
            "flashlight_battery": flashlight_battery_percent,
            "display_name": inventory_system.get_item_display_name("flashlight")
        }
    flashlight_active = !flashlight_active
    return {
        "success": true,
        "item_id": "flashlight",
        "action": "flashlight_toggle",
        "flashlight_active": flashlight_active,
        "flashlight_battery": flashlight_battery_percent,
        "display_name": inventory_system.get_item_display_name("flashlight")
    }

func _change_flashlight_batteries() -> Dictionary:
    if inventory_system == null:
        return {
            "success": false,
            "reason": "systems_unavailable",
            "item_id": "flashlight",
            "action": "change_batteries"
        }
    var stock = inventory_system.get_item_count("batteries")
    if stock <= 0:
        return {
            "success": false,
            "reason": "no_batteries",
            "item_id": "flashlight",
            "action": "change_batteries"
        }
    if flashlight_battery_percent >= FLASHLIGHT_BATTERY_MAX - 0.01:
        return {
            "success": false,
            "reason": "battery_full",
            "item_id": "flashlight",
            "action": "change_batteries"
        }
    var consume_report = inventory_system.consume_item("batteries", 1)
    if !consume_report.get("success", false):
        var failure = consume_report.duplicate(true)
        failure["success"] = false
        failure["item_id"] = "flashlight"
        failure["action"] = "change_batteries"
        failure["reason"] = failure.get("reason", "consume_failed")
        return failure
    flashlight_battery_percent = FLASHLIGHT_BATTERY_MAX
    flashlight_active = false
    return {
        "success": true,
        "item_id": "flashlight",
        "action": "flashlight_batteries",
        "flashlight_battery": flashlight_battery_percent,
        "flashlight_active": flashlight_active,
        "display_name": inventory_system.get_item_display_name("flashlight"),
        "batteries_remaining": consume_report.get("quantity_remaining", inventory_system.get_item_count("batteries"))
    }

func _consume_flashlight_battery(minutes_spent: int) -> Dictionary:
    minutes_spent = max(minutes_spent, 0)
    if minutes_spent <= 0 or !flashlight_active:
        return {}
    if inventory_system == null:
        flashlight_active = false
        return {
            "active": false,
            "reason": "systems_unavailable",
            "item_id": "flashlight"
        }
    var has_flashlight = inventory_system.get_item_count("flashlight") > 0
    if !has_flashlight:
        flashlight_active = false
        flashlight_battery_percent = 0.0
        return {
            "active": false,
            "reason": "missing_flashlight",
            "item_id": "flashlight",
            "battery_percent": flashlight_battery_percent
        }
    var hours = float(minutes_spent) / 60.0
    var drain = hours * FLASHLIGHT_BATTERY_DRAIN_PER_HOUR
    if drain <= 0.0:
        return {}
    flashlight_battery_percent = clamp(flashlight_battery_percent, 0.0, FLASHLIGHT_BATTERY_MAX)
    var previous = flashlight_battery_percent
    flashlight_battery_percent = clamp(previous - drain, 0.0, FLASHLIGHT_BATTERY_MAX)
    var report := {
        "item_id": "flashlight",
        "active": flashlight_active,
        "battery_spent": min(drain, previous),
        "battery_percent": flashlight_battery_percent
    }
    if flashlight_battery_percent <= 0.0:
        flashlight_battery_percent = 0.0
        flashlight_active = false
        report["active"] = false
        report["deactivated"] = true
        report["reason"] = "battery_depleted"
    return report

func _consume_health_item(item_id: String, quantity: int, heal_amount: float, source: String) -> Dictionary:
    quantity = max(quantity, 1)
    heal_amount = max(heal_amount, 0.0)
    var available = inventory_system.get_item_count(item_id)
    if available < quantity:
        return {
            "success": false,
            "reason": "insufficient_stock",
            "item_id": item_id,
            "required": quantity,
            "available": available
        }

    var consume_report = inventory_system.consume_item(item_id, quantity)
    if !consume_report.get("success", false):
        var failure = consume_report.duplicate(true)
        failure["success"] = false
        failure["reason"] = failure.get("reason", "consume_failed")
        return failure

    var before = health_system.get_health()
    var heal_report = health_system.apply_heal(heal_amount, source)
    var applied = float(heal_report.get("applied", 0.0))
    var after = float(heal_report.get("new_health", health_system.get_health()))

    return {
        "success": true,
        "item_id": item_id,
        "display_name": consume_report.get("display_name", inventory_system.get_item_display_name(item_id)),
        "quantity_used": quantity,
        "heal_requested": heal_amount,
        "heal_applied": applied,
        "health_before": before,
        "health_after": after,
        "quantity_remaining": consume_report.get("quantity_remaining", inventory_system.get_item_count(item_id))
    }

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

    var start_minutes = current_minutes
    var advance_report = time_system.advance_minutes(requested_minutes)
    if sleep_system:
        sleep_system.apply_awake_minutes(requested_minutes)
    if warmth_system:
        warmth_system.apply_environment_minutes(requested_minutes, start_minutes, false)

    _last_awake_minute_stamp = time_system.get_minutes_since_daybreak()

    var flashlight_report: Dictionary = {}
    if requested_minutes > 0:
        flashlight_report = _consume_flashlight_battery(requested_minutes)

    var result := {
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
    if !flashlight_report.is_empty():
        result["flashlight_status"] = flashlight_report
    return result

func _preview_activity_time(hours: float) -> Dictionary:
    var result := {
        "success": false,
        "reason": "systems_unavailable",
        "status": "unavailable",
        "requested_minutes": 0,
        "time_multiplier": 1.0
    }

    if time_system == null or sleep_system == null:
        return result

    hours = max(hours, 0.0)
    if is_zero_approx(hours):
        result["reason"] = "no_duration"
        result["status"] = "rejected"
        return result

    var multiplier = get_combined_activity_multiplier()
    multiplier = max(multiplier, 0.01)
    var requested_minutes = int(ceil(hours * 60.0 * multiplier))
    requested_minutes = max(requested_minutes, 1)
    var minutes_available = time_system.get_minutes_until_daybreak()

    result["time_multiplier"] = multiplier
    result["requested_minutes"] = requested_minutes
    result["minutes_available"] = minutes_available

    if requested_minutes > minutes_available:
        result["reason"] = "exceeds_day"
        result["status"] = "blocked"
        result["blocker"] = "daybreak"
        return result

    result["success"] = true
    result["reason"] = "ready"
    result["status"] = "ready"
    return result

func _compute_minutes_until_spawn(spawn_day: int, spawn_minute: int) -> int:
    if time_system == null:
        return -1
    var current_minutes = time_system.get_minutes_since_daybreak()
    var day_delta = spawn_day - current_day
    if day_delta < 0:
        return -1
    var total_minutes = spawn_minute - current_minutes
    if day_delta > 0:
        total_minutes += day_delta * TimeSystem.MINUTES_PER_DAY
    return total_minutes

func _update_lure_target_from_forecast(forecast: Dictionary):
    if typeof(forecast) != TYPE_DICTIONARY:
        _refresh_lure_status(true)
        return

    var events: Array = forecast.get("events", [])
    var candidate: Dictionary = {}
    for event in events:
        if typeof(event) != TYPE_DICTIONARY:
            continue
        if String(event.get("type", "")) != "scheduled_spawn":
            continue
        var spawns = int(event.get("spawns", event.get("quantity", 0)))
        if spawns <= 0:
            continue
        var minutes_ahead = int(event.get("minutes_ahead", LURE_WINDOW_MINUTES + 1))
        if minutes_ahead > LURE_WINDOW_MINUTES:
            continue
        candidate = event.duplicate(true)
        break

    if candidate.is_empty():
        if !_lure_target.is_empty():
            _clear_lure_target("forecast_clear")
        else:
            _refresh_lure_status(true)
        return

    var pending = zombie_system.get_pending_spawn() if zombie_system else {}
    if typeof(pending) != TYPE_DICTIONARY or pending.is_empty():
        _clear_lure_target("pending_missing")
        return

    var target_day = int(candidate.get("day", current_day))
    var target_minute = int(candidate.get("minute", -1))
    if int(pending.get("day", -1)) != target_day or int(pending.get("minute", -1)) != target_minute:
        _clear_lure_target("forecast_mismatch")
        return

    _lure_target = {
        "day": target_day,
        "minute": target_minute,
        "quantity": int(candidate.get("quantity", candidate.get("spawns", 0))),
        "source": "recon",
        "scouted_at_day": current_day,
        "scouted_at_minute": time_system.get_minutes_since_daybreak() if time_system else 0,
        "clock_time": String(candidate.get("clock_time", ""))
    }
    _refresh_lure_status(true)

func _clear_lure_target(_reason: String = ""):
    _lure_target = {}
    _refresh_lure_status(true)

func _refresh_lure_status(emit_signal: bool) -> Dictionary:
    var status := {
        "available": false,
        "status": "unavailable",
        "window_minutes": LURE_WINDOW_MINUTES,
        "calorie_cost": LURE_CALORIE_COST,
        "hours_required": LURE_DURATION_HOURS,
        "scouted": !_lure_target.is_empty()
    }

    var wolves_present = wolf_system != null and wolf_system.has_active_wolves()

    if time_system == null or sleep_system == null:
        status["reason"] = "systems_unavailable"
    else:
        var preview = _preview_activity_time(LURE_DURATION_HOURS)
        status["minutes_required"] = int(preview.get("requested_minutes", 0))
        status["time_multiplier"] = float(preview.get("time_multiplier", get_combined_activity_multiplier()))
        status["minutes_available"] = int(preview.get("minutes_available", time_system.get_minutes_until_daybreak()))

        if wolves_present:
            status["threat"] = "wolves"
            status["wolves_present"] = true
            status["scouted"] = true
            var wolf_state = wolf_system.get_state()
            status["wolf_state"] = wolf_state
            status["minutes_remaining"] = int(wolf_state.get("minutes_remaining", 0))
            status["clock_time"] = time_system.get_formatted_time()
            if preview.get("success", false):
                status["reason"] = "wolves_active"
                status["status"] = "wolves_ready"
                status["available"] = true
            else:
                status["reason"] = preview.get("reason", "time_rejected")
                status["status"] = preview.get("status", "blocked")
        elif zombie_system == null:
            status["reason"] = "systems_unavailable"
        else:
            if _lure_target.is_empty():
                status["reason"] = "no_target"
            else:
                var pending = zombie_system.get_pending_spawn()
                if typeof(pending) != TYPE_DICTIONARY or pending.is_empty():
                    status["reason"] = "pending_cleared"
                    status["scouted"] = false
                    _lure_target = {}
                else:
                    var target_day = int(_lure_target.get("day", -1))
                    var target_minute = int(_lure_target.get("minute", -1))
                    if int(pending.get("day", -1)) != target_day or int(pending.get("minute", -1)) != target_minute:
                        status["reason"] = "spawn_mismatch"
                        status["scouted"] = false
                        _lure_target = {}
                    else:
                        var quantity = int(pending.get("quantity", _lure_target.get("quantity", 0)))
                        if quantity <= 0:
                            status["reason"] = "no_quantity"
                            status["scouted"] = false
                            _lure_target = {}
                        else:
                            var minutes_remaining = _compute_minutes_until_spawn(target_day, target_minute)
                            status["minutes_remaining"] = minutes_remaining
                            status["clock_time"] = time_system.get_formatted_time_after(max(minutes_remaining, 0))
                            status["quantity"] = quantity
                            status["spawn_day"] = target_day
                            status["spawn_minute"] = target_minute
                            status["scouted_at_day"] = _lure_target.get("scouted_at_day", current_day)
                            status["scouted_at_minute"] = _lure_target.get("scouted_at_minute", 0)
                            status["source"] = _lure_target.get("source", "recon")
                            if minutes_remaining < 0:
                                status["reason"] = "expired"
                                status["scouted"] = false
                                _lure_target = {}
                            elif minutes_remaining > LURE_WINDOW_MINUTES:
                                status["reason"] = "outside_window"
                                status["status"] = "scouted"
                            elif !preview.get("success", false):
                                status["reason"] = preview.get("reason", "exceeds_day")
                                status["status"] = preview.get("status", "blocked")
                            else:
                                status["reason"] = "ready"
                                status["status"] = "ready"
                                status["available"] = true

    if status.get("reason", "") == "no_target" and !_lure_target.is_empty():
        status["scouted"] = true

    if status != _last_lure_status:
        _last_lure_status = status.duplicate(true)
        if emit_signal:
            lure_status_changed.emit(_last_lure_status.duplicate(true))
    elif emit_signal and _last_lure_status.is_empty():
        lure_status_changed.emit(status.duplicate(true))

    return _last_lure_status
