# TaskMenu.gd overview:
# - Purpose: queue survivor tasks (sleep, meals, repairs, forging, lead-away) and feed results back to systems.
# - Layout: outer panel splits info + assignments with a scroll container keeping action rows readable when the list grows.
# - Sections: exports tune UI ranges, preloads cache systems, onready grabs controls, handlers manage actions and feedback text.
extends Control

# Maximum hours the player can queue for sleep (keep within 4 - 16 for balance).
@export var max_sleep_hours: int = 12
@export var forging_results_panel_path: NodePath
@export var action_popup_path: NodePath

const SLEEP_PERCENT_PER_HOUR: int = 10
const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const WeatherSystem = preload("res://scripts/systems/WeatherSystem.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const TowerHealthSystem = preload("res://scripts/systems/TowerHealthSystem.gd")
const ZombieSystem = preload("res://scripts/systems/ZombieSystem.gd")
const ForgingResultsPanel = preload("res://scripts/ui/ForgingResultsPanel.gd")
const ActionPopupPanel = preload("res://scripts/ui/ActionPopupPanel.gd")

const CALORIES_PER_FOOD_UNIT: float = 1000.0
const LEAD_AWAY_CHANCE_PERCENT: int = int(round(ZombieSystem.DEFAULT_LEAD_AWAY_CHANCE * 100.0))
const RECON_OUTLOOK_HOURS: int = 6
const LURE_WINDOW_MINUTES: int = GameManager.LURE_WINDOW_MINUTES
const LURE_CALORIE_COST: float = GameManager.LURE_CALORIE_COST
const LURE_DURATION_HOURS: float = GameManager.LURE_DURATION_HOURS
const WOLF_ATTACK_CHANCE_PERCENT: int = int(round(GameManager.WOLF_ATTACK_CHANCE * 100.0))
const WOLF_LURE_SUCCESS_PERCENT: int = int(round(GameManager.WOLF_LURE_SUCCESS_CHANCE * 100.0))
const FIGHT_BACK_HOURS: float = GameManager.FIGHT_BACK_HOURS
const FIGHT_BACK_REST_COST_PERCENT: float = GameManager.FIGHT_BACK_REST_COST_PERCENT
const FIGHT_BACK_CALORIE_COST: float = GameManager.FIGHT_BACK_CALORIE_COST
const FISHING_ROLLS_PER_HOUR: int = GameManager.FISHING_ROLLS_PER_HOUR
const FISHING_SUCCESS_CHANCE: float = GameManager.FISHING_ROLL_SUCCESS_CHANCE
const FISHING_SUCCESS_PERCENT: int = int(round(FISHING_SUCCESS_CHANCE * 100.0))
const FISHING_REST_COST_PERCENT: float = GameManager.FISHING_REST_COST_PERCENT
const FISHING_CALORIE_COST: float = GameManager.FISHING_CALORIE_COST
const FISHING_GRUB_LOSS_CHANCE: float = GameManager.FISHING_GRUB_LOSS_CHANCE
const FISHING_GRUB_LOSS_PERCENT: int = int(round(FISHING_GRUB_LOSS_CHANCE * 100.0))
const FISHING_SIZE_TABLE := GameManager.FISHING_SIZE_TABLE
const FORGING_REST_COST_PERCENT: float = GameManager.FORGING_REST_COST_PERCENT
const FORGING_CALORIE_COST: float = GameManager.FORGING_CALORIE_COST
const CAMP_SEARCH_HOURS: float = GameManager.CAMP_SEARCH_HOURS
const CAMP_SEARCH_REST_COST_PERCENT: float = GameManager.CAMP_SEARCH_REST_COST_PERCENT
const CAMP_SEARCH_CALORIE_COST: float = GameManager.CAMP_SEARCH_CALORIE_COST
const HUNT_HOURS: float = GameManager.HUNT_HOURS
const HUNT_REST_COST_PERCENT: float = GameManager.HUNT_REST_COST_PERCENT
const HUNT_CALORIE_COST: float = GameManager.HUNT_CALORIE_COST
const HUNT_ROLLS_PER_TRIP: int = GameManager.HUNT_ROLLS_PER_TRIP
const HUNT_ARROW_BREAK_PERCENT: int = int(round(GameManager.HUNT_ARROW_BREAK_CHANCE * 100.0))
const BUTCHER_HOURS: float = GameManager.BUTCHER_HOURS
const BUTCHER_REST_COST_PERCENT: float = GameManager.BUTCHER_REST_COST_PERCENT
const BUTCHER_CALORIE_COST: float = GameManager.BUTCHER_CALORIE_COST
const COOK_WHOLE_HOURS: float = GameManager.COOK_WHOLE_HOURS
const COOK_WHOLE_REST_COST_PERCENT: float = GameManager.COOK_WHOLE_REST_COST_PERCENT
const COOK_WHOLE_CALORIE_COST: float = GameManager.COOK_WHOLE_CALORIE_COST
const TRAP_CALORIE_COST: float = GameManager.TRAP_CALORIE_COST
const TRAP_ENERGY_COST_PERCENT: float = GameManager.TRAP_REST_COST_PERCENT
const TRAP_BREAK_PERCENT: int = int(round(GameManager.TRAP_BREAK_CHANCE * 100.0))
const TRAP_DEPLOY_HOURS: float = GameManager.TRAP_DEPLOY_HOURS
const TRAP_ITEM_ID := GameManager.TRAP_ITEM_ID
const SNARE_ITEM_ID := GameManager.SNARE_ITEM_ID
const SNARE_PLACE_HOURS: float = GameManager.SNARE_PLACE_HOURS
const SNARE_PLACE_REST_COST_PERCENT: float = GameManager.SNARE_PLACE_REST_COST_PERCENT
const SNARE_PLACE_CALORIE_COST: float = GameManager.SNARE_PLACE_CALORIE_COST
const SNARE_CHECK_HOURS: float = GameManager.SNARE_CHECK_HOURS
const SNARE_CHECK_REST_COST_PERCENT: float = GameManager.SNARE_CHECK_REST_COST_PERCENT
const SNARE_CHECK_CALORIE_COST: float = GameManager.SNARE_CHECK_CALORIE_COST
const SNARE_CATCH_PERCENT: int = int(round(GameManager.SNARE_CATCH_CHANCE * 100.0))
const FISHING_SIZE_LABELS := {
    "small": "Small",
    "medium": "Medium",
    "large": "Large"
}

# Meal presets surfaced to the menu; food_units mirror GameManager expectations.
const MEAL_OPTIONS := [
    {
        "key": "small",
        "label": "Small (0.5)",
        "display": "Small",
        "food_units": 0.5
    },
    {
        "key": "normal",
        "label": "Normal (1.0)",
        "display": "Normal",
        "food_units": 1.0
    },
    {
        "key": "large",
        "label": "Large (1.5)",
        "display": "Large",
        "food_units": 1.5
    }
]

var selected_hours: int = 0
var time_system: TimeSystem

var _cached_minutes_remaining: int = 0
var _menu_open: bool = false
var inventory_system: InventorySystem
var tower_health_system: TowerHealthSystem
var zombie_system: ZombieSystem
var weather_system: WeatherSystem
var selected_meal_key: String = "normal"
var _forging_feedback_state: String = "ready"
var _forging_feedback_locked: bool = false
var _lead_feedback_state: String = "status"
var _lead_feedback_locked: bool = false
var _lure_status: Dictionary = {}
var _wolf_state: Dictionary = {}

var _selected_action: String = "sleep"
var _action_status_text: Dictionary = {}
var _action_defaults: Dictionary = {}
var _action_results_active: Dictionary = {}
var _action_buttons: Dictionary = {}
var _trap_state: Dictionary = {}
var _snare_state: Dictionary = {}

# Grab nodes and buttons once so focus behavior remains consistent.
@onready var game_manager: GameManager = _resolve_game_manager()
@onready var hours_value_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepControls/HourSelector/HoursValue
@onready var decrease_sleep_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepControls/HourSelector/DecreaseButton
@onready var increase_sleep_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepControls/HourSelector/IncreaseButton
@onready var sleep_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepHeader/SleepSummary
@onready var info_title_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/DescriptionTitle
@onready var info_body_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/SummaryLabel
@onready var info_status_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/InfoStatus
@onready var info_hint_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/DescriptionHint
@onready var info_energy_value_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/InfoStats/EnergyRow/EnergyValue
@onready var info_calorie_value_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/InfoStats/CalorieRow/CalorieValue
@onready var go_button: Button = $Layout/InfoPanel/InfoMargin/InfoList/GoRow/GoButton
@onready var forging_results_panel: ForgingResultsPanel = get_node_or_null(forging_results_panel_path) if forging_results_panel_path != NodePath("") else null
@onready var action_popup_panel: ActionPopupPanel = get_node_or_null(action_popup_path) if action_popup_path != NodePath("") else null
@onready var meal_size_option: OptionButton = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/MealRow/MealControls/MealSizeOption
@onready var meal_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/MealRow/MealText/MealSummary
@onready var repair_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/RepairRow/RepairText/RepairSummary
@onready var forging_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/ForgingRow/ForgingText/ForgingSummary
@onready var camp_search_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/CampSearchRow/CampSearchText/CampSearchSummary
@onready var hunt_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/HuntRow/HuntText/HuntSummary
@onready var lead_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/LeadRow/LeadText/LeadSummary
@onready var reinforce_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReinforceRow/ReinforceText/ReinforceSummary
@onready var sleep_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepControls/SleepSelectButton
@onready var forging_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/ForgingRow/ForgingSelectButton
@onready var camp_search_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/CampSearchRow/CampSearchSelectButton
@onready var hunt_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/HuntRow/HuntSelectButton
@onready var fishing_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/FishingRow/FishingText/FishingSummary
@onready var fishing_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/FishingRow/FishingSelectButton
@onready var recon_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReconRow/ReconText/ReconSummary
@onready var recon_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReconRow/ReconSelectButton
@onready var lead_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/LeadRow/LeadSelectButton
@onready var fight_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/FightRow/FightText/FightSummary
@onready var fight_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/FightRow/FightSelectButton
@onready var meal_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/MealRow/MealControls/MealSelectButton
@onready var repair_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/RepairRow/RepairSelectButton
@onready var reinforce_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReinforceRow/ReinforceSelectButton
@onready var trap_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/TrapRow/TrapText/TrapSummary
@onready var trap_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/TrapRow/TrapSelectButton
@onready var snare_place_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnarePlaceRow/SnarePlaceText/SnarePlaceSummary
@onready var snare_place_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnarePlaceRow/SnarePlaceSelectButton
@onready var snare_check_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnareCheckRow/SnareCheckText/SnareCheckSummary
@onready var snare_check_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnareCheckRow/SnareCheckSelectButton
@onready var butcher_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/ButcherRow/ButcherText/ButcherSummary
@onready var butcher_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/ButcherRow/ButcherSelectButton
@onready var cook_whole_summary_label: Label = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/CookWholeRow/CookWholeText/CookWholeSummary
@onready var cook_whole_select_button: Button = $Layout/ActionsPanel/Margin/ActionScroll/ActionList/CookWholeRow/CookWholeSelectButton

const DESCRIPTION_DEFAULT := {
    "title": "Task Details",
    "hint": "Hover or focus an action to see its requirements."
}

const TASK_DESCRIPTION_META := {
    "sleep": {
        "title": "Rest",
        "hint": "Spend time to recover rest and calories."
    },
    "forging": {
        "title": "Forge",
        "hint": "Search the forest for supplies."
    },
    "camp_search": {
        "title": "Search Campground",
        "hint": "Sweep abandoned campsites for bulk supplies."
    },
    "hunt": {
        "title": "Hunt",
        "hint": "Spend arrows to chase game for food."
    },
    "fishing": {
        "title": "Fish",
        "hint": "Cast bait for fresh meals."
    },
    "recon": {
        "title": "Recon",
        "hint": "Scout weather and undead approach windows."
    },
    "lead": {
        "title": "Lead Away",
        "hint": "Draw undead from the tower."
    },
    "fight_back": {
        "title": "Fight Back",
        "hint": "Charge outside to drive off wolves or clear nearby undead."
    },
    "trap": {
        "title": "Place Trap",
        "hint": "Arm a trap to intercept the next zombie."
    },
    "snare_place": {
        "title": "Place Animal Snare",
        "hint": "Deploy a crafted snare to hunt small game."
    },
    "snare_check": {
        "title": "Check Snare",
        "hint": "Inspect deployed snares for trapped animals."
    },
    "meal": {
        "title": "Eat",
        "hint": "Convert stored food into calories."
    },
    "repair": {
        "title": "Repair",
        "hint": "Spend wood to restore tower health."
    },
    "reinforce": {
        "title": "Reinforce",
        "hint": "Fortify the tower past its base strength."
    },
    "butcher": {
        "title": "Butcher & Cook",
        "hint": "Process fresh game over a lit fire for bonus food."
    },
    "cook_whole": {
        "title": "Cook Animals Whole",
        "hint": "Slow-roast stored game without knife bonuses."
    }
}

func _ready():
    # Prepare button callbacks and sync default descriptions before showing the menu.
    set_process_input(true)
    set_process_unhandled_input(true)
    _close_menu()

    if is_instance_valid(info_title_label):
        info_title_label.text = DESCRIPTION_DEFAULT.get("title", "Task Details")
    if is_instance_valid(info_hint_label):
        info_hint_label.text = DESCRIPTION_DEFAULT.get("hint", "Hover or focus an action to see its requirements.")
    if is_instance_valid(info_status_label):
        info_status_label.text = ""

    if go_button:
        go_button.pressed.connect(_on_go_button_pressed)
    if decrease_sleep_button:
        decrease_sleep_button.pressed.connect(_on_decrease_button_pressed)
    if increase_sleep_button:
        increase_sleep_button.pressed.connect(_on_increase_button_pressed)

    _register_action_selector(sleep_select_button, "sleep")
    _register_action_selector(forging_select_button, "forging")
    _register_action_selector(camp_search_select_button, "camp_search")
    _register_action_selector(hunt_select_button, "hunt")
    _register_action_selector(fishing_select_button, "fishing")
    _register_action_selector(recon_select_button, "recon")
    _register_action_selector(lead_select_button, "lead")
    _register_action_selector(fight_select_button, "fight_back")
    _register_action_selector(trap_select_button, "trap")
    _register_action_selector(snare_place_select_button, "snare_place")
    _register_action_selector(snare_check_select_button, "snare_check")
    _register_action_selector(meal_select_button, "meal")
    _register_action_selector(repair_select_button, "repair")
    _register_action_selector(reinforce_select_button, "reinforce")
    _register_action_selector(butcher_select_button, "butcher")
    _register_action_selector(cook_whole_select_button, "cook_whole")

    if game_manager:
        time_system = game_manager.get_time_system()
        inventory_system = game_manager.get_inventory_system()
        tower_health_system = game_manager.get_tower_health_system()
        weather_system = game_manager.get_weather_system()
        if game_manager.has_signal("trap_state_changed"):
            game_manager.trap_state_changed.connect(_on_trap_state_changed)
        _trap_state = game_manager.get_trap_state()
        if game_manager.has_signal("snare_state_changed"):
            game_manager.snare_state_changed.connect(_on_snare_state_changed)
        _snare_state = game_manager.get_snare_state()
        if game_manager.has_signal("hunt_stock_changed"):
            game_manager.hunt_stock_changed.connect(_on_hunt_stock_changed)
        if game_manager.has_signal("wood_stove_state_changed"):
            game_manager.wood_stove_state_changed.connect(_on_wood_stove_state_changed)
        if time_system:
            time_system.time_advanced.connect(_on_time_system_changed)
            time_system.day_rolled_over.connect(_on_time_system_changed)
        if inventory_system:
            inventory_system.food_total_changed.connect(_on_inventory_food_total_changed)
            inventory_system.item_added.connect(_on_inventory_item_changed)
            inventory_system.item_consumed.connect(_on_inventory_item_changed)
            _set_forging_feedback(_format_forging_ready(inventory_system.get_total_food_units()), "ready")
        else:
            _set_forging_feedback("Forging offline", "offline")
        if tower_health_system:
            tower_health_system.tower_health_changed.connect(_on_tower_health_changed)
        zombie_system = game_manager.get_zombie_system()
        if zombie_system:
            zombie_system.zombies_changed.connect(_on_lead_zombie_count_changed)
            _set_lead_feedback(_format_lead_ready(zombie_system.get_active_zombies()), "status")
        else:
            _set_lead_feedback("Lead Away offline", "offline")
        if game_manager.has_signal("wolf_state_changed"):
            game_manager.wolf_state_changed.connect(_on_wolf_state_changed)
            _wolf_state = game_manager.get_wolf_state()
        else:
            _wolf_state = {}
        if game_manager.has_signal("lure_status_changed"):
            game_manager.lure_status_changed.connect(_on_lure_status_changed)
            _lure_status = game_manager.get_lure_status()
            _refresh_lead_feedback()
    else:
        _set_forging_feedback("Forging unavailable", "offline")
        _set_lead_feedback("Lead Away unavailable", "offline")

    _setup_meal_size_options()
    _setup_description_targets()
    _select_action("sleep", true)
    _update_fight_summary()
    _refresh_display()

    if forging_results_panel == null:
        var tree = get_tree()
        if tree:
            var root = tree.get_root()
            if root:
                var candidate: Node = root.get_node_or_null("Main/UI/ForgingResultsPanel")
                if candidate is ForgingResultsPanel:
                    forging_results_panel = candidate
    if action_popup_panel == null:
        var popup_tree = get_tree()
        if popup_tree:
            var popup_root = popup_tree.get_root()
            if popup_root:
                var popup_candidate: Node = popup_root.get_node_or_null("Main/UI/ActionPopupPanel")
                if popup_candidate is ActionPopupPanel:
                    action_popup_panel = popup_candidate

func _input(event):
    _handle_menu_input(event)

func _unhandled_input(event):
    _handle_menu_input(event)

func _handle_menu_input(event):
    # Toggle the task overlay or close it with escape-style actions.
    if event.is_action_pressed("action_menu") and !event.is_echo():
        if visible:
            _close_menu()
        else:
            _open_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("ui_cancel") and visible and !event.is_echo():
        _close_menu()
        get_viewport().set_input_as_handled()

func _refresh_display():
    # Recalculate limits and UI summaries whenever time, inventory, or selection changes.
    _cached_minutes_remaining = _get_minutes_left_today()
    var hours_available = _get_sleep_hours_available()
    if selected_hours > hours_available:
        selected_hours = max(hours_available, 0)
    if is_instance_valid(hours_value_label):
        hours_value_label.text = str(selected_hours)

    _update_sleep_summary()
    _update_camp_search_summary()
    _update_hunt_summary()
    _update_meal_summary()
    _update_fishing_summary()
    _update_recon_summary()
    _update_fight_summary()
    _update_repair_summary()
    _update_reinforce_summary()
    _update_trap_summary()
    _update_snare_place_summary()
    _update_snare_check_summary()
    _update_butcher_summary()
    _update_cook_whole_summary()
    _update_description_body()
    _update_info_status()
    _update_info_stats()

func _get_sleep_hours_available() -> int:
    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes_remaining = max(_get_minutes_left_today(), 0)
    var hours_available = int(ceil(minutes_remaining / (60.0 * multiplier))) if minutes_remaining > 0 else 0
    return min(max_sleep_hours, max(hours_available, 0))

func _setup_description_targets():
    var paths := {
        "sleep": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepHeader/SleepLabel",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepHeader/SleepSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepControls",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepControls/HourSelector",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepControls/HourSelector/DecreaseButton",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepControls/HourSelector/IncreaseButton",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SleepRow/SleepControls/SleepSelectButton"
        ],
        "forging": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ForgingRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ForgingRow/ForgingText/ForgingSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ForgingRow/ForgingSelectButton"
        ],
        "camp_search": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/CampSearchRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/CampSearchRow/CampSearchText/CampSearchSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/CampSearchRow/CampSearchSelectButton"
        ],
        "hunt": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/HuntRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/HuntRow/HuntText/HuntSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/HuntRow/HuntSelectButton"
        ],
        "fishing": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/FishingRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/FishingRow/FishingText/FishingSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/FishingRow/FishingSelectButton"
        ],
        "recon": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReconRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReconRow/ReconText/ReconSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReconRow/ReconSelectButton"
        ],
        "lead": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/LeadRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/LeadRow/LeadText/LeadSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/LeadRow/LeadSelectButton"
        ],
        "fight_back": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/FightRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/FightRow/FightText/FightSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/FightRow/FightSelectButton"
        ],
        "meal": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/MealRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/MealRow/MealText/MealSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/MealRow/MealControls/MealSizeOption",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/MealRow/MealControls/MealSelectButton"
        ],
        "trap": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/TrapRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/TrapRow/TrapText/TrapSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/TrapRow/TrapSelectButton"
        ],
        "snare_place": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnarePlaceRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnarePlaceRow/SnarePlaceText/SnarePlaceSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnarePlaceRow/SnarePlaceSelectButton"
        ],
        "snare_check": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnareCheckRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnareCheckRow/SnareCheckText/SnareCheckSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/SnareCheckRow/SnareCheckSelectButton"
        ],
        "butcher": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ButcherRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ButcherRow/ButcherText/ButcherSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ButcherRow/ButcherSelectButton"
        ],
        "cook_whole": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/CookWholeRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/CookWholeRow/CookWholeText/CookWholeSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/CookWholeRow/CookWholeSelectButton"
        ],
        "repair": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/RepairRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/RepairRow/RepairText/RepairSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/RepairRow/RepairSelectButton"
        ],
        "reinforce": [
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReinforceRow",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReinforceRow/ReinforceText/ReinforceSummary",
            "Layout/ActionsPanel/Margin/ActionScroll/ActionList/ReinforceRow/ReinforceSelectButton"
        ]
    }

    for key in paths.keys():
        for path in paths[key]:
            var node = get_node_or_null(path)
            if node and node is Control:
                _register_description_target(node, key)

func _register_description_target(control: Control, key: String):
    if control == null:
        return
    if control.has_signal("mouse_entered"):
        control.mouse_entered.connect(func(): _set_description(key))
    if control.has_signal("focus_entered"):
        control.focus_entered.connect(func(): _set_description(key))

func _set_description(key: String, force: bool = false):
    _select_action(key, force)

func _update_description_body():
    if !is_instance_valid(info_body_label):
        return
    info_body_label.text = _get_description_body(_selected_action)

func _get_description_body(key: String) -> String:
    match key:
        "sleep":
            return _build_sleep_description()
        "forging":
            return _build_forging_description()
        "camp_search":
            return _build_camp_search_description()
        "hunt":
            return _build_hunt_description()
        "fishing":
            return _build_fishing_description()
        "recon":
            return _build_recon_description()
        "lead":
            return _build_lead_description()
        "fight_back":
            return _build_fight_description()
        "trap":
            return _build_trap_description()
        "snare_place":
            return _build_snare_place_description()
        "snare_check":
            return _build_snare_check_description()
        "meal":
            return _build_meal_description()
        "repair":
            return _build_repair_description()
        "reinforce":
            return _build_reinforce_description()
        "butcher":
            return _build_butcher_description()
        "cook_whole":
            return _build_cook_whole_description()
        _:
            return "Select an action to learn more."
func _select_action(key: String, force: bool = false):
    if key.is_empty():
        key = _selected_action
    if !TASK_DESCRIPTION_META.has(key):
        key = "sleep"
    var changed = force or key != _selected_action
    _selected_action = key
    var meta = TASK_DESCRIPTION_META.get(key, DESCRIPTION_DEFAULT)
    if is_instance_valid(info_title_label):
        info_title_label.text = meta.get("title", DESCRIPTION_DEFAULT.get("title", "Task Details"))
    if is_instance_valid(info_hint_label):
        info_hint_label.text = meta.get("hint", DESCRIPTION_DEFAULT.get("hint", "Hover or focus an action to see its requirements."))
    _update_description_body()
    _update_info_status()
    _update_info_stats()
    if changed or force:
        _update_action_highlights()

func _register_action_selector(button: BaseButton, action: String):
    if button == null:
        return
    button.toggle_mode = true
    button.button_pressed = action == _selected_action
    button.pressed.connect(func():
        _handle_action_button_press(action)
    )
    _action_buttons[action] = button

func _update_action_highlights():
    for key in _action_buttons.keys():
        var button: BaseButton = _action_buttons[key]
        if button and is_instance_valid(button):
            button.button_pressed = key == _selected_action

func _handle_action_button_press(action: String):
    # Sleep stays queued for hour adjustments; every other button executes immediately.
    _select_action(action, true)
    if action == "sleep":
        if is_instance_valid(sleep_select_button):
            sleep_select_button.button_pressed = true
        return

    _trigger_selected_action()
    _select_action(action, true)

func _update_info_status():
    if !is_instance_valid(info_status_label):
        return
    var text = _action_status_text.get(_selected_action, "")
    info_status_label.text = text
    info_status_label.visible = !text.is_empty()

func _update_info_stats():
    if !is_instance_valid(info_energy_value_label) or !is_instance_valid(info_calorie_value_label):
        return
    info_energy_value_label.text = _get_action_energy_text(_selected_action)
    info_calorie_value_label.text = _get_action_calorie_text(_selected_action)

func _refresh_info_stats_if_selected(action: String):
    if _selected_action == action:
        _update_info_stats()

func _set_action_status(action: String, text: String, update_row: bool = false):
    _action_status_text[action] = text
    if update_row:
        match action:
            "sleep":
                if is_instance_valid(sleep_summary_label):
                    sleep_summary_label.text = text
            "forging":
                if is_instance_valid(forging_summary_label):
                    forging_summary_label.text = text
            "camp_search":
                if is_instance_valid(camp_search_summary_label):
                    camp_search_summary_label.text = text
            "hunt":
                if is_instance_valid(hunt_summary_label):
                    hunt_summary_label.text = text
            "fishing":
                if is_instance_valid(fishing_summary_label):
                    fishing_summary_label.text = text
            "recon":
                if is_instance_valid(recon_summary_label):
                    recon_summary_label.text = text
            "lead":
                if is_instance_valid(lead_summary_label):
                    lead_summary_label.text = text
            "fight_back":
                if is_instance_valid(fight_summary_label):
                    fight_summary_label.text = text
            "trap":
                if is_instance_valid(trap_summary_label):
                    trap_summary_label.text = text
            "snare_place":
                if is_instance_valid(snare_place_summary_label):
                    snare_place_summary_label.text = text
            "snare_check":
                if is_instance_valid(snare_check_summary_label):
                    snare_check_summary_label.text = text
            "meal":
                if is_instance_valid(meal_summary_label):
                    meal_summary_label.text = text
            "repair":
                if is_instance_valid(repair_summary_label):
                    repair_summary_label.text = text
            "reinforce":
                if is_instance_valid(reinforce_summary_label):
                    reinforce_summary_label.text = text
            "butcher":
                if is_instance_valid(butcher_summary_label):
                    butcher_summary_label.text = text
            "cook_whole":
                if is_instance_valid(cook_whole_summary_label):
                    cook_whole_summary_label.text = text
    if action == _selected_action:
        _update_info_status()
    _refresh_info_stats_if_selected(action)

func _set_action_default(action: String, text: String, update_row: bool = false):
    _action_defaults[action] = text
    if !_action_results_active.get(action, false):
        _set_action_status(action, text, update_row)
    _refresh_info_stats_if_selected(action)

func _set_action_result(action: String, text: String, update_row: bool = false):
    var active = !text.is_empty()
    _action_results_active[action] = active
    if active:
        _set_action_status(action, text, update_row)
    else:
        _set_action_status(action, _action_defaults.get(action, ""), update_row)

func _trigger_selected_action():
    match _selected_action:
        "sleep":
            _execute_sleep_action()
        "forging":
            _execute_forging_action()
        "camp_search":
            _execute_camp_search_action()
        "hunt":
            _execute_hunt_action()
        "fishing":
            _execute_fishing_action()
        "recon":
            _execute_recon_action()
        "lead":
            _execute_lead_action()
        "fight_back":
            _execute_fight_action()
        "trap":
            _execute_trap_action()
        "snare_place":
            _execute_snare_place_action()
        "snare_check":
            _execute_snare_check_action()
        "meal":
            _execute_meal_action()
        "repair":
            _execute_repair_action()
        "reinforce":
            _execute_reinforce_action()
        "butcher":
            _execute_butcher_action()
        "cook_whole":
            _execute_cook_whole_action()

func _on_go_button_pressed():
    _trigger_selected_action()


func _build_sleep_description() -> String:
    var lines: PackedStringArray = []
    lines.append("Each hour: +%d%% rest / -%d cal" % [SLEEP_PERCENT_PER_HOUR, SleepSystem.CALORIES_PER_SLEEP_HOUR])
    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes_remaining = _get_minutes_left_today()
    if selected_hours > 0:
        var planned_minutes = int(ceil(selected_hours * 60.0 * multiplier))
        var minutes_available = max(minutes_remaining, 0)
        var minutes_applied = min(planned_minutes, minutes_available)
        lines.append("%d hr queued -> uses %s (x%.1f)" % [
            selected_hours,
            _format_duration(planned_minutes),
            multiplier
        ])
        if minutes_applied > 0:
            var applied_hours = float(minutes_applied) / (60.0 * multiplier)
            var rest_gain = applied_hours * float(SLEEP_PERCENT_PER_HOUR)
            var calories = applied_hours * SleepSystem.CALORIES_PER_SLEEP_HOUR
            lines.append("Usable %s -> +%s%% / -%d cal" % [
                _format_hours_value(applied_hours),
                _format_percent_value(rest_gain),
                int(round(calories))
            ])
            if minutes_applied < planned_minutes:
                var trimmed = planned_minutes - minutes_applied
                if trimmed > 0:
                    lines.append("Dawn trims %s" % _format_duration(trimmed))
            if time_system:
                lines.append("Ends at %s" % time_system.get_formatted_time_after(minutes_applied))
        else:
            lines.append("No time before dawn")
    else:
        if minutes_remaining > 0:
            var fractional_hours = minutes_remaining / (60.0 * multiplier)
            var rest_gain_partial = fractional_hours * SLEEP_PERCENT_PER_HOUR
            var calories_partial = fractional_hours * SleepSystem.CALORIES_PER_SLEEP_HOUR
            lines.append("Rest to 6:00 -> +%s%% / -%d cal" % [_format_percent_value(rest_gain_partial), int(round(calories_partial))])
            lines.append("Uses %s (%.2f hr @ x%.1f)" % [_format_duration(minutes_remaining), fractional_hours, multiplier])
        else:
            lines.append("No time left before 6:00 AM.")
    lines.append("Day left: %s" % _format_duration(minutes_remaining))
    return "\n".join(lines)

func _build_forging_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Spend 1 hr (x%.1f) sweeping the woods." % multiplier)
    lines.append("Energy -%s%% | +%d cal burn" % [_format_percent_value(FORGING_REST_COST_PERCENT), int(round(FORGING_CALORIE_COST))])
    lines.append("Food finds: Mushrooms 25%% / Berries 25%% / Walnuts 25%% / Grubs 20%% / Apples 20%% / Oranges 20%% / Raspberries 20%% / Blueberries 20%%")
    lines.append("Advanced finds (10%%): Plastic Sheet, Metal Scrap, Nails x3, Duct Tape, Medicinal Herbs, Fuel (3-5), Mechanical Parts, Electrical Parts")
    lines.append("Takes %s" % _format_duration(minutes))
    if zombie_system and zombie_system.has_active_zombies():
        lines.append("Blocked: %d undead nearby" % zombie_system.get_active_zombies())
    else:
        lines.append("Ready while the area is clear")
    return "\n".join(lines)

func _build_camp_search_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(CAMP_SEARCH_HOURS * 60.0 * multiplier))
    lines.append("Spend %dh (x%.1f) sweeping old camps." % [int(round(CAMP_SEARCH_HOURS)), multiplier])
    lines.append("Energy -%s%% | +%d cal burn" % [_format_percent_value(CAMP_SEARCH_REST_COST_PERCENT), int(round(CAMP_SEARCH_CALORIE_COST))])
    lines.append("Basics 10%% each: Mushrooms, Berries, Apples, Oranges, Raspberries, Blueberries, Walnuts, Grubs")
    lines.append("Textiles 40%% Ripped Cloth | Wood 25%% | Feathers 50%% | Canned Food 15%% | Nails Pack 20%%")
    lines.append("Advanced 25%% (2x): Plastic Sheet, Metal Scrap, Nails x3, Duct Tape, Medicinal Herbs, Mechanical Parts, Electrical Parts | Fuel 3-5")
    var capacity = game_manager.get_carry_capacity() if game_manager else InventorySystem.DEFAULT_CARRY_CAPACITY
    lines.append("Carry %d slots (Backpack raises to 12)" % max(capacity, 0))
    lines.append("Takes %s" % _format_duration(minutes))
    if zombie_system and zombie_system.has_active_zombies():
        lines.append("Blocked: %d undead nearby" % zombie_system.get_active_zombies())
    else:
        lines.append("Ready while the area is clear")
    return "\n".join(lines)

func _build_hunt_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(HUNT_HOURS * 60.0 * multiplier))
    lines.append("Spend %dh (x%.1f) stalking nearby trails." % [int(round(HUNT_HOURS)), multiplier])
    lines.append("Energy -%s%% | +%d cal burn" % [_format_percent_value(HUNT_REST_COST_PERCENT), int(round(HUNT_CALORIE_COST))])
    lines.append("Up to %d shots | %d%% chance arrow breaks each shot" % [HUNT_ROLLS_PER_TRIP, HUNT_ARROW_BREAK_PERCENT])
    lines.append("Requires Bow + ≥1 Arrow (recovered unless the shaft breaks)")
    if game_manager:
        var animals: Array = game_manager.get_hunt_animals()
        if !animals.is_empty():
            var entries: PackedStringArray = []
            for entry in animals:
                if typeof(entry) != TYPE_DICTIONARY:
                    continue
                var label = String(entry.get("label", entry.get("id", "Game")))
                var chance = float(entry.get("chance", 0.0))
                var food_units = float(entry.get("food_units", 0.0))
                entries.append("%d%% %s (%.1f food)" % [int(round(chance * 100.0)), label, food_units])
            if !entries.is_empty():
                lines.append("Game table: %s" % ", ".join(entries))
        var status = game_manager.get_hunt_status()
        var bow_stock = int(status.get("bow_stock", 0))
        var arrow_stock = int(status.get("arrow_stock", 0))
        lines.append("Bow stock: %d | Arrows: %d" % [bow_stock, arrow_stock])
        var pending_stock: Dictionary = status.get("pending_stock", {})
        if typeof(pending_stock) == TYPE_DICTIONARY:
            var pending_total = float(pending_stock.get("total_food_units", 0.0))
            lines.append("Stored game: %.1f food (Cook Whole = base | Butcher = +25%%)" % pending_total)
    if zombie_system and zombie_system.has_active_zombies():
        lines.append("Blocked: %d undead nearby" % zombie_system.get_active_zombies())
    else:
        lines.append("Ready while the area is clear")
    lines.append("Takes %s" % _format_duration(minutes))
    return "\n".join(lines)

func _build_fishing_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Spend 1 hr (x%.1f) casting from shore." % multiplier)
    lines.append("Energy -%d%% | +%d cal burn" % [int(round(FISHING_REST_COST_PERCENT)), int(round(FISHING_CALORIE_COST))])
    lines.append("%d rolls @ %d%% each | Sizes: Small 50%% (0.5), Medium 35%% (1.0), Large 15%% (1.5)" % [FISHING_ROLLS_PER_HOUR, FISHING_SUCCESS_PERCENT])
    lines.append("Needs Fishing Rod + Grub (%d%% loss chance)" % FISHING_GRUB_LOSS_PERCENT)
    if inventory_system:
        lines.append("Rod stock: %d" % inventory_system.get_item_count("fishing_rod"))
        lines.append("Grubs: %d" % inventory_system.get_item_count("grubs"))
    else:
        lines.append("Inventory offline")
    if time_system and minutes > 0 and minutes <= _get_minutes_left_today():
        lines.append("Ends at %s" % time_system.get_formatted_time_after(minutes))
    lines.append("Day left: %s" % _format_duration(_get_minutes_left_today()))
    return "\n".join(lines)

func _build_recon_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Spend 1 hr (x%.1f) reviewing maps and radio logs." % multiplier)
    lines.append("Costs %d cal | Forecast next %d hr of rain and undead." % [int(round(GameManager.RECON_CALORIE_COST)), RECON_OUTLOOK_HOURS])
    var minutes_remaining = _get_minutes_left_today()
    if time_system and minutes > 0 and minutes <= minutes_remaining:
        lines.append("Ends at %s" % time_system.get_formatted_time_after(minutes))
    var window_minutes = RECON_OUTLOOK_HOURS * 60
    if minutes_remaining <= window_minutes:
        lines.append("Includes dawn check in %s" % _format_duration(minutes_remaining))
    else:
        lines.append("Next dawn beyond outlook (%s)" % _format_duration(window_minutes))
    lines.append("Day left: %s" % _format_duration(minutes_remaining))
    return "\n".join(lines)

func _build_lead_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var lead_minutes = int(ceil(60.0 * multiplier))
    lines.append("Spend 1 hr (x%.1f) scouting a diversion route." % multiplier)
    lines.append("Energy -15%% | %d%% success per 🧟" % LEAD_AWAY_CHANCE_PERCENT)
    lines.append("Action time: %s" % _format_duration(lead_minutes))
    if zombie_system:
        var count = zombie_system.get_active_zombies()
        if count > 0:
            lines.append("Active undead: %d" % count)
        else:
            lines.append("Needs at least 1 undead present")
    var lure_minutes = int(ceil(LURE_DURATION_HOURS * 60.0 * multiplier))
    lines.append("Patrol covers %dh; waves must be ≤%dh out to divert." % [int(round(LURE_DURATION_HOURS)), int(round(LURE_WINDOW_MINUTES / 60.0))])
    lines.append("Costs %d cal | Patrol runtime %s when underway" % [int(round(LURE_CALORIE_COST)), _format_duration(lure_minutes)])
    return "\n".join(lines)

func _build_fight_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var fight_minutes = int(ceil(FIGHT_BACK_HOURS * 60.0 * multiplier))
    lines.append("Spend %.1f hr (x%.1f) rushing the perimeter." % [FIGHT_BACK_HOURS, multiplier])
    lines.append("Energy -%d%% | +%d cal burn" % [int(round(FIGHT_BACK_REST_COST_PERCENT)), int(round(FIGHT_BACK_CALORIE_COST))])
    lines.append("Best gear: Knife (5-15 dmg) | Bow+Arrow (3-7 dmg) | Both (0-5 dmg)")
    lines.append("Clears wolves %d%% lure, direct assault guaranteed." % WOLF_LURE_SUCCESS_PERCENT)
    if bool(_wolf_state.get("active", false)) or bool(_wolf_state.get("present", false)):
        var remaining = int(_wolf_state.get("minutes_remaining", 0))
        var window = "now" if remaining <= 0 else "%s left" % _format_duration(remaining)
        lines.append("Wolves outside -> %s" % window)
    if zombie_system:
        var count = zombie_system.get_active_zombies()
        if count > 0:
            lines.append("Nearby undead: %d" % count)
    if time_system and fight_minutes > 0 and fight_minutes <= _get_minutes_left_today():
        lines.append("Ends at %s" % time_system.get_formatted_time_after(fight_minutes))
    lines.append("Day left: %s" % _format_duration(_get_minutes_left_today()))
    return "\n".join(lines)

func _build_trap_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(TRAP_DEPLOY_HOURS * 60.0 * multiplier))
    lines.append("Spend %.0f hr (x%.1f) to arm a trap." % [TRAP_DEPLOY_HOURS, multiplier])
    lines.append("Energy -%s%% | +%d cal burn" % [_format_percent_value(TRAP_ENERGY_COST_PERCENT), int(round(TRAP_CALORIE_COST))])
    if inventory_system:
        lines.append("Requires spike trap (Stock %d)" % inventory_system.get_item_count(TRAP_ITEM_ID))
    else:
        lines.append("Requires spike trap built")
    lines.append("Kills next zombie | %d%% break chance" % TRAP_BREAK_PERCENT)
    if _trap_state.get("active", false):
        var armed_time = String(_trap_state.get("deployed_at_time", ""))
        if armed_time != "":
            lines.append("Currently armed since %s" % armed_time)
    lines.append("Takes %s" % _format_duration(minutes))
    lines.append("Day left: %s" % _format_duration(_get_minutes_left_today()))
    return "\n".join(lines)

func _build_snare_place_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(SNARE_PLACE_HOURS * 60.0 * multiplier))
    lines.append("Spend %.1f hr (x%.1f) to set a ground snare." % [SNARE_PLACE_HOURS, multiplier])
    lines.append("Energy -%s%% | +%d cal burn" % [_format_percent_value(SNARE_PLACE_REST_COST_PERCENT), int(round(SNARE_PLACE_CALORIE_COST))])
    lines.append("Each hour: %d%% catch chance (Rabbit/Squirrel worth 2.0 food)." % SNARE_CATCH_PERCENT)
    if inventory_system:
        lines.append("Requires Animal Snare (Stock %d)" % inventory_system.get_item_count(SNARE_ITEM_ID))
    else:
        lines.append("Requires Animal Snare crafted")
    if !_snare_state.is_empty():
        var deployed = int(_snare_state.get("total_deployed", 0))
        var waiting = int(_snare_state.get("animals_ready", 0))
        if deployed > 0:
            lines.append("Deployed snares: %d active | %d waiting" % [max(deployed - waiting, 0), waiting])
    if time_system and minutes > 0 and minutes <= _get_minutes_left_today():
        lines.append("Ends at %s" % time_system.get_formatted_time_after(minutes))
    lines.append("Day left: %s" % _format_duration(_get_minutes_left_today()))
    return "\n".join(lines)

func _build_snare_check_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(SNARE_CHECK_HOURS * 60.0 * multiplier))
    lines.append("Spend %.1f hr (x%.1f) to inspect all snares." % [SNARE_CHECK_HOURS, multiplier])
    lines.append("Energy -%s%% | +%d cal burn" % [_format_percent_value(SNARE_CHECK_REST_COST_PERCENT), int(round(SNARE_CHECK_CALORIE_COST))])
    if !_snare_state.is_empty():
        var waiting = int(_snare_state.get("animals_ready", 0))
        if waiting > 0:
            lines.append("Animals waiting: %d" % waiting)
        else:
            lines.append("No animals waiting right now")
        var total = int(_snare_state.get("total_deployed", 0))
        if total > 0:
            lines.append("Snares placed: %d" % total)
    else:
        lines.append("Requires snares placed in the field")
    if time_system and minutes > 0 and minutes <= _get_minutes_left_today():
        lines.append("Ends at %s" % time_system.get_formatted_time_after(minutes))
    lines.append("Day left: %s" % _format_duration(_get_minutes_left_today()))
    return "\n".join(lines)

func _build_butcher_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(BUTCHER_HOURS * 60.0 * multiplier))
    lines.append("Spend %dh (x%.1f) cleaning and cooking fresh game." % [int(round(BUTCHER_HOURS)), multiplier])
    lines.append("Energy -%s%% | +%d cal burn" % [_format_percent_value(BUTCHER_REST_COST_PERCENT), int(round(BUTCHER_CALORIE_COST))])
    lines.append("Requires crafted knife, lit fire, and stored game from hunting")
    lines.append("Adds 25%% food (rounded up to the nearest 0.5 unit) to processed meat")
    if game_manager:
        var status = game_manager.get_butcher_status()
        var knife_stock = int(status.get("knife_stock", 0))
        var fire_lit = status.get("fire_lit", false)
        var pending_stock: Dictionary = status.get("pending_stock", {})
        var pending_total = 0.0
        if typeof(pending_stock) == TYPE_DICTIONARY:
            pending_total = float(pending_stock.get("total_food_units", 0.0))
        var fire_status = "Lit" if fire_lit else "Out"
        lines.append("Knife stock: %d | Fire: %s" % [knife_stock, fire_status])
        lines.append("Stored game: %.1f food" % pending_total)
    if time_system and minutes > 0 and minutes <= _get_minutes_left_today():
        lines.append("Ends at %s" % time_system.get_formatted_time_after(minutes))
    lines.append("Day left: %s" % _format_duration(_get_minutes_left_today()))
    return "\n".join(lines)

func _build_cook_whole_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(COOK_WHOLE_HOURS * 60.0 * multiplier))
    lines.append("Spend %dh (x%.1f) roasting game without knife work." % [int(round(COOK_WHOLE_HOURS)), multiplier])
    lines.append("Energy -%s%% | +%d cal burn" % [_format_percent_value(COOK_WHOLE_REST_COST_PERCENT), int(round(COOK_WHOLE_CALORIE_COST))])
    lines.append("Requires lit fire and stored game. Provides base food only (no bonus).")
    if game_manager:
        var status = game_manager.get_cook_whole_status()
        var fire_lit = status.get("fire_lit", false)
        var pending_stock: Dictionary = status.get("pending_stock", {})
        var pending_total = 0.0
        if typeof(pending_stock) == TYPE_DICTIONARY:
            pending_total = float(pending_stock.get("total_food_units", 0.0))
        var fire_status = "Lit" if fire_lit else "Out"
        lines.append("Fire: %s | Stored game: %.1f food" % [fire_status, pending_total])
    if time_system and minutes > 0 and minutes <= _get_minutes_left_today():
        lines.append("Ends at %s" % time_system.get_formatted_time_after(minutes))
    lines.append("Day left: %s" % _format_duration(_get_minutes_left_today()))
    return "\n".join(lines)

func _build_meal_description() -> String:
    var lines: PackedStringArray = []
    var option = _resolve_meal_option(selected_meal_key)
    var food_units = option.get("food_units", 1.0)
    var calories = int(round(food_units * CALORIES_PER_FOOD_UNIT))
    lines.append("Spend 1 hr to eat a %s meal." % option.get("display", selected_meal_key.capitalize()))
    lines.append("Consumes %s food (-%d cal debt)" % [_format_food(food_units), calories])
    if inventory_system:
        lines.append("Food on hand: %s" % _format_food(inventory_system.get_total_food_units()))
    else:
        lines.append("Inventory offline")
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Takes %s" % _format_duration(minutes))
    return "\n".join(lines)

func _build_repair_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Spend 1 hr (x%.1f) restoring the tower." % multiplier)
    lines.append("Costs 10%% rest / -350 cal")
    lines.append("Restores +%s hp" % _format_health_value(TowerHealthSystem.REPAIR_HEALTH_PER_ACTION))
    if inventory_system:
        var wood_stock = inventory_system.get_item_count("wood")
        lines.append("Needs 1 wood (Stock %d)" % wood_stock)
    else:
        lines.append("Needs 1 wood")
    if tower_health_system:
        lines.append("Tower %s" % _format_health_snapshot(tower_health_system.get_health()))
    else:
        lines.append("Tower status offline")
    lines.append("Takes %s" % _format_duration(minutes))
    return "\n".join(lines)

func _build_reinforce_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(120.0 * multiplier))
    lines.append("Spend 2 hr (x%.1f) fortifying the tower." % multiplier)
    lines.append("Costs 20%% rest / -450 cal")
    lines.append("Adds +%s hp (cap %s)" % [
        _format_health_value(25.0),
        _format_health_value(TowerHealthSystem.REINFORCED_MAX_HEALTH)
    ])
    if inventory_system:
        var wood_stock = inventory_system.get_item_count("wood")
        var nails_stock = inventory_system.get_item_count("nails")
        lines.append("Needs 3 wood (Stock %d)" % wood_stock)
        lines.append("Needs 5 nails (Stock %d)" % nails_stock)
    else:
        lines.append("Needs 3 wood & 5 nails")
    if tower_health_system:
        lines.append("Tower %s" % _format_health_snapshot(tower_health_system.get_health()))
    else:
        lines.append("Tower status offline")
    lines.append("Takes %s" % _format_duration(minutes))
    return "\n".join(lines)

func _on_decrease_button_pressed():
    _select_action("sleep")
    if sleep_select_button:
        sleep_select_button.button_pressed = true
    selected_hours = max(selected_hours - 1, 0)
    _refresh_display()

func _on_increase_button_pressed():
    _select_action("sleep")
    if sleep_select_button:
        sleep_select_button.button_pressed = true
    var hours_available = _get_sleep_hours_available()
    if hours_available <= 0:
        print("⚠️ No rest time left before daybreak")
        _refresh_display()
        return
    if selected_hours >= hours_available:
        print("⚠️ Cannot schedule beyond remaining daily time")
        return
    selected_hours = min(selected_hours + 1, hours_available)
    _refresh_display()

func _execute_sleep_action():
    if game_manager == null:
        _set_action_result("sleep", "Sleep unavailable")
        return

    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var hours_requested = float(selected_hours)
    var minutes_remaining = _get_minutes_left_today()

    if hours_requested <= 0.0:
        if minutes_remaining <= 0:
            _select_action("sleep", true)
            _set_action_result("sleep", "No time left before 6:00 AM.")
            return
        hours_requested = minutes_remaining / (60.0 * multiplier)

    var result = game_manager.schedule_sleep(hours_requested)
    if result.get("accepted", false):
        print("✅ Sleep applied: %s" % result)
        selected_hours = 0
        _set_action_result("sleep", "")
        _refresh_display()
        _close_menu()
    else:
        var minutes_left = result.get("minutes_available", _get_minutes_left_today())
        var rejection_multiplier = result.get("time_multiplier", multiplier)
        var message = "Not enough time (x%.1f, left: %s)" % [rejection_multiplier, _format_duration(minutes_left)]
        _select_action("sleep", true)
        _set_action_result("sleep", message)
        print("⚠️ Sleep rejected: %s" % result)

func _execute_forging_action():
    if game_manager == null:
        _set_forging_feedback("Forging unavailable", "offline")
        return

    _lock_forging_feedback()
    var result = game_manager.perform_forging()
    _set_forging_feedback(_format_forging_result(result), "result")
    if forging_results_panel:
        forging_results_panel.show_result(result)
    _refresh_display()

func _execute_camp_search_action():
    if game_manager == null:
        _set_action_result("camp_search", "Camp search unavailable", true)
        return

    var result = game_manager.perform_campground_search()
    _set_action_result("camp_search", _format_camp_search_result(result), true)
    if forging_results_panel:
        forging_results_panel.show_result(result)
    _refresh_display()

func _execute_hunt_action():
    if game_manager == null:
        _set_action_result("hunt", "Hunt unavailable", true)
        return

    var result = game_manager.perform_hunt()
    _set_action_result("hunt", _format_hunt_result(result), true)
    _refresh_display()

func _execute_fishing_action():
    if game_manager == null:
        _set_action_result("fishing", "Fishing unavailable", true)
        return

    var result = game_manager.perform_fishing()
    _set_action_result("fishing", _format_fishing_result(result), true)
    _refresh_display()

func _execute_lead_action():
    if game_manager == null:
        _set_lead_feedback("Lead Away unavailable", "offline")
        return

    _lock_lead_feedback()
    var status = game_manager.get_lure_status() if game_manager else {}
    var result: Dictionary
    if status.get("available", false):
        result = game_manager.perform_lure_incoming_zombies()
    else:
        result = game_manager.perform_lead_away_undead()
    _set_lead_feedback(_format_lead_result(result), "result")
    if action_popup_panel and String(result.get("action", "")) == "lure" and result.get("success", false):
        _show_lure_popup(result)
    _refresh_display()

func _execute_fight_action():
    if game_manager == null:
        _set_action_result("fight_back", "Fight Back unavailable", true)
        return

    var result = game_manager.perform_fight_back()
    _set_action_result("fight_back", _format_fight_result(result), true)
    _update_fight_summary()
    if action_popup_panel:
        _show_fight_popup(result)
    _refresh_display()

func _execute_trap_action():
    if game_manager == null:
        _set_action_result("trap", "Trap systems offline", true)
        return

    var result = game_manager.perform_trap_deployment()
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        var message: String
        match reason:
            "trap_active":
                message = "Trap already armed"
            "no_traps":
                var stock = int(result.get("trap_stock", 0))
                message = "Need built trap (Stock %d)" % max(stock, 0)
            "exceeds_day":
                var minutes_available = int(result.get("minutes_available", 0))
                message = _format_daybreak_warning(minutes_available)
            "systems_unavailable":
                message = "Trap offline"
            "consume_failed":
                message = "Trap deployment failed"
            _:
                message = "Trap deploy failed"
        _set_action_result("trap", message, true)
        _update_trap_summary()
        return

    var message = _format_trap_deploy_result(result)
    _set_action_result("trap", message, true)
    _trap_state = game_manager.get_trap_state()
    _update_trap_summary()
    if action_popup_panel and result.has("injury_report"):
        _show_trap_injury_popup(result.get("injury_report", {}))

func _execute_snare_place_action():
    if game_manager == null:
        _set_action_result("snare_place", "Snare placement offline", true)
        return

    var result = game_manager.perform_place_snare()
    if !result.get("success", false):
        var reason = String(result.get("reason", "failed"))
        var message: String
        match reason:
            "systems_unavailable":
                message = "Snare placement offline"
            "no_snares":
                var stock = int(result.get("snare_stock", 0))
                message = "Need Animal Snare (Stock %d)" % max(stock, 0)
            "zombies_present":
                var count = int(result.get("zombie_count", 0))
                message = "Zombies nearby (%d) - clear area first" % max(count, 0)
            "exceeds_day":
                var minutes_available = int(result.get("minutes_available", 0))
                message = _format_daybreak_warning(minutes_available)
            _:
                message = "Snare placement failed"
        _set_action_result("snare_place", message, true)
        _snare_state = game_manager.get_snare_state()
        _update_snare_place_summary()
        _update_snare_check_summary()
        return

    var message = _format_snare_place_result(result)
    _set_action_result("snare_place", message, true)
    _snare_state = game_manager.get_snare_state()
    _update_snare_place_summary()
    _update_snare_check_summary()

func _execute_snare_check_action():
    if game_manager == null:
        _set_action_result("snare_check", "Snare checks offline", true)
        return

    var result = game_manager.perform_check_snares()
    if !result.get("success", false):
        var reason = String(result.get("reason", "failed"))
        var message: String
        match reason:
            "systems_unavailable":
                message = "Snare checks offline"
            "no_snares":
                message = "No snares placed yet"
            "zombies_present":
                var count = int(result.get("zombie_count", 0))
                message = "Zombies nearby (%d) - clear area first" % max(count, 0)
            "empty":
                message = String(result.get("message", "The snare is empty still, try again later."))
            "exceeds_day":
                var minutes_available = int(result.get("minutes_available", 0))
                message = _format_daybreak_warning(minutes_available)
            _:
                message = "Snare check failed"
        _set_action_result("snare_check", message, true)
        _snare_state = game_manager.get_snare_state()
        _update_snare_place_summary()
        _update_snare_check_summary()
        return

    var message = _format_snare_check_result(result)
    _set_action_result("snare_check", message, true)
    _snare_state = game_manager.get_snare_state()
    _update_snare_place_summary()
    _update_snare_check_summary()

func _execute_butcher_action():
    if game_manager == null:
        _set_action_result("butcher", "Butcher unavailable", true)
        return

    var result = game_manager.perform_butcher_and_cook()
    _set_action_result("butcher", _format_butcher_result(result), true)

func _execute_cook_whole_action():
    if game_manager == null:
        _set_action_result("cook_whole", "Cook Whole unavailable", true)
        return

    var result = game_manager.perform_cook_animals_whole()
    _set_action_result("cook_whole", _format_cook_whole_result(result), true)
    _refresh_display()

func _execute_recon_action():
    if game_manager == null:
        _set_action_result("recon", "Recon unavailable", true)
        return

    var result = game_manager.perform_recon()
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        var message: String
        match reason:
            "systems_unavailable":
                message = "Recon offline"
            "after_window":
                var window_after: Dictionary = result.get("window", {})
                var resume_minutes = int(window_after.get("resumes_in_minutes", 0))
                if resume_minutes > 0:
                    message = "Recon back %s" % _format_duration(resume_minutes)
                else:
                    var resume_label = String(window_after.get("resumes_at", "6:00 AM"))
                    message = "Recon back at %s" % resume_label
            "before_window":
                var window_before: Dictionary = result.get("window", {})
                var wait_minutes = int(window_before.get("minutes_until_window", 0))
                if wait_minutes > 0:
                    message = "Recon ready %s" % _format_duration(wait_minutes)
                else:
                    var resume_clock = String(window_before.get("resumes_at", "6:00 AM"))
                    message = "Recon ready at %s" % resume_clock
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            "blocked":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            _:
                message = "Recon failed"
        _set_action_result("recon", message, true)
        return

    _set_action_result("recon", "Recon data updated", true)
    if action_popup_panel:
        _show_recon_popup(result)
    _refresh_display()

func _on_meal_size_option_item_selected(index: int):
    if index < 0 or index >= meal_size_option.item_count:
        return
    var key = meal_size_option.get_item_metadata(index)
    if key is String:
        selected_meal_key = key
    _update_meal_summary()

func _execute_meal_action():
    if game_manager == null:
        _set_action_result("meal", "Eating unavailable")
        return

    var result = game_manager.perform_eating(selected_meal_key)
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        var message: String
        match reason:
            "insufficient_food":
                var required = result.get("required_food", 0.0)
                var available = result.get("total_food_units", 0.0)
                message = "Need %s food (Have %s)" % [_format_food(required), _format_food(available)]
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            _:
                message = "Meal failed"
        _set_action_result("meal", message)
        return

    var calories = int(round(result.get("calories_consumed", 0.0)))
    var food_spent = result.get("food_units_spent", 0.0)
    var ended_at = result.get("ended_at_time", "")
    var message_parts: PackedStringArray = []
    message_parts.append("-%d cal" % calories)
    message_parts.append("-%s food" % _format_food(food_spent))
    if ended_at != "":
        message_parts.append("End %s" % ended_at)
    var message = "%s meal -> %s" % [result.get("portion", selected_meal_key).capitalize(), " | ".join(message_parts)]
    _set_action_result("meal", message)
    _refresh_display()

func _execute_repair_action():
    if game_manager == null:
        _set_action_result("repair", "Repair unavailable")
        return

    var result = game_manager.repair_tower({})
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        var message: String
        match reason:
            "tower_full_health":
                message = "Tower already stable"
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            "insufficient_wood":
                var required = int(result.get("wood_required", 1))
                var available = int(result.get("wood_available", 0))
                message = "Need %d wood (Have %d)" % [required, available]
            _:
                message = "Repair failed"
        _set_action_result("repair", message)
        return

    var restored = result.get("health_restored", 0.0)
    var after = result.get("health_after", 0.0)
    var ended_at = result.get("ended_at_time", "")
    var parts: PackedStringArray = []
    parts.append("+%s hp" % _format_health_value(restored))
    parts.append("%s" % _format_health_snapshot(after))
    parts.append("-%d cal" % int(round(result.get("calories_spent", 0.0))))
    var wood_spent = int(result.get("wood_spent", 0))
    if wood_spent > 0:
        parts.append("-%d wood (Stock %d)" % [wood_spent, int(result.get("wood_remaining", 0))])
    var rest_bonus = result.get("rest_granted_percent", 0.0)
    if rest_bonus > 0.0:
        parts.append("+%d%% rest" % int(round(rest_bonus)))
    if ended_at != "":
        parts.append("End %s" % ended_at)
    var message = "Repair -> %s" % " | ".join(parts)
    _set_action_result("repair", message)
    _refresh_display()
func _execute_reinforce_action():
    if game_manager == null:
        _set_action_result("reinforce", "Reinforce unavailable")
        return

    var result = game_manager.reinforce_tower({})
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        var message: String
        match reason:
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            "insufficient_material":
                var need: PackedStringArray = []
                var required_wood = int(result.get("wood_required", 3))
                var wood_available = int(result.get("wood_available", 0))
                if wood_available < required_wood:
                    need.append("Need %d wood (Have %d)" % [required_wood, wood_available])
                var required_nails = int(result.get("nails_required", 5))
                var nails_available = int(result.get("nails_available", 0))
                if nails_available < required_nails:
                    need.append("Need %d nails (Have %d)" % [required_nails, nails_available])
                if need.is_empty():
                    need.append("Materials missing")
                message = " / ".join(need)
            "reinforced_cap":
                var cap_value = int(round(result.get("health", TowerHealthSystem.REINFORCED_MAX_HEALTH)))
                message = "Tower fully fortified (%d)" % cap_value
            "tower_full_health":
                var cap = int(round(result.get("health", TowerHealthSystem.REINFORCED_MAX_HEALTH)))
                message = "Tower already fortified (%d)" % cap
            "wood_consume_failed":
                message = "Wood spend failed"
            "nails_consume_failed":
                message = "Nails spend failed"
            "systems_unavailable":
                message = "Systems offline"
            _:
                message = "Reinforce failed"
        _set_action_result("reinforce", message)
        return

    var added = result.get("health_added", 0.0)
    var after = result.get("health_after", 0.0)
    var ended_at = result.get("ended_at_time", "")
    var rest_spent = result.get("rest_spent_percent", 0.0)
    var calories = int(round(result.get("calories_spent", 0.0)))
    var wood_spent = int(result.get("wood_spent", 0))
    var nails_spent = int(result.get("nails_spent", 0))
    var wood_remaining = int(result.get("wood_remaining", 0))
    var nails_remaining = int(result.get("nails_remaining", 0))
    var parts: PackedStringArray = []
    parts.append("+%s hp" % _format_health_value(added))
    parts.append("%s" % _format_health_snapshot(after))
    if rest_spent > 0.0:
        parts.append("-%d%% rest" % int(round(rest_spent)))
    if calories > 0:
        parts.append("-%d cal" % calories)
    if wood_spent > 0:
        var wood_fragment = "-%d wood" % wood_spent
        wood_fragment += " (Stock %d)" % max(wood_remaining, 0)
        parts.append(wood_fragment)
    if nails_spent > 0:
        var nail_fragment = "-%d nails" % nails_spent
        nail_fragment += " (Stock %d)" % max(nails_remaining, 0)
        parts.append(nail_fragment)
    if ended_at != "":
        parts.append("End %s" % ended_at)
    var message = "Reinforce -> %s" % " | ".join(parts)
    _set_action_result("reinforce", message)
    _refresh_display()


func _format_forging_ready(total_food: float) -> String:
    var capacity = game_manager.get_carry_capacity() if game_manager else InventorySystem.DEFAULT_CARRY_CAPACITY
    var base_capacity = InventorySystem.DEFAULT_CARRY_CAPACITY
    var capacity_fragment = "Carry %d slots" % max(capacity, 0)
    if capacity <= base_capacity:
        capacity_fragment += " (12 w/Backpack)"
    else:
        capacity_fragment += " (Base %d)" % base_capacity
    return "Forging ready (-%s%% energy | +%d cal burn | %s | Food %.1f)" % [
        _format_percent_value(FORGING_REST_COST_PERCENT),
        int(round(FORGING_CALORIE_COST)),
        capacity_fragment,
        total_food
    ]

func _format_camp_search_ready() -> String:
    var capacity = game_manager.get_carry_capacity() if game_manager else InventorySystem.DEFAULT_CARRY_CAPACITY
    var base_capacity = InventorySystem.DEFAULT_CARRY_CAPACITY
    var capacity_fragment = "Carry %d slots" % max(capacity, 0)
    if capacity <= base_capacity:
        capacity_fragment += " (12 w/Backpack)"
    else:
        capacity_fragment += " (Base %d)" % base_capacity
    return "Camp Search ready (-%s%% energy | +%d cal burn | %s | %dh sweep)" % [
        _format_percent_value(CAMP_SEARCH_REST_COST_PERCENT),
        int(round(CAMP_SEARCH_CALORIE_COST)),
        capacity_fragment,
        int(round(CAMP_SEARCH_HOURS))
    ]

func _format_hunt_ready() -> String:
    if game_manager == null:
        return "Hunt offline"
    var status = game_manager.get_hunt_status()
    var bow_stock = int(status.get("bow_stock", 0))
    var arrow_stock = int(status.get("arrow_stock", 0))
    var shots = int(status.get("shots_per_trip", HUNT_ROLLS_PER_TRIP))
    var planned_shots = int(status.get("shots_planned", shots))
    var pending_stock: Dictionary = status.get("pending_stock", {})
    var pending_total = 0.0
    if typeof(pending_stock) == TYPE_DICTIONARY:
        pending_total = float(pending_stock.get("total_food_units", 0.0))
    var fragments: PackedStringArray = []
    fragments.append("-%s%% energy" % _format_percent_value(HUNT_REST_COST_PERCENT))
    fragments.append("+%d cal burn" % int(round(HUNT_CALORIE_COST)))
    var shot_fragment = "Shots %d" % max(shots, 0)
    if planned_shots > 0 and planned_shots != shots:
        shot_fragment += " (Plan %d)" % max(planned_shots, 0)
    shot_fragment += " (%d%% break)" % HUNT_ARROW_BREAK_PERCENT
    fragments.append(shot_fragment)
    var bow_fragment = "Bow %d" % max(bow_stock, 0)
    if bow_stock <= 0:
        bow_fragment += " (Need 1)"
    fragments.append(bow_fragment)
    var arrow_fragment = "Arrows %d" % max(arrow_stock, 0)
    if arrow_stock <= 0:
        arrow_fragment += " (Need 1)"
    fragments.append(arrow_fragment)
    fragments.append("Game %.1f food" % pending_total)
    var zombies = int(status.get("zombies_nearby", 0))
    if zombies > 0:
        fragments.append("Blocked %d undead" % zombies)
    return "Hunt ready (%s)" % " | ".join(fragments)

func _format_butcher_ready() -> String:
    if game_manager == null:
        return "Butcher offline"
    var status = game_manager.get_butcher_status()
    var knife_stock = int(status.get("knife_stock", 0))
    var fire_lit = status.get("fire_lit", false)
    var pending_stock: Dictionary = status.get("pending_stock", {})
    var pending_total = 0.0
    if typeof(pending_stock) == TYPE_DICTIONARY:
        pending_total = float(pending_stock.get("total_food_units", 0.0))
    var processable = float(status.get("processable_food_units", 0.0))
    var fragments: PackedStringArray = []
    fragments.append("-%s%% energy" % _format_percent_value(BUTCHER_REST_COST_PERCENT))
    fragments.append("+%d cal burn" % int(round(BUTCHER_CALORIE_COST)))
    var knife_fragment = "Knife %d" % max(knife_stock, 0)
    if knife_stock <= 0:
        knife_fragment += " (Need 1)"
    fragments.append(knife_fragment)
    fragments.append("Fire %s" % ("Lit" if fire_lit else "Out"))
    if pending_total > 0.0:
        fragments.append("Game %.1f food" % pending_total)
    else:
        fragments.append("No game stored")
    if processable > 0.0:
        fragments.append("Cookable %s" % _format_food(processable))
    else:
        fragments.append("Cookable 0 (Need stored food)")
    return "Butcher ready (%s)" % " | ".join(fragments)

func _format_cook_whole_ready() -> String:
    if game_manager == null:
        return "Cook Whole offline"
    var status = game_manager.get_cook_whole_status()
    var fire_lit = status.get("fire_lit", false)
    var pending_stock: Dictionary = status.get("pending_stock", {})
    var pending_total = 0.0
    if typeof(pending_stock) == TYPE_DICTIONARY:
        pending_total = float(pending_stock.get("total_food_units", 0.0))
    var processable = float(status.get("processable_food_units", 0.0))
    var fragments: PackedStringArray = []
    fragments.append("-%s%% energy" % _format_percent_value(COOK_WHOLE_REST_COST_PERCENT))
    fragments.append("+%d cal burn" % int(round(COOK_WHOLE_CALORIE_COST)))
    fragments.append("Fire %s" % ("Lit" if fire_lit else "Out"))
    if pending_total > 0.0:
        fragments.append("Game %.1f food" % pending_total)
    else:
        fragments.append("No game stored")
    if processable > 0.0:
        fragments.append("Cookable %s" % _format_food(processable))
    else:
        fragments.append("Cookable 0 (Need stored food)")
    return "Cook Whole ready (%s)" % " | ".join(fragments)

func _format_forging_result(result: Dictionary) -> String:
    var end_at = result.get("ended_at_time", "")
    if result.get("success", false):
        var parts: PackedStringArray = []
        var loot: Array = result.get("loot", [])
        if loot.is_empty():
            parts.append("Supplies added")
        else:
            for item in loot:
                var label = item.get("display_name", item.get("item_id", "Find"))
                var qty = int(item.get("quantity_added", item.get("quantity", 1)))
                var entry = "%s x%d" % [label, max(qty, 1)]
                var food_gain = float(item.get("food_gained", 0.0))
                if !is_zero_approx(food_gain):
                    entry += " (+%s food)" % _format_food(food_gain)
                parts.append(entry)
        var carried = int(result.get("items_carried", loot.size()))
        var capacity = int(result.get("carry_capacity", game_manager.get_carry_capacity() if game_manager else InventorySystem.DEFAULT_CARRY_CAPACITY))
        if capacity > 0:
            parts.append("Carry %d/%d" % [max(min(carried, capacity), 0), capacity])
        var dropped: Array = result.get("dropped_loot", [])
        if !dropped.is_empty():
            var dropped_fragments: PackedStringArray = []
            for item in dropped:
                var label = item.get("display_name", item.get("item_id", "Drop"))
                var qty = int(item.get("quantity", 1))
                dropped_fragments.append("%s x%d" % [label, max(qty, 1)])
            if !dropped_fragments.is_empty():
                parts.append("Dropped: %s" % ", ".join(dropped_fragments))
        parts.append("Total %s" % _format_food(result.get("total_food_units", 0.0)))
        var rest_spent = result.get("rest_spent_percent", 0.0)
        if rest_spent > 0.0:
            parts.append("-%s%% energy" % _format_percent_value(rest_spent))
            var calories_spent = int(round(result.get("calories_spent", FORGING_CALORIE_COST)))
            if calories_spent > 0:
                parts.append("+%d cal burn" % calories_spent)
            if end_at != "":
                parts.append("End %s" % end_at)
            return " | ".join(parts)

    var reason = result.get("reason", "")
    match reason:
        "systems_unavailable":
            return "Forging offline"
        "zombies_present":
            var count = int(result.get("zombie_count", 0))
            return "Zombies nearby! Forging blocked (%d)" % max(count, 1)
        "carry_limit_reached":
            var capacity = int(result.get("carry_capacity", game_manager.get_carry_capacity() if game_manager else InventorySystem.DEFAULT_CARRY_CAPACITY))
            var fragments: PackedStringArray = []
            fragments.append("Carry full (%d slots)" % max(capacity, 0))
            var dropped: Array = result.get("dropped_loot", [])
            if !dropped.is_empty():
                var dropped_fragments: PackedStringArray = []
                for item in dropped:
                    var label = item.get("display_name", item.get("item_id", "Drop"))
                    var qty = int(item.get("quantity", 1))
                    dropped_fragments.append("%s x%d" % [label, max(qty, 1)])
                if !dropped_fragments.is_empty():
                    fragments.append("Dropped: %s" % ", ".join(dropped_fragments))
            if end_at != "":
                fragments.append("End %s" % end_at)
            var rest_spent = result.get("rest_spent_percent", 0.0)
            if rest_spent > 0.0:
                fragments.append("-%s%% energy" % _format_percent_value(rest_spent))
            var calories_spent = int(round(result.get("calories_spent", FORGING_CALORIE_COST)))
            if calories_spent > 0:
                fragments.append("+%d cal burn" % calories_spent)
            return "Forging blocked -> %s" % " | ".join(fragments)
        "nothing_found":
            var message = "Found nothing"
            var rest_spent = result.get("rest_spent_percent", 0.0)
            if rest_spent > 0.0:
                message += " | -%s%% energy" % _format_percent_value(rest_spent)
            var calories_spent = int(round(result.get("calories_spent", FORGING_CALORIE_COST)))
            if calories_spent > 0:
                message += " | +%d cal burn" % calories_spent
            if end_at != "":
                message += " | End %s" % end_at
            return message
        "exceeds_day":
            var minutes_available = result.get("minutes_available", 0)
            return _format_daybreak_warning(minutes_available)
        _:
            var fallback = "Forging failed"
            var rest_spent = result.get("rest_spent_percent", 0.0)
            if rest_spent > 0.0:
                fallback += " | -%s%% energy" % _format_percent_value(rest_spent)
            var calories_spent = int(round(result.get("calories_spent", FORGING_CALORIE_COST)))
            if calories_spent > 0:
                fallback += " | +%d cal burn" % calories_spent
            return fallback

func _format_camp_search_result(result: Dictionary) -> String:
    var end_at = result.get("ended_at_time", "")
    if result.get("success", false):
        var parts: PackedStringArray = []
        var loot: Array = result.get("loot", [])
        if loot.is_empty():
            parts.append("Supplies secured")
        else:
            for item in loot:
                var label = item.get("display_name", item.get("item_id", "Find"))
                var qty = int(item.get("quantity_added", item.get("quantity", 1)))
                parts.append("%s x%d" % [label, max(qty, 1)])
        var carried = int(result.get("items_carried", loot.size()))
        var capacity = int(result.get("carry_capacity", game_manager.get_carry_capacity() if game_manager else InventorySystem.DEFAULT_CARRY_CAPACITY))
        if capacity > 0:
            parts.append("Carry %d/%d" % [max(min(carried, capacity), 0), capacity])
        var dropped: Array = result.get("dropped_loot", [])
        if !dropped.is_empty():
            var dropped_fragments: PackedStringArray = []
            for item in dropped:
                var label = item.get("display_name", item.get("item_id", "Drop"))
                var qty = int(item.get("quantity", 1))
                dropped_fragments.append("%s x%d" % [label, max(qty, 1)])
            if !dropped_fragments.is_empty():
                parts.append("Dropped: %s" % ", ".join(dropped_fragments))
        var rest_spent = result.get("rest_spent_percent", 0.0)
        if rest_spent > 0.0:
            parts.append("-%s%% energy" % _format_percent_value(rest_spent))
        var calories_spent = int(round(result.get("calories_spent", CAMP_SEARCH_CALORIE_COST)))
        if calories_spent > 0:
            parts.append("+%d cal burn" % calories_spent)
        if end_at != "":
            parts.append("End %s" % end_at)
        return " | ".join(parts)

    var reason = result.get("reason", "")
    match reason:
        "systems_unavailable":
            return "Camp search offline"
        "zombies_present":
            var count = int(result.get("zombie_count", 0))
            return "Zombies nearby! Camp search blocked (%d)" % max(count, 1)
        "carry_limit_reached":
            var capacity = int(result.get("carry_capacity", game_manager.get_carry_capacity() if game_manager else InventorySystem.DEFAULT_CARRY_CAPACITY))
            var fragments: PackedStringArray = []
            fragments.append("Carry full (%d slots)" % max(capacity, 0))
            var dropped: Array = result.get("dropped_loot", [])
            if !dropped.is_empty():
                var dropped_fragments: PackedStringArray = []
                for item in dropped:
                    var label = item.get("display_name", item.get("item_id", "Drop"))
                    var qty = int(item.get("quantity", 1))
                    dropped_fragments.append("%s x%d" % [label, max(qty, 1)])
                if !dropped_fragments.is_empty():
                    fragments.append("Dropped: %s" % ", ".join(dropped_fragments))
            if end_at != "":
                fragments.append("End %s" % end_at)
            var rest_spent = result.get("rest_spent_percent", 0.0)
            if rest_spent > 0.0:
                fragments.append("-%s%% energy" % _format_percent_value(rest_spent))
            var calories_spent = int(round(result.get("calories_spent", CAMP_SEARCH_CALORIE_COST)))
            if calories_spent > 0:
                fragments.append("+%d cal burn" % calories_spent)
            return "Camp search blocked -> %s" % " | ".join(fragments)
        "nothing_found":
            var message = "Camps were empty"
            var rest_spent = result.get("rest_spent_percent", 0.0)
            if rest_spent > 0.0:
                message += " | -%s%% energy" % _format_percent_value(rest_spent)
            var calories_spent = int(round(result.get("calories_spent", CAMP_SEARCH_CALORIE_COST)))
            if calories_spent > 0:
                message += " | +%d cal burn" % calories_spent
            if end_at != "":
                message += " | End %s" % end_at
            return message
        "exceeds_day":
            var minutes_available = result.get("minutes_available", 0)
            return _format_daybreak_warning(minutes_available)
        _:
            var fallback = "Camp search failed"
            var rest_spent = result.get("rest_spent_percent", 0.0)
            if rest_spent > 0.0:
                fallback += " | -%s%% energy" % _format_percent_value(rest_spent)
            var calories_spent = int(round(result.get("calories_spent", CAMP_SEARCH_CALORIE_COST)))
            if calories_spent > 0:
                fallback += " | +%d cal burn" % calories_spent
            return fallback

func _format_hunt_result(result: Dictionary) -> String:
    var end_at = result.get("ended_at_time", "")
    if result.get("success", false):
        var parts: PackedStringArray = []
        var animals: Array = result.get("animals", [])
        if animals.is_empty():
            parts.append("No game recovered")
        else:
            var tallies: Dictionary = {}
            for entry in animals:
                var label = String(entry.get("display_name", entry.get("id", "Game")))
                tallies[label] = int(tallies.get(label, 0)) + 1
            var tally_fragments: PackedStringArray = []
            for label in tallies.keys():
                tally_fragments.append("%s x%d" % [label, int(tallies[label])])
            if !tally_fragments.is_empty():
                parts.append(", ".join(tally_fragments))
        var food_gained = float(result.get("food_units_gained", 0.0))
        if food_gained > 0.0:
            parts.append("+%s food" % _format_food(food_gained))
        var shots_taken = int(result.get("shots_taken", 0))
        var shots_requested = int(result.get("shots_requested", HUNT_ROLLS_PER_TRIP))
        var shots_planned = int(result.get("shots_planned", shots_requested))
        var shot_fragment = "Shots %d/%d" % [max(shots_taken, 0), max(shots_requested, 0)]
        if shots_planned > 0 and shots_planned != shots_requested:
            shot_fragment += " (Plan %d)" % max(shots_planned, 0)
        parts.append(shot_fragment)
        var arrow_breaks = int(result.get("arrow_breaks", 0))
        var arrow_before = int(result.get("arrow_stock_before", 0))
        var arrow_after = int(result.get("arrows_remaining", 0))
        parts.append("Arrows %d→%d (-%d)" % [arrow_before, arrow_after, max(arrow_breaks, 0)])
        if result.get("arrow_consume_failed", false):
            parts.append("Arrow spend failed")
        var pending_stock: Dictionary = result.get("pending_stock", {})
        if typeof(pending_stock) == TYPE_DICTIONARY:
            var pending_total = float(pending_stock.get("total_food_units", 0.0))
            if pending_total > 0.0:
                parts.append("Game bank %.1f" % pending_total)
        var rest_spent = result.get("rest_spent_percent", 0.0)
        if rest_spent > 0.0:
            parts.append("-%s%% energy" % _format_percent_value(rest_spent))
        var calories_spent = int(round(result.get("calories_spent", HUNT_CALORIE_COST)))
        if calories_spent > 0:
            parts.append("+%d cal burn" % calories_spent)
        if end_at != "":
            parts.append("End %s" % end_at)
        return " | ".join(parts)

    var reason = String(result.get("reason", "failed"))
    match reason:
        "systems_unavailable":
            return "Hunt offline"
        "zombies_present":
            var count = int(result.get("zombie_count", 0))
            return "Zombies nearby (%d)" % max(count, 1)
        "no_bow":
            return "Need crafted bow"
        "no_arrows":
            var stock = int(result.get("arrow_stock", 0))
            return "Need arrows (Stock %d)" % max(stock, 0)
        "no_game":
            var fragments: PackedStringArray = []
            fragments.append("Tracked game but empty-handed")
            var shots_taken = int(result.get("shots_taken", 0))
            if shots_taken > 0:
                var requested = int(result.get("shots_requested", HUNT_ROLLS_PER_TRIP))
                var planned = int(result.get("shots_planned", requested))
                var miss_fragment = "Shots %d" % shots_taken
                if planned > 0 and planned != requested:
                    miss_fragment += " (Plan %d)" % max(planned, 0)
                fragments.append(miss_fragment)
            var arrow_breaks = int(result.get("arrow_breaks", 0))
            if arrow_breaks > 0:
                fragments.append("Arrows lost %d" % arrow_breaks)
            if result.get("arrow_consume_failed", false):
                fragments.append("Arrow spend failed")
            var rest_spent = result.get("rest_spent_percent", 0.0)
            if rest_spent > 0.0:
                fragments.append("-%s%% energy" % _format_percent_value(rest_spent))
            var calories_spent = int(round(result.get("calories_spent", HUNT_CALORIE_COST)))
            if calories_spent > 0:
                fragments.append("+%d cal burn" % calories_spent)
            if end_at != "":
                fragments.append("End %s" % end_at)
            return " | ".join(fragments)
        "time_rejected", "exceeds_day":
            var minutes_available = int(result.get("minutes_available", 0))
            return _format_daybreak_warning(minutes_available)
        _:
            return "Hunt failed"

func _format_butcher_result(result: Dictionary) -> String:
    var end_at = result.get("ended_at_time", "")
    if result.get("success", false):
        var parts: PackedStringArray = []
        var processable = float(result.get("processable_food_units", 0.0))
        if processable > 0.0:
            parts.append("Cooked %s food" % _format_food(processable))
        var bonus = float(result.get("bonus_food_units", 0.0))
        if bonus > 0.0:
            parts.append("Bonus +%s food" % _format_food(bonus))
        var pending_stock: Dictionary = result.get("pending_stock", {})
        if typeof(pending_stock) == TYPE_DICTIONARY:
            var pending_total = float(pending_stock.get("total_food_units", 0.0))
            parts.append("Game bank %.1f" % pending_total)
        var rest_spent = result.get("rest_spent_percent", 0.0)
        if rest_spent > 0.0:
            parts.append("-%s%% energy" % _format_percent_value(rest_spent))
        var calories_spent = int(round(result.get("calories_spent", BUTCHER_CALORIE_COST)))
        if calories_spent > 0:
            parts.append("+%d cal burn" % calories_spent)
        if end_at != "":
            parts.append("End %s" % end_at)
        return " | ".join(parts)

    var reason = String(result.get("reason", "failed"))
    match reason:
        "systems_unavailable":
            return "Butcher offline"
        "no_knife":
            var stock = int(result.get("knife_stock", 0))
            return "Need crafted knife (Stock %d)" % max(stock, 0)
        "fire_unlit":
            return "Need lit fire"
        "no_game":
            return "No game stored"
        "no_food":
            return "Food already eaten"
        "time_rejected", "exceeds_day":
            var minutes_available = int(result.get("minutes_available", 0))
            return _format_daybreak_warning(minutes_available)
        _:
            return "Butcher failed"

func _format_cook_whole_result(result: Dictionary) -> String:
    var end_at = result.get("ended_at_time", "")
    if result.get("success", false):
        var parts: PackedStringArray = []
        var processable = float(result.get("processable_food_units", 0.0))
        if processable > 0.0:
            parts.append("Cooked %s food" % _format_food(processable))
        var pending_stock: Dictionary = result.get("pending_stock", {})
        if typeof(pending_stock) == TYPE_DICTIONARY:
            var pending_total = float(pending_stock.get("total_food_units", 0.0))
            parts.append("Game bank %.1f" % pending_total)
        var rest_spent = result.get("rest_spent_percent", 0.0)
        if rest_spent > 0.0:
            parts.append("-%s%% energy" % _format_percent_value(rest_spent))
        var calories_spent = int(round(result.get("calories_spent", COOK_WHOLE_CALORIE_COST)))
        if calories_spent > 0:
            parts.append("+%d cal burn" % calories_spent)
        if end_at != "":
            parts.append("End %s" % end_at)
        return " | ".join(parts)

    var reason = String(result.get("reason", "failed"))
    match reason:
        "systems_unavailable":
            return "Cook Whole offline"
        "fire_unlit":
            return "Need lit fire"
        "no_game":
            return "No game stored"
        "no_food":
            return "Food already eaten"
        "time_rejected", "exceeds_day":
            var minutes_available = int(result.get("minutes_available", 0))
            return _format_daybreak_warning(minutes_available)
        _:
            return "Cook Whole failed"

func _format_fishing_result(result: Dictionary) -> String:
    if typeof(result) != TYPE_DICTIONARY or result.is_empty():
        return "Fishing failed"

    var reason = String(result.get("reason", ""))
    match reason:
        "systems_unavailable":
            return "Fishing offline"
        "missing_rod":
            return "Need Fishing Rod"
        "no_grubs":
            return "Need Grub"
        "exceeds_day":
            var minutes_available = result.get("minutes_available", 0)
            return _format_daybreak_warning(minutes_available)
        "time_rejected":
            var minutes_available = result.get("minutes_available", _get_minutes_left_today())
            return _format_daybreak_warning(minutes_available)
        "no_duration":
            return "No time scheduled"

    var rest_spent = float(result.get("rest_spent_percent", 0.0))
    var calories = int(round(result.get("calories_spent", FISHING_CALORIE_COST)))
    var grubs_remaining = int(result.get("grubs_remaining", -1))
    var grub_lost = result.get("grub_lost", false)
    var grub_consume_failed = result.get("grub_consume_failed", false)
    var ended_at = String(result.get("ended_at_time", ""))

    if result.get("success", false):
        var parts: PackedStringArray = []
        var rolls_total = max(int(result.get("rolls", FISHING_ROLLS_PER_HOUR)), 1)
        var successes = int(result.get("successful_rolls", 0))
        var catches: Array = result.get("catches", [])
        var size_counts: Dictionary = {}
        for catch in catches:
            if typeof(catch) != TYPE_DICTIONARY:
                continue
            var size = String(catch.get("size", "small")).to_lower()
            size_counts[size] = int(size_counts.get(size, 0)) + 1
        var mix: PackedStringArray = []
        for entry in FISHING_SIZE_TABLE:
            var size_key = String(entry.get("size", "")).to_lower()
            if size_key == "":
                continue
            var count = int(size_counts.get(size_key, 0))
            if count > 0:
                mix.append("%s x%d" % [FISHING_SIZE_LABELS.get(size_key, size_key.capitalize()), count])
        if mix.is_empty():
            mix.append("No catches")
        parts.append("%d/%d hits (%s)" % [max(successes, 0), rolls_total, ", ".join(mix)])

        var food_gained = float(result.get("food_units_gained", 0.0))
        if food_gained > 0.0:
            parts.append("+%s food" % _format_food(food_gained))
        if rest_spent > 0.0:
            parts.append("-%d%% rest" % int(round(rest_spent)))
        if calories > 0:
            parts.append("-%d cal" % calories)
        if grub_consume_failed:
            parts.append("Grub spend failed")
        elif grub_lost:
            parts.append("Grub lost")
        if grubs_remaining >= 0:
            parts.append("Grubs %d" % grubs_remaining)
        var total_food = result.get("total_food_units", null)
        if typeof(total_food) == TYPE_FLOAT or typeof(total_food) == TYPE_INT:
            parts.append("Stock %s" % _format_food(float(total_food)))
        if ended_at != "":
            parts.append("End %s" % ended_at)
        return "Fishing -> %s" % " | ".join(parts)

    if reason == "no_catch":
        var parts_nc: PackedStringArray = []
        var rolls_total_nc = max(int(result.get("rolls", FISHING_ROLLS_PER_HOUR)), 1)
        parts_nc.append("0/%d hits" % rolls_total_nc)
        if rest_spent > 0.0:
            parts_nc.append("-%d%% rest" % int(round(rest_spent)))
        if calories > 0:
            parts_nc.append("-%d cal" % calories)
        if grub_consume_failed:
            parts_nc.append("Grub spend failed")
        elif grub_lost:
            parts_nc.append("Grub lost")
        else:
            parts_nc.append("Grub kept")
        if grubs_remaining >= 0:
            parts_nc.append("Grubs %d" % grubs_remaining)
        if ended_at != "":
            parts_nc.append("End %s" % ended_at)
        return "Fishing -> %s" % " | ".join(parts_nc)

    var parts: PackedStringArray = []
    parts.append("Fishing failed")
    if rest_spent > 0.0:
        parts.append("-%d%% rest" % int(round(rest_spent)))
    if calories > 0:
        parts.append("-%d cal" % calories)
    if grub_consume_failed:
        parts.append("Grub spend failed")
    elif grub_lost:
        parts.append("Grub lost")
    if grubs_remaining >= 0:
        parts.append("Grubs %d" % grubs_remaining)
    if ended_at != "":
        parts.append("End %s" % ended_at)
    return "Fishing -> %s" % " | ".join(parts)

func _format_recon_result(result: Dictionary) -> String:
    var parts: PackedStringArray = []
    var hours_scanned = int(result.get("hours_scanned", RECON_OUTLOOK_HOURS))
    parts.append("Scouted %dh" % max(hours_scanned, 1))
    var calories = int(round(result.get("calories_spent", GameManager.RECON_CALORIE_COST)))
    if calories > 0:
        parts.append("-%d cal" % calories)
    var ended_at = result.get("ended_at_time", "")
    if ended_at != "":
        parts.append("End %s" % ended_at)
    var window_status: Dictionary = result.get("window_status", {})
    if typeof(window_status) == TYPE_DICTIONARY and !window_status.is_empty():
        if window_status.get("available", false):
            var cutoff_minutes = int(window_status.get("minutes_until_cutoff", 0))
            if cutoff_minutes > 0:
                parts.append("Window %s" % _format_duration(cutoff_minutes))
        else:
            var resume_minutes = int(window_status.get("resumes_in_minutes", 0))
            if resume_minutes > 0:
                parts.append("Back %s" % _format_duration(resume_minutes))
    var weather_text = _summarize_weather_forecast(result.get("weather_forecast", {}))
    if weather_text != "":
        parts.append(weather_text)
    var zombie_text = _summarize_zombie_forecast(result.get("zombie_forecast", {}))
    if zombie_text != "":
        parts.append(zombie_text)
    var wolf_text = _summarize_wolf_forecast(result.get("wolf_forecast", {}))
    if wolf_text != "":
        parts.append(wolf_text)
    return "Recon -> %s" % " | ".join(parts)

func _show_lure_popup(result: Dictionary):
    if action_popup_panel == null:
        return
    var threat = String(result.get("threat", "zombies"))
    if threat == "wolves":
        var wolves_lines: PackedStringArray = []
        var success = result.get("success", false)
        wolves_lines.append("Outcome: %s" % ("Cleared" if success else "Stayed"))
        var chance_percent = int(round(result.get("chance", GameManager.WOLF_LURE_SUCCESS_CHANCE) * 100.0))
        wolves_lines.append("Chance: %d%%" % clamp(chance_percent, 0, 100))
        wolves_lines.append("Roll: %.2f" % float(result.get("roll", 1.0)))

        var cost_lines: PackedStringArray = []
        var calories = int(round(result.get("calories_spent", LURE_CALORIE_COST)))
        if calories > 0:
            cost_lines.append("Calories: -%d" % calories)
        var minutes = int(result.get("minutes_required", result.get("minutes_spent", 0)))
        if minutes > 0:
            cost_lines.append("Duration: %s" % _format_duration(minutes))
        var ended_at = String(result.get("ended_at_time", ""))
        if ended_at != "":
            cost_lines.append("Ended: %s" % ended_at)

        action_popup_panel.show_sections("Lure Report", [
            {
                "title": "Wolves",
                "lines": wolves_lines
            },
            {
                "title": "Costs",
                "lines": cost_lines
            }
        ])
        return
    var total = int(result.get("lure_attempted", result.get("zombies_prevented", 0)))
    var diverted = int(result.get("zombies_prevented", 0))
    if total < diverted:
        total = diverted
    var stayed = int(result.get("lure_failed", max(total - diverted, 0)))
    stayed = max(stayed, 0)
    var tower_now = int(result.get("zombies_at_tower", zombie_system.get_active_zombies() if zombie_system else 0))
    var injury: Dictionary = result.get("injury_report", {})
    var damage = float(injury.get("total_damage", injury.get("damage", 0.0)))
    var health_after = float(injury.get("health_after", _get_player_health()))
    var triggered_successes = int(injury.get("triggered_successes", 0))
    var triggered_failures = int(injury.get("triggered_failures", 0))

    var tower_lines: PackedStringArray = []
    tower_lines.append("Undead at tower: %d" % max(tower_now, 0))

    var lure_lines: PackedStringArray = []
    lure_lines.append("Total targeted: %d" % max(total, 0))
    lure_lines.append("Diverted: %d" % max(diverted, 0))
    lure_lines.append("Stayed: %d" % stayed)

    var health_lines: PackedStringArray = []
    if damage > 0.0:
        health_lines.append("Damage taken: %d" % int(round(damage)))
        if triggered_successes > 0 or triggered_failures > 0:
            var detail_parts: PackedStringArray = []
            if triggered_successes > 0:
                detail_parts.append("%d from successes" % triggered_successes)
            if triggered_failures > 0:
                detail_parts.append("%d from failures" % triggered_failures)
            if !detail_parts.is_empty():
                health_lines.append("Hits: %s" % ", ".join(detail_parts))
    else:
        health_lines.append("Damage taken: 0")
    health_lines.append("Health now: %d%%" % int(round(health_after)))

    action_popup_panel.show_sections("Lure Report", [
        {
            "title": "Tower Status",
            "lines": tower_lines
        },
        {
            "title": "Lure Outcome",
            "lines": lure_lines
        },
        {
            "title": "Health Impact",
            "lines": health_lines
        }
    ])

func _show_fight_popup(result: Dictionary):
    if action_popup_panel == null or !result.get("success", false):
        return

    var outcome_lines: PackedStringArray = []
    if result.get("wolves_present", false):
        outcome_lines.append("Wolves: %s" % ("Driven off" if result.get("wolves_removed", false) else "Still nearby"))
    else:
        outcome_lines.append("Wolves: None")
    if result.get("zombies_present", false):
        outcome_lines.append("Undead: %s" % ("Cleared" if result.get("zombies_removed", true) else "Remain"))
    else:
        outcome_lines.append("Undead: None")

    var gear_lines: PackedStringArray = []
    gear_lines.append("Knife: %s" % ("Yes" if result.get("has_knife", false) else "No"))
    var ranged_ready = result.get("has_bow", false) and result.get("has_arrow", false)
    gear_lines.append("Bow+Arrow: %s" % ("Yes" if ranged_ready else "No"))

    var damage_lines: PackedStringArray = []
    var damage = int(round(result.get("damage_applied", result.get("damage_roll", 0))))
    damage_lines.append("Damage taken: %d" % max(damage, 0))
    damage_lines.append("Health now: %d%%" % int(round(result.get("health_after", _get_player_health()))))

    var stats_lines: PackedStringArray = []
    var rest_spent = int(round(result.get("rest_spent_percent", 0.0)))
    if rest_spent > 0:
        stats_lines.append("Rest: -%d%%" % rest_spent)
    var calories = int(round(result.get("calories_spent", FIGHT_BACK_CALORIE_COST)))
    if calories > 0:
        stats_lines.append("Calories: -%d" % calories)
    var minutes = int(result.get("minutes_required", result.get("minutes_spent", 0)))
    if minutes > 0:
        stats_lines.append("Duration: %s" % _format_duration(minutes))

    action_popup_panel.show_sections("Fight Back Report", [
        {
            "title": "Outcome",
            "lines": outcome_lines
        },
        {
            "title": "Gear",
            "lines": gear_lines
        },
        {
            "title": "Injury",
            "lines": damage_lines
        },
        {
            "title": "Costs",
            "lines": stats_lines
        }
    ])

func _show_trap_injury_popup(injury: Dictionary):
    if action_popup_panel == null:
        return
    var damage = float(injury.get("damage", injury.get("total_damage", 0.0)))
    if damage <= 0.0:
        return
    var health_after = float(injury.get("health_after", _get_player_health()))
    var options = PackedStringArray([
        "Ouch, you hurt your self setting a trap and take 10 damage.",
        "You got hurt setting that trap, Lose 10 Health."
    ])
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var index = options.size() - 1
    if options.size() > 0:
        index = rng.randi_range(0, options.size() - 1)
    var message = options[index] if options.size() > 0 else "Trap injury suffered."
    var lines: PackedStringArray = []
    lines.append(message)
    lines.append("Health now: %d%%" % int(round(health_after)))
    action_popup_panel.show_message("Trap Injury", lines)

func _show_recon_popup(result: Dictionary):
    if action_popup_panel == null:
        return
    var sections: Array = []
    var weather_lines = _build_weather_forecast_lines(result.get("weather_forecast", {}))
    if weather_lines.is_empty():
        weather_lines.append("No major changes detected.")
    sections.append({
        "title": "Weather (Next 6h)",
        "lines": weather_lines
    })
    var zombie_lines = _build_zombie_forecast_lines(result.get("zombie_forecast", {}))
    if zombie_lines.is_empty():
        zombie_lines.append("No waves detected.")
    sections.append({
        "title": "Zombie Activity",
        "lines": zombie_lines
    })
    var wolf_lines = _build_wolf_forecast_lines(result.get("wolf_forecast", {}))
    if wolf_lines.is_empty():
        wolf_lines.append("No packs within %dh." % RECON_OUTLOOK_HOURS)
    sections.append({
        "title": "Wolf Movements",
        "lines": wolf_lines
    })
    action_popup_panel.show_sections("Recon Outlook", sections)

func _build_weather_forecast_lines(forecast: Dictionary) -> PackedStringArray:
    var lines: PackedStringArray = []
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return lines
    var state = String(forecast.get("current_state", WeatherSystem.WEATHER_CLEAR))
    var label = weather_system.get_state_display_name_for(state) if weather_system else state.capitalize()
    var multiplier = weather_system.get_multiplier_for_state(state) if weather_system else 1.0
    lines.append("Now: %s (x%.2f)" % [label, multiplier])
    var events: Array = forecast.get("events", [])
    for event in events:
        if typeof(event) != TYPE_DICTIONARY:
            continue
        var minutes = int(event.get("minutes_ahead", 0))
        if minutes <= 0:
            continue
        var when = _format_forecast_eta(minutes)
        match String(event.get("type", "")):
            "start":
                var future_state = String(event.get("state", state))
                var future_label = weather_system.get_state_display_name_for(future_state) if weather_system else future_state.capitalize()
                var duration = int(event.get("duration_hours", event.get("hours_remaining", 0)))
                var text = "%s: %s" % [when, future_label]
                if duration > 0:
                    text += " (%dh)" % duration
                lines.append(text)
            "stop":
                lines.append("%s: Clears" % when)
            _:
                continue
    return lines

func _build_zombie_forecast_lines(forecast: Dictionary) -> PackedStringArray:
    var lines: PackedStringArray = []
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return lines
    var active_now = int(forecast.get("active_now", 0))
    if active_now > 0:
        lines.append("Now: %d nearby" % max(active_now, 0))
    var events: Array = forecast.get("events", [])
    for event in events:
        if typeof(event) != TYPE_DICTIONARY:
            continue
        var minutes = int(event.get("minutes_ahead", 0))
        if minutes <= 0:
            continue
        var when = _format_forecast_eta(minutes)
        var quantity = int(event.get("quantity", event.get("spawns", event.get("added", 0))))
        var clock_time = String(event.get("clock_time", ""))
        var text = "%s: %d approaching" % [when, max(quantity, 0)]
        if clock_time != "":
            text += " (%s)" % clock_time
        if String(event.get("type", "")) == "next_day_spawn":
            var day = int(event.get("day", forecast.get("current_day", 0) + 1))
            text += " (Day %d)" % day
        lines.append(text)
    return lines

func _build_wolf_forecast_lines(forecast: Dictionary) -> PackedStringArray:
    var lines: PackedStringArray = []
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return lines

    var events: Array = forecast.get("events", [])
    var active_entry: Dictionary = {}
    var next_arrival: Dictionary = {}

    for event in events:
        if typeof(event) != TYPE_DICTIONARY:
            continue
        var event_type = String(event.get("type", ""))
        match event_type:
            "active":
                active_entry = event.duplicate(true)
            "arrival":
                if next_arrival.is_empty() or int(event.get("minutes_ahead", 0)) < int(next_arrival.get("minutes_ahead", 2147483647)):
                    next_arrival = event.duplicate(true)

    if !active_entry.is_empty():
        var remaining = int(active_entry.get("minutes_remaining", 0))
        if remaining > 0:
            lines.append("Now: Outside (%s left)" % _format_duration(remaining))
        else:
            lines.append("Now: Outside (departing soon)")

    if !next_arrival.is_empty():
        var minutes = int(next_arrival.get("minutes_ahead", 0))
        var when = _format_forecast_eta(minutes)
        var duration = int(next_arrival.get("duration", next_arrival.get("scheduled_duration", next_arrival.get("end_minute", 0) - next_arrival.get("minute", 0))))
        var label = "%s: Arrive" % when
        if duration > 0:
            label += " (stay %s)" % _format_duration(duration)
        lines.append(label)

    return lines

func _format_forecast_eta(minutes: int) -> String:
    if minutes <= 0:
        return "Now"
    var total_minutes = max(minutes, 0)
    var hours = total_minutes / 60
    var mins = total_minutes % 60
    if hours > 0 and mins > 0:
        return "In %dh %dm" % [hours, mins]
    if hours > 0:
        return "In %dh" % hours
    return "In %dm" % mins

func _get_player_health() -> float:
    if game_manager == null:
        return 0.0
    var health_system = game_manager.get_health_system()
    if health_system == null:
        return 0.0
    return health_system.get_health()

func _summarize_weather_forecast(forecast: Dictionary) -> String:
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return "Weather data unavailable"

    var events: Array = forecast.get("events", [])
    var fragments: PackedStringArray = []

    if events.is_empty():
        var current_state = String(forecast.get("current_state", WeatherSystem.WEATHER_CLEAR))
        fragments.append("Steady %s" % _format_weather_state_label(current_state))
    else:
        for event in events:
            if typeof(event) != TYPE_DICTIONARY:
                continue
            var type = String(event.get("type", ""))
            var minutes = int(event.get("minutes_ahead", 0))
            var time_text = "Now" if minutes == 0 else _format_duration(minutes)
            match type:
                "start":
                    var state = String(event.get("state", WeatherSystem.WEATHER_SPRINKLING))
                    fragments.append("%s -> %s" % [time_text, _format_weather_state_label(state)])
                "stop":
                    fragments.append("%s -> Clear" % time_text)
                "ongoing":
                    var state = String(event.get("state", forecast.get("current_state", WeatherSystem.WEATHER_CLEAR)))
                    var hours_left = int(event.get("hours_remaining", 0))
                    if hours_left > 0:
                        fragments.append("Now -> %s (%dh left)" % [_format_weather_state_label(state), max(hours_left, 0)])
                    else:
                        fragments.append("Now -> %s" % _format_weather_state_label(state))

    if fragments.is_empty():
        return "Weather steady"
    return "Weather: %s" % " / ".join(fragments)

func _summarize_zombie_forecast(forecast: Dictionary) -> String:
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return ""

    var fragments: PackedStringArray = []
    var active_now = int(forecast.get("active_now", 0))
    if active_now > 0:
        fragments.append("%d nearby" % max(active_now, 0))

    var events: Array = forecast.get("events", [])
    if events.is_empty():
        if fragments.is_empty():
            var horizon = int(forecast.get("minutes_horizon", RECON_OUTLOOK_HOURS * 60))
            fragments.append("Quiet %dh" % max(int(round(horizon / 60.0)), 0))
    else:
        for event in events:
            if typeof(event) != TYPE_DICTIONARY:
                continue
            var spawns = int(event.get("spawns", 0))
            var minutes = int(event.get("minutes_ahead", forecast.get("minutes_horizon", 0)))
            var time_text = "Now" if minutes == 0 else _format_duration(minutes)
            var clock_time = String(event.get("clock_time", ""))
            if clock_time != "":
                time_text = clock_time
            var event_type = String(event.get("type", ""))
            if event_type == "next_day_spawn" and clock_time != "":
                time_text = "Next day %s" % clock_time
            elif event_type == "next_day_spawn":
                time_text = "Next day %s" % time_text
            if spawns > 0:
                fragments.append("%s -> %d arrive" % [time_text, max(spawns, 0)])
            else:
                fragments.append("%s -> No wave" % time_text)

    if fragments.is_empty():
        return "Zombies: Quiet"
    return "Zombies: %s" % " / ".join(fragments)

func _summarize_wolf_forecast(forecast: Dictionary) -> String:
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return ""

    var events: Array = forecast.get("events", [])
    var active_entry: Dictionary = {}
    var next_arrival: Dictionary = {}

    for event in events:
        if typeof(event) != TYPE_DICTIONARY:
            continue
        var event_type = String(event.get("type", ""))
        match event_type:
            "active":
                active_entry = event.duplicate(true)
            "arrival":
                if next_arrival.is_empty() or int(event.get("minutes_ahead", 0)) < int(next_arrival.get("minutes_ahead", 2147483647)):
                    next_arrival = event.duplicate(true)

    if !active_entry.is_empty():
        var remaining = int(active_entry.get("minutes_remaining", 0))
        var window = "Now"
        if remaining > 0:
            window = "%s left" % _format_duration(remaining)
        return "Wolves: Outside (%s)" % window

    if !next_arrival.is_empty():
        var minutes = int(next_arrival.get("minutes_ahead", 0))
        var arrival_text = "Now" if minutes <= 0 else _format_duration(minutes)
        var duration = int(next_arrival.get("duration", next_arrival.get("scheduled_duration", next_arrival.get("end_minute", 0) - next_arrival.get("minute", 0))))
        if duration > 0:
            return "Wolves: Arrive %s (stay %s)" % [arrival_text, _format_duration(duration)]
        return "Wolves: Arrive %s" % arrival_text

    return "Wolves: No activity"

func _format_trap_deploy_result(result: Dictionary) -> String:
    var parts: PackedStringArray = []
    parts.append("Break %d%%" % TRAP_BREAK_PERCENT)
    var rest_spent = float(result.get("rest_spent_percent", TRAP_ENERGY_COST_PERCENT))
    if rest_spent > 0.0:
        parts.append("-%s%% rest" % _format_percent_value(rest_spent))
    var calories = int(round(result.get("calories_spent", TRAP_CALORIE_COST)))
    if calories > 0:
        parts.append("-%d cal" % calories)
    var stock_after = int(result.get("trap_stock_after", 0))
    parts.append("Stock %d" % max(stock_after, 0))
    var ended_at = String(result.get("ended_at_time", ""))
    if ended_at != "":
        parts.append("End %s" % ended_at)
    return "Trap armed -> %s" % " | ".join(parts)

func _format_trap_trigger_result(state: Dictionary) -> String:
    var parts: PackedStringArray = []
    var kills = int(state.get("kills", 1))
    parts.append("Killed %d" % max(kills, 0))
    var broke = state.get("broken", false)
    if broke:
        parts.append("Trap broke (%d%%)" % TRAP_BREAK_PERCENT)
    else:
        parts.append("Trap intact")
        var stock_after = int(state.get("trap_stock_after", 0))
        parts.append("Stock %d" % max(stock_after, 0))
    var time_text = String(state.get("last_kill_time", ""))
    if time_text != "":
        parts.append(time_text)
    return "Trap triggered -> %s" % " | ".join(parts)

func _format_snare_place_result(result: Dictionary) -> String:
    var parts: PackedStringArray = []
    var rest_spent = float(result.get("rest_spent_percent", SNARE_PLACE_REST_COST_PERCENT))
    if rest_spent > 0.0:
        parts.append("-%s%% rest" % _format_percent_value(rest_spent))
    var calories = int(round(result.get("calories_spent", SNARE_PLACE_CALORIE_COST)))
    if calories > 0:
        parts.append("-%d cal" % calories)
    var stock_after = int(result.get("snare_stock_after", 0))
    parts.append("Stock %d" % max(stock_after, 0))
    var deployed = int(result.get("total_deployed", 0))
    if deployed > 0:
        parts.append("Deployed %d" % deployed)
    var ended_at = String(result.get("ended_at_time", ""))
    if ended_at != "":
        parts.append("End %s" % ended_at)
    return "Snare placed -> %s" % " | ".join(parts)

func _format_snare_check_result(result: Dictionary) -> String:
    var parts: PackedStringArray = []
    var animals: Array = result.get("animals_collected", [])
    var count = int(result.get("animals_found", animals.size()))
    parts.append("Collected %d" % max(count, 0))
    if !animals.is_empty():
        var tally: Dictionary = {}
        for entry in animals:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            var label = String(entry.get("label", entry.get("id", "Game")))
            tally[label] = int(tally.get(label, 0)) + 1
        var loot: PackedStringArray = []
        for label in tally.keys():
            loot.append("%s x%d" % [label, int(tally[label])])
        if !loot.is_empty():
            parts.append("Loot %s" % ", ".join(loot))
    var food_units = float(result.get("food_units_gained", 0.0))
    if food_units > 0.0:
        parts.append("+%s food" % _format_food(food_units))
    var rest_spent = float(result.get("rest_spent_percent", SNARE_CHECK_REST_COST_PERCENT))
    if rest_spent > 0.0:
        parts.append("-%s%% rest" % _format_percent_value(rest_spent))
    var calories = int(round(result.get("calories_spent", SNARE_CHECK_CALORIE_COST)))
    if calories > 0:
        parts.append("-%d cal" % calories)
    var snare_state: Dictionary = result.get("snare_state", {})
    if typeof(snare_state) == TYPE_DICTIONARY and !snare_state.is_empty():
        var waiting = int(snare_state.get("animals_ready", 0))
        parts.append("Waiting %d" % max(waiting, 0))
    return "Snare check -> %s" % " | ".join(parts)

func _get_minutes_left_today() -> int:
    if time_system:
        return time_system.get_minutes_until_daybreak()
    return max_sleep_hours * 60

func _on_time_system_changed(_a = null, _b = null):
    _refresh_display()

func _format_duration(minutes: int) -> String:
    minutes = max(minutes, 0)
    var hours = minutes / 60
    var mins = minutes % 60
    if hours > 0 and mins > 0:
        return "%dh %02dm" % [hours, mins]
    elif hours > 0:
        return "%dh" % hours
    else:
        return "%dm" % mins

func _format_hours_value(hours: float) -> String:
    hours = max(hours, 0.0)
    var text = "%.2f" % hours
    while text.ends_with("0") and text.find(".") != -1:
        text = text.substr(0, text.length() - 1)
    if text.ends_with("."):
        text = text.substr(0, text.length() - 1)
    return text

func _format_daybreak_warning(minutes_available: int) -> String:
    return "Daybreak soon (Left %s)" % _format_duration(minutes_available)

func _set_forging_feedback(text: String, state: String):
    _forging_feedback_state = state
    if state == "result":
        _set_action_result("forging", text, true)
    else:
        _set_action_default("forging", text, true)
    _refresh_info_stats_if_selected("forging")

func _lock_forging_feedback():
    _forging_feedback_locked = true
    call_deferred("_unlock_forging_feedback")

func _unlock_forging_feedback():
    _forging_feedback_locked = false

func _set_lead_feedback(text: String, state: String):
    _lead_feedback_state = state
    if state == "result":
        _set_action_result("lead", text, true)
    else:
        _set_action_default("lead", text, true)

func _lock_lead_feedback():
    _lead_feedback_locked = true
    call_deferred("_unlock_lead_feedback")

func _unlock_lead_feedback():
    _lead_feedback_locked = false

func _open_menu():
    if _menu_open:
        return
    _menu_open = true
    _refresh_display()
    visible = true

func _close_menu():
    if !_menu_open and !visible:
        return
    _menu_open = false
    visible = false

func _setup_meal_size_options():
    if !is_instance_valid(meal_size_option):
        return
    meal_size_option.clear()
    for option in MEAL_OPTIONS:
        var idx = meal_size_option.item_count
        meal_size_option.add_item(option.get("label", option.get("display", "Meal")))
        meal_size_option.set_item_metadata(idx, option.get("key", "normal"))
        if option.get("key", "normal") == selected_meal_key:
            meal_size_option.select(idx)
    if meal_size_option.selected == -1 and meal_size_option.item_count > 0:
        meal_size_option.select(0)
        selected_meal_key = meal_size_option.get_item_metadata(0)
    _update_meal_summary()

func _update_sleep_summary():
    if !is_instance_valid(sleep_summary_label):
        return

    var lines: PackedStringArray = []
    lines.append("+%d%% rest/hr | -%d cal/hr" % [SLEEP_PERCENT_PER_HOUR, SleepSystem.CALORIES_PER_SLEEP_HOUR])
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)

    var minutes_remaining = max(_cached_minutes_remaining, 0)

    if selected_hours > 0:
        var planned_minutes = int(ceil(selected_hours * 60.0 * multiplier))
        var minutes_available = max(minutes_remaining, 0)
        var minutes_applied = min(planned_minutes, minutes_available)
        lines.append("%dh queued (%s)" % [selected_hours, _format_duration(planned_minutes)])
        if minutes_applied > 0:
            var applied_hours = float(minutes_applied) / (60.0 * multiplier)
            var rest_gain = applied_hours * float(SLEEP_PERCENT_PER_HOUR)
            lines.append("%sh usable | +%s%% rest" % [_format_hours_value(applied_hours), _format_percent_value(rest_gain)])
            if minutes_applied < planned_minutes:
                var trimmed = planned_minutes - minutes_applied
                if trimmed > 0:
                    lines.append("Dawn trims %s" % _format_duration(trimmed))
            if time_system:
                lines.append("Ends %s" % time_system.get_formatted_time_after(minutes_applied))
        else:
            lines.append("No time before dawn")
    else:
        if minutes_remaining > 0:
            var max_hours_today = int(ceil(minutes_remaining / (60.0 * multiplier))) if minutes_remaining > 0 else 0
            max_hours_today = min(max_hours_today, max_sleep_hours)
            if max_hours_today > 0:
                lines.append("Plan up to %dh today" % max_hours_today)
            else:
                lines.append("No time before dawn")
        else:
            lines.append("No time before dawn")

    var summary = " | ".join(lines)
    sleep_summary_label.text = summary
    _set_action_default("sleep", summary, true)

func _update_camp_search_summary():
    if !is_instance_valid(camp_search_summary_label):
        return

    var summary = _format_camp_search_ready()
    camp_search_summary_label.text = summary
    _set_action_default("camp_search", summary, true)

func _update_hunt_summary():
    if !is_instance_valid(hunt_summary_label):
        return

    var ready = false
    if game_manager:
        var status = game_manager.get_hunt_status()
        var bow_stock = int(status.get("bow_stock", 0))
        var arrow_stock = int(status.get("arrow_stock", 0))
        var zombies = int(status.get("zombies_nearby", 0))
        ready = bow_stock > 0 and arrow_stock > 0 and zombies <= 0
    var summary = _format_hunt_ready()
    hunt_summary_label.text = summary
    _set_action_default("hunt", summary, true)
    if is_instance_valid(hunt_select_button):
        hunt_select_button.disabled = !ready

func _update_meal_summary():
    if !is_instance_valid(meal_summary_label):
        return
    var option = _resolve_meal_option(selected_meal_key)
    var food_units = option.get("food_units", 1.0)
    var calories = int(round(food_units * CALORIES_PER_FOOD_UNIT))
    var lines: PackedStringArray = []
    lines.append("%s meal -> -%s food / -%d cal" % [option.get("display", selected_meal_key.capitalize()), _format_food(food_units), calories])
    if inventory_system:
        lines.append("Stock: %s food" % _format_food(inventory_system.get_total_food_units()))
    else:
        lines.append("Inventory offline")
    var summary = "\n".join(lines)
    meal_summary_label.text = summary
    _set_action_default("meal", summary)
    _refresh_info_stats_if_selected("meal")

func _update_fishing_summary():
    if !is_instance_valid(fishing_summary_label):
        return

    var parts: PackedStringArray = []
    parts.append("%d rolls @ %d%%" % [FISHING_ROLLS_PER_HOUR, FISHING_SUCCESS_PERCENT])
    parts.append("Sizes S50%/M35%/L15%")
    parts.append("Energy -%d%% / +%d cal burn" % [int(round(FISHING_REST_COST_PERCENT)), int(round(FISHING_CALORIE_COST))])
    parts.append("%d%% grub loss" % FISHING_GRUB_LOSS_PERCENT)

    var ready = true
    var rod_stock = 0
    var grub_stock = 0
    if inventory_system:
        rod_stock = inventory_system.get_item_count("fishing_rod")
        grub_stock = inventory_system.get_item_count("grubs")
        parts.append("Rod %d" % rod_stock)
        parts.append("Grubs %d" % grub_stock)
        ready = rod_stock > 0 and grub_stock > 0
    else:
        parts.append("Inventory offline")
        ready = false

    if !ready and inventory_system:
        var needs: PackedStringArray = []
        if rod_stock <= 0:
            needs.append("Fishing Rod")
        if grub_stock <= 0:
            needs.append("Grub")
        if !needs.is_empty():
            parts.append("Need %s" % " & ".join(needs))

    var summary = " | ".join(parts)
    fishing_summary_label.text = summary
    _set_action_default("fishing", summary, true)
    if is_instance_valid(fishing_select_button):
        fishing_select_button.disabled = !ready

func _update_recon_summary():
    if !is_instance_valid(recon_summary_label):
        return
    var parts: PackedStringArray = []
    parts.append("%dh outlook" % RECON_OUTLOOK_HOURS)
    parts.append("-%d cal" % int(round(GameManager.RECON_CALORIE_COST)))
    var window_status: Dictionary = {}
    if game_manager:
        window_status = game_manager.get_recon_window_status()
    var recon_available = window_status.get("available", false)
    if recon_available:
        var cutoff_clock = String(window_status.get("cutoff_at", "12:00 AM"))
        if cutoff_clock != "":
            parts.append("Cutoff %s" % cutoff_clock)
        else:
            var cutoff_minutes = int(window_status.get("minutes_until_cutoff", GameManager.RECON_WINDOW_END_MINUTE))
            parts.append("Cutoff %s" % _format_duration(cutoff_minutes))
    else:
        if window_status.is_empty():
            parts.append("Recon offline")
        else:
            var resume_minutes = int(window_status.get("resumes_in_minutes", 0))
            var resume_label = String(window_status.get("resumes_at", "6:00 AM"))
            if resume_minutes > 0:
                parts.append("Back %s" % _format_duration(resume_minutes))
            elif resume_label != "":
                parts.append("Back at %s" % resume_label)
            else:
                parts.append("Recon offline")
    if time_system:
        parts.append("Dawn %s" % _format_duration(time_system.get_minutes_until_daybreak()))
    if zombie_system and zombie_system.has_active_zombies():
        parts.append("%d undead near" % zombie_system.get_active_zombies())
    var summary = " | ".join(parts)
    recon_summary_label.text = summary
    _set_action_default("recon", summary, true)
    if is_instance_valid(recon_select_button):
        recon_select_button.disabled = !recon_available

func _update_fight_summary():
    if !is_instance_valid(fight_summary_label):
        return
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(FIGHT_BACK_HOURS * 60.0 * multiplier))
    var threat_parts: PackedStringArray = []
    var wolves_active = bool(_wolf_state.get("active", false)) or bool(_wolf_state.get("present", false))
    if wolves_active:
        var remaining = int(_wolf_state.get("minutes_remaining", 0))
        var window = "now"
        if remaining > 0:
            window = _format_duration(remaining)
        threat_parts.append("Wolves %s" % window)
    if zombie_system and zombie_system.get_active_zombies() > 0:
        threat_parts.append("Undead %d" % zombie_system.get_active_zombies())
    if threat_parts.is_empty():
        threat_parts.append("No outside threats")

    var parts: PackedStringArray = []
    parts.append(" | ".join(threat_parts))
    parts.append("%s sprint" % _format_duration(minutes))
    parts.append("-%d%% rest | -%d cal" % [int(round(FIGHT_BACK_REST_COST_PERCENT)), int(round(FIGHT_BACK_CALORIE_COST))])

    var has_knife = inventory_system and inventory_system.get_item_count(GameManager.CRAFTED_KNIFE_ID) > 0
    var has_bow = inventory_system and inventory_system.get_item_count("bow") > 0
    var has_arrow = inventory_system and inventory_system.get_item_count("arrow") > 0
    var ready = (wolves_active or (zombie_system and zombie_system.get_active_zombies() > 0)) and (has_knife or (has_bow and has_arrow))
    if ready:
        var gear: PackedStringArray = []
        if has_knife:
            gear.append("Knife")
        if has_bow and has_arrow:
            gear.append("Bow+Arrow")
        if !gear.is_empty():
            parts.append("Gear: %s" % ", ".join(gear))
    else:
        parts.append("Need Knife or Bow+Arrow")

    var summary = "Fight Back -> %s" % " | ".join(parts)
    fight_summary_label.text = summary
    _set_action_default("fight_back", summary, true)
    if is_instance_valid(fight_select_button):
        fight_select_button.disabled = !ready

func _update_repair_summary():
    if !is_instance_valid(repair_summary_label):
        return
    var lines: PackedStringArray = []
    lines.append("Repair -> +%s hp" % _format_health_value(TowerHealthSystem.REPAIR_HEALTH_PER_ACTION))
    lines.append("+10% rest / -350 cal")
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    var minutes = int(ceil(60.0 * max(multiplier, 0.01)))
    lines.append("Takes %s" % _format_duration(minutes))
    if inventory_system:
        var wood_stock = inventory_system.get_item_count("wood")
        lines.append("Needs 1 wood (Stock %d)" % wood_stock)
    else:
        lines.append("Needs 1 wood")
    if tower_health_system:
        lines.append("Tower %s" % _format_health_snapshot(tower_health_system.get_health()))
    var summary = " | ".join(lines)
    repair_summary_label.text = summary
    _set_action_default("repair", summary)
func _update_reinforce_summary():
    if !is_instance_valid(reinforce_summary_label):
        return
    var lines: PackedStringArray = []
    lines.append("Reinforce -> +25 hp (cap 150)")
    lines.append("-20% rest / -450 cal")
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    var minutes = int(ceil(120.0 * max(multiplier, 0.01)))
    lines.append("Takes %s" % _format_duration(minutes))
    if inventory_system:
        var wood_stock = inventory_system.get_item_count("wood")
        var nail_stock = inventory_system.get_item_count("nails")
        lines.append("Needs 3 wood (Stock %d)" % wood_stock)
        lines.append("Needs 5 nails (Stock %d)" % nail_stock)
    else:
        lines.append("Needs 3 wood & 5 nails")
    if tower_health_system:
        lines.append("Tower %s" % _format_health_snapshot(tower_health_system.get_health()))
    var summary = " | ".join(lines)
    reinforce_summary_label.text = summary
    _set_action_default("reinforce", summary)

func _update_trap_summary():
    if !is_instance_valid(trap_summary_label):
        return
    var text: String
    if game_manager == null:
        text = "Trap offline"
    else:
        if _trap_state.is_empty():
            _trap_state = game_manager.get_trap_state()
        var active = _trap_state.get("active", false)
        if active:
            var fragments: PackedStringArray = []
            fragments.append("%d%% break" % TRAP_BREAK_PERCENT)
            var armed_time = String(_trap_state.get("deployed_at_time", ""))
            if armed_time != "":
                fragments.append(armed_time)
            text = "Armed (%s)" % " | ".join(fragments)
        else:
            var stock = inventory_system.get_item_count(TRAP_ITEM_ID) if inventory_system else 0
            if stock <= 0:
                text = "Need built trap (Stock 0)"
            else:
                text = "%.0fh | -%s%% rest | -%d cal" % [
                    TRAP_DEPLOY_HOURS,
                    _format_percent_value(TRAP_ENERGY_COST_PERCENT),
                    int(round(TRAP_CALORIE_COST))
                ]
    trap_summary_label.text = text
    _set_action_default("trap", text, true)

func _update_snare_place_summary():
    if !is_instance_valid(snare_place_summary_label):
        return
    var text: String
    if game_manager == null:
        text = "Snare placement offline"
    else:
        if _snare_state.is_empty():
            _snare_state = game_manager.get_snare_state()
        var stock = inventory_system.get_item_count(SNARE_ITEM_ID) if inventory_system else 0
        if stock <= 0:
            text = "Need Animal Snare (Stock 0)"
        else:
            var deployed = int(_snare_state.get("total_deployed", 0))
            var waiting = int(_snare_state.get("animals_ready", 0))
            var fragments: PackedStringArray = []
            fragments.append("%.1fh" % SNARE_PLACE_HOURS)
            fragments.append("-%s%% rest" % _format_percent_value(SNARE_PLACE_REST_COST_PERCENT))
            fragments.append("-%d cal" % int(round(SNARE_PLACE_CALORIE_COST)))
            fragments.append("Stock %d" % stock)
            if deployed > 0:
                fragments.append("Deployed %d" % deployed)
            if waiting > 0:
                fragments.append("Waiting %d" % waiting)
            text = " | ".join(fragments)
    snare_place_summary_label.text = text
    _set_action_default("snare_place", text, true)

func _update_snare_check_summary():
    if !is_instance_valid(snare_check_summary_label):
        return
    var text: String
    if game_manager == null:
        text = "Snare checks offline"
    else:
        if _snare_state.is_empty():
            _snare_state = game_manager.get_snare_state()
        var deployed = int(_snare_state.get("total_deployed", 0))
        if deployed <= 0:
            text = "Requires snares placed"
        else:
            var waiting = int(_snare_state.get("animals_ready", 0))
            var fragments: PackedStringArray = []
            fragments.append("%.1fh" % SNARE_CHECK_HOURS)
            fragments.append("-%s%% rest" % _format_percent_value(SNARE_CHECK_REST_COST_PERCENT))
            fragments.append("-%d cal" % int(round(SNARE_CHECK_CALORIE_COST)))
            if waiting > 0:
                fragments.append("Animals %d" % waiting)
            else:
                fragments.append("No animals waiting")
            text = " | ".join(fragments)
    snare_check_summary_label.text = text
    _set_action_default("snare_check", text, true)

func _update_butcher_summary():
    if !is_instance_valid(butcher_summary_label):
        return

    var ready = false
    if game_manager:
        var status = game_manager.get_butcher_status()
        var knife_stock = int(status.get("knife_stock", 0))
        var fire_lit = status.get("fire_lit", false)
        var processable = float(status.get("processable_food_units", 0.0))
        ready = knife_stock > 0 and fire_lit and processable > 0.0
    var summary = _format_butcher_ready()
    butcher_summary_label.text = summary
    _set_action_default("butcher", summary, true)
    if is_instance_valid(butcher_select_button):
        butcher_select_button.disabled = !ready


func _update_cook_whole_summary():
    if !is_instance_valid(cook_whole_summary_label):
        return

    var ready = false
    if game_manager:
        var status = game_manager.get_cook_whole_status()
        var fire_lit = status.get("fire_lit", false)
        var processable = float(status.get("processable_food_units", 0.0))
        ready = fire_lit and processable > 0.0
    var summary = _format_cook_whole_ready()
    cook_whole_summary_label.text = summary
    _set_action_default("cook_whole", summary, true)
    if is_instance_valid(cook_whole_select_button):
        cook_whole_select_button.disabled = !ready


func _resolve_meal_option(key: String) -> Dictionary:
    var normalized = key.to_lower()
    for option in MEAL_OPTIONS:
        if option.get("key", "") == normalized:
            return option
    return MEAL_OPTIONS[1]

func _format_food(value: float) -> String:
    if is_equal_approx(value, round(value)):
        return "%d" % int(round(value))
    return "%.1f" % value

func _get_action_energy_text(action: String) -> String:
    match action:
        "sleep":
            var per_hour = SLEEP_PERCENT_PER_HOUR
            if selected_hours > 0:
                var planned = selected_hours * per_hour
                return "+%s%% planned (%d%%/hr)" % [_format_percent_value(planned), per_hour]
            return "+%d%% per hr" % per_hour
        "forging":
            return "-%s%% cost" % _format_percent_value(FORGING_REST_COST_PERCENT)
        "camp_search":
            return "-%s%% cost" % _format_percent_value(CAMP_SEARCH_REST_COST_PERCENT)
        "hunt":
            return "-%s%% cost" % _format_percent_value(HUNT_REST_COST_PERCENT)
        "fishing":
            return "-%s%% cost" % _format_percent_value(FISHING_REST_COST_PERCENT)
        "recon":
            return "0% (Focus only)"
        "lead":
            if _lure_status.get("available", false):
                return "0% (Lure intercept)"
            return "-%s%% cost" % _format_percent_value(15.0)
        "fight_back":
            return "-%s%% cost" % _format_percent_value(FIGHT_BACK_REST_COST_PERCENT)
        "trap":
            return "-%s%% cost" % _format_percent_value(TRAP_ENERGY_COST_PERCENT)
        "snare_place":
            return "-%s%% cost" % _format_percent_value(SNARE_PLACE_REST_COST_PERCENT)
        "snare_check":
            return "-%s%% cost" % _format_percent_value(SNARE_CHECK_REST_COST_PERCENT)
        "meal":
            return "0% (Energy neutral)"
        "butcher":
            return "-%s%% cost" % _format_percent_value(BUTCHER_REST_COST_PERCENT)
        "cook_whole":
            return "-%s%% cost" % _format_percent_value(COOK_WHOLE_REST_COST_PERCENT)
        "repair":
            return "+%s%% bonus" % _format_percent_value(10.0)
        "reinforce":
            return "-%s%% cost" % _format_percent_value(20.0)
        _:
            return "0%"

func _get_action_calorie_text(action: String) -> String:
    match action:
        "sleep":
            var per_hour = SleepSystem.CALORIES_PER_SLEEP_HOUR
            if selected_hours > 0:
                var planned = int(round(selected_hours * per_hour))
                return "+%d burn planned (+%d/hr)" % [planned, per_hour]
            return "+%d burn/hr" % per_hour
        "forging":
            return "+%d burn" % int(round(FORGING_CALORIE_COST))
        "camp_search":
            return "+%d burn" % int(round(CAMP_SEARCH_CALORIE_COST))
        "hunt":
            return "+%d burn" % int(round(HUNT_CALORIE_COST))
        "fishing":
            return "+%d burn" % int(round(FISHING_CALORIE_COST))
        "recon":
            return "+%d burn" % int(round(GameManager.RECON_CALORIE_COST))
        "lead":
            if _lure_status.get("available", false):
                return "+%d burn" % int(round(GameManager.LURE_CALORIE_COST))
            return "Awake burn only"
        "fight_back":
            return "+%d burn" % int(round(FIGHT_BACK_CALORIE_COST))
        "trap":
            return "+%d burn" % int(round(TRAP_CALORIE_COST))
        "snare_place":
            return "+%d burn" % int(round(SNARE_PLACE_CALORIE_COST))
        "snare_check":
            return "+%d burn" % int(round(SNARE_CHECK_CALORIE_COST))
        "meal":
            var option = _resolve_meal_option(selected_meal_key)
            var food_units = float(option.get("food_units", 1.0))
            var calories = int(round(food_units * CALORIES_PER_FOOD_UNIT))
            return "-%d gain" % calories
        "butcher":
            return "+%d burn" % int(round(BUTCHER_CALORIE_COST))
        "cook_whole":
            return "+%d burn" % int(round(COOK_WHOLE_CALORIE_COST))
        "repair":
            return "+350 burn"
        "reinforce":
            return "+450 burn"
        _:
            return "Awake burn only"

func _get_fishing_size_data(size: String) -> Dictionary:
    var key = size.to_lower()
    for entry in FISHING_SIZE_TABLE:
        if String(entry.get("size", "")).to_lower() == key:
            return entry
    return {}

func _format_percent_value(value: float) -> String:
    var rounded = round(value * 10.0) / 10.0
    if is_equal_approx(rounded, round(rounded)):
        return "%d" % int(round(rounded))
    return "%.1f" % rounded

func _format_lead_ready(count: int) -> String:
    return "Lead Away -> %d%% per 🧟 (Have %d)" % [LEAD_AWAY_CHANCE_PERCENT, max(count, 0)]

func _format_lure_ready(status: Dictionary) -> String:
    var parts: PackedStringArray = []
    var quantity = int(status.get("quantity", 0))
    var minutes = int(status.get("minutes_remaining", 0))
    var eta = String(status.get("clock_time", ""))
    if eta == "":
        eta = _format_duration(minutes)
    parts.append("Lure -> %d inbound" % max(quantity, 1))
    parts.append("ETA %s" % eta)
    var calories = int(round(status.get("calorie_cost", LURE_CALORIE_COST)))
    if calories > 0:
        parts.append("-%d cal" % calories)
    var minutes_required = int(status.get("minutes_required", int(ceil(LURE_DURATION_HOURS * 60.0))))
    if minutes_required > 0:
        parts.append("Takes %s" % _format_duration(minutes_required))
    return " | ".join(parts)

func _format_lure_outside_window(status: Dictionary) -> String:
    var quantity = int(status.get("quantity", 0))
    var minutes = int(status.get("minutes_remaining", 0))
    var eta = String(status.get("clock_time", ""))
    if eta == "":
        eta = _format_duration(minutes)
    return "Lure -> %d arrive %s (beyond %dh window)" % [max(quantity, 1), eta, int(round(LURE_WINDOW_MINUTES / 60.0))]

func _format_lure_time_blocked(status: Dictionary) -> String:
    var minutes_required = int(status.get("minutes_required", int(ceil(LURE_DURATION_HOURS * 60.0))))
    var minutes_available = int(status.get("minutes_available", 0))
    return "Lure -> Need %s (Left %s)" % [_format_duration(minutes_required), _format_duration(minutes_available)]

func _format_lure_result(result: Dictionary) -> String:
    var ended_at = result.get("ended_at_time", "")
    var rest_spent = result.get("rest_spent_percent", 0.0)
    if result.get("success", false):
        var threat = String(result.get("threat", "zombies"))
        if threat == "wolves":
            var parts_wolves: PackedStringArray = []
            parts_wolves.append("Wolves %s" % ("cleared" if result.get("wolves_removed", false) else "stayed"))
            var chance_percent = int(round(result.get("chance", GameManager.WOLF_LURE_SUCCESS_CHANCE) * 100.0))
            parts_wolves.append("%d%% roll %.2f" % [clamp(chance_percent, 0, 100), float(result.get("roll", 1.0))])
            var calories = int(round(result.get("calories_spent", LURE_CALORIE_COST)))
            if calories > 0:
                parts_wolves.append("-%d cal" % calories)
            var duration = int(result.get("minutes_required", result.get("minutes_spent", 0)))
            if duration > 0:
                parts_wolves.append("Took %s" % _format_duration(duration))
            if rest_spent > 0.0:
                parts_wolves.append("-%d%% rest" % int(round(rest_spent)))
            if ended_at != "":
                parts_wolves.append("End %s" % ended_at)
            return "Lure -> %s" % " | ".join(parts_wolves)

        var diverted = int(result.get("zombies_prevented", 0))
        var clock = String(result.get("spawn_prevented_clock", ended_at))
        var calories = int(round(result.get("calories_spent", LURE_CALORIE_COST)))
        var duration = int(result.get("minutes_required", result.get("minutes_spent", 0)))
        var parts: PackedStringArray = []
        parts.append("Lured %d" % max(diverted, 0))
        if clock != "":
            parts.append("Intercept %s" % clock)
        if calories > 0:
            parts.append("-%d cal" % calories)
        if duration > 0:
            parts.append("Took %s" % _format_duration(duration))
        if rest_spent > 0.0:
            parts.append("-%d%% rest" % int(round(rest_spent)))
        return "Lure -> %s" % " | ".join(parts)

    var reason = String(result.get("reason", ""))
    match reason:
        "systems_unavailable":
            return "Lure offline"
        "no_target":
            return "Lure -> Recon required"
        "pending_cleared":
            return "Lure -> No wave scheduled"
        "spawn_mismatch":
            return "Lure -> Wave shifted"
        "no_quantity":
            return "Lure -> No undead inbound"
        "expired":
            return "Lure -> Wave already hit"
        "outside_window":
            return _format_lure_outside_window(result)
        "exceeds_day":
            return _format_lure_time_blocked(result)
        "day_mismatch":
            return "Lure -> Schedule changed"
        "minute_mismatch":
            return "Lure -> Timing changed"
        "no_pending_spawn":
            return "Lure -> No pending wave"
        "cancel_failed":
            return "Lure -> Could not divert"
        "wolves_stayed":
            var fragments: PackedStringArray = []
            var chance_percent = int(round(result.get("chance", GameManager.WOLF_LURE_SUCCESS_CHANCE) * 100.0))
            fragments.append("Wolves stayed (%d%%)" % clamp(chance_percent, 0, 100))
            fragments.append("Roll %.2f" % float(result.get("roll", 1.0)))
            var calories = int(round(result.get("calories_spent", LURE_CALORIE_COST)))
            if calories > 0:
                fragments.append("-%d cal" % calories)
            var duration = int(result.get("minutes_required", result.get("minutes_spent", 0)))
            if duration > 0:
                fragments.append("Took %s" % _format_duration(duration))
            if rest_spent > 0.0:
                fragments.append("-%d%% rest" % int(round(rest_spent)))
            if ended_at != "":
                fragments.append("End %s" % ended_at)
            return "Lure -> %s" % " | ".join(fragments)
        "chance_blocked":
            return "Lure -> Wolves resisted"
        "no_wolves":
            return "Lure -> Wolves already gone"
        _:
            return "Lure failed"

func _format_lead_result(result: Dictionary) -> String:
    var action = String(result.get("action", "lead_away"))
    if action == "lure":
        return _format_lure_result(result)
    var rest_spent = result.get("rest_spent_percent", 0.0)
    var ended_at = result.get("ended_at_time", "")
    if result.get("success", false):
        var removed = int(result.get("removed", 0))
        var remaining = int(result.get("remaining", 0))
        var chance = float(result.get("chance", 0.0)) * 100.0
        var parts: PackedStringArray = []
        parts.append("Removed %d" % max(removed, 0))
        parts.append("Remain %d" % max(remaining, 0))
        parts.append("%.0f%% each" % chance)
        if rest_spent > 0.0:
            parts.append("-%d%% rest" % int(round(rest_spent)))
        if ended_at != "":
            parts.append("End %s" % ended_at)
        return "Lead Away -> %s" % " | ".join(parts)

    var reason = result.get("reason", "")
    match reason:
        "systems_unavailable":
            return "Lead Away offline"
        "no_zombies":
            return "No zombies nearby"
        "exceeds_day":
            var minutes_available = result.get("minutes_available", 0)
            return _format_daybreak_warning(minutes_available)
        "zombies_stayed":
            var rolls = int(result.get("rolls", 0))
            var chance = float(result.get("chance", 0.0)) * 100.0
            var fragments: PackedStringArray = []
            fragments.append("No takers (%d @ %.0f%%)" % [max(rolls, 0), chance])
            if rest_spent > 0.0:
                fragments.append("-%d%% rest" % int(round(rest_spent)))
            if ended_at != "":
                fragments.append("End %s" % ended_at)
            return "Lead Away -> %s" % " | ".join(fragments)
        _:
            var fallback = "Lead Away failed"
            if rest_spent > 0.0:
                fallback += " | -%d%% rest" % int(round(rest_spent))
            if ended_at != "":
                fallback += " | End %s" % ended_at
            return fallback

func _format_fight_result(result: Dictionary) -> String:
    if result.get("success", false):
        var parts: PackedStringArray = []
        if result.get("wolves_present", false):
            parts.append("Wolves %s" % ("cleared" if result.get("wolves_removed", false) else "lingered"))
        if result.get("zombies_present", false):
            parts.append("Undead %s" % ("cleared" if result.get("zombies_removed", true) else "lingered"))
        var damage = int(round(result.get("damage_applied", result.get("damage_roll", 0))))
        parts.append("Damage %d" % max(damage, 0))
        var rest_spent = result.get("rest_spent_percent", 0.0)
        if rest_spent > 0.0:
            parts.append("-%d%% rest" % int(round(rest_spent)))
        var calories = int(round(result.get("calories_spent", FIGHT_BACK_CALORIE_COST)))
        if calories > 0:
            parts.append("-%d cal" % calories)
        return "Fight Back -> %s" % " | ".join(parts)

    var reason = String(result.get("reason", "failed"))
    match reason:
        "systems_unavailable":
            return "Fight Back offline"
        "no_threat":
            return "Fight Back -> No threats outside"
        "no_weapons":
            return "Fight Back -> Need Knife or Bow+Arrow"
        "exceeds_day":
            var minutes_available = int(result.get("minutes_available", 0))
            return _format_daybreak_warning(minutes_available)
        "time_rejected":
            var minutes_available = int(result.get("minutes_available", 0))
            return _format_daybreak_warning(minutes_available)
        _:
            return "Fight Back failed"

func _format_health_value(value: float) -> String:
    if is_zero_approx(value - round(value)):
        return "%d" % int(round(value))
    return "%.1f" % value

func _format_health_snapshot(value: float) -> String:
    if tower_health_system == null:
        return "--"
    return "%s/%s" % [_format_health_value(value), _format_health_value(tower_health_system.get_max_health())]

func _format_weather_state_label(state: String) -> String:
    if weather_system:
        return weather_system.get_state_display_name_for(state)
    return state.capitalize()

func _on_inventory_food_total_changed(new_total: float):
    _update_meal_summary()
    _update_camp_search_summary()
    _update_hunt_summary()
    _update_butcher_summary()
    _update_cook_whole_summary()
    _update_snare_place_summary()
    _update_snare_check_summary()
    if _forging_feedback_locked:
        return
    if _forging_feedback_state == "offline":
        return
    _set_forging_feedback(_format_forging_ready(new_total), "ready")
func _on_inventory_item_changed(_item_id: String, _quantity_delta: int, _food_delta: float, _total_food_units: float):
    _update_fishing_summary()
    _update_repair_summary()
    _update_reinforce_summary()
    _update_trap_summary()
    _update_snare_place_summary()
    _update_snare_check_summary()
    _update_camp_search_summary()
    _update_hunt_summary()
    _update_butcher_summary()
    _update_cook_whole_summary()
    _update_fight_summary()
    if !_forging_feedback_locked and _forging_feedback_state != "offline" and inventory_system:
        _set_forging_feedback(_format_forging_ready(inventory_system.get_total_food_units()), "ready")


func _on_tower_health_changed(_new: float, _old: float):
    _update_repair_summary()
    _update_reinforce_summary()

func _on_lead_zombie_count_changed(count: int):
    _update_hunt_summary()
    _refresh_info_stats_if_selected("hunt")
    if _lead_feedback_locked:
        return
    if _lead_feedback_state == "offline" or _lead_feedback_state == "result":
        return
    _set_lead_feedback(_format_lead_ready(count), "status")
    _refresh_lead_feedback()
    _update_recon_summary()
    _update_fight_summary()
    _refresh_info_stats_if_selected("lead")

func _on_lure_status_changed(status: Dictionary):
    _lure_status = status.duplicate(true)
    _refresh_lead_feedback()
    _refresh_info_stats_if_selected("lead")

func _on_wolf_state_changed(state: Dictionary):
    _wolf_state = state.duplicate(true)
    _update_fight_summary()
    _refresh_info_stats_if_selected("fight_back")

func _on_trap_state_changed(_active: bool, state: Dictionary):
    _trap_state = state.duplicate(true)
    _update_trap_summary()
    var status = String(state.get("status", ""))
    if status == "triggered":
        _set_action_result("trap", _format_trap_trigger_result(state), true)
    _refresh_info_stats_if_selected("trap")

func _on_snare_state_changed(state: Dictionary):
    _snare_state = state.duplicate(true)
    _update_snare_place_summary()
    _update_snare_check_summary()
    _update_cook_whole_summary()
    _refresh_info_stats_if_selected("snare_place")
    _refresh_info_stats_if_selected("snare_check")
    _refresh_info_stats_if_selected("cook_whole")

func _on_hunt_stock_changed(_stock: Dictionary):
    _update_hunt_summary()
    _update_butcher_summary()
    _update_cook_whole_summary()
    _refresh_info_stats_if_selected("hunt")
    _refresh_info_stats_if_selected("butcher")
    _refresh_info_stats_if_selected("cook_whole")

func _on_wood_stove_state_changed(_state: Dictionary):
    _update_butcher_summary()
    _update_cook_whole_summary()
    _refresh_info_stats_if_selected("butcher")
    _refresh_info_stats_if_selected("cook_whole")

func _refresh_lead_feedback():
    if _lead_feedback_locked:
        return
    if _lead_feedback_state == "offline" or _lead_feedback_state == "result":
        return

    if _lure_status.get("available", false):
        _set_lead_feedback(_format_lure_ready(_lure_status), "status")
        return

    if _lure_status.get("scouted", false):
        var reason = String(_lure_status.get("reason", ""))
        match reason:
            "outside_window":
                _set_lead_feedback(_format_lure_outside_window(_lure_status), "status")
                return
            "exceeds_day":
                _set_lead_feedback(_format_lure_time_blocked(_lure_status), "status")
                return
            "pending_cleared":
                pass
            "spawn_mismatch":
                pass
            "no_quantity":
                pass
            "expired":
                pass

    if zombie_system:
        _set_lead_feedback(_format_lead_ready(zombie_system.get_active_zombies()), "status")
    else:
        _set_lead_feedback("Lead Away unavailable", "offline")

func _resolve_game_manager() -> GameManager:
    var tree = get_tree()
    if tree == null:
        push_warning("SceneTree unavailable, cannot resolve GameManager")
        return null

    var root = tree.get_root()
    if root == null:
        push_warning("Root node unavailable, cannot resolve GameManager")
        return null

    var candidate: Node = root.get_node_or_null("Main/GameManager")
    if candidate == null:
        var group_matches = tree.get_nodes_in_group("game_manager") if tree.has_group("game_manager") else []
        if group_matches.size() > 0:
            candidate = group_matches[0]

    if candidate is GameManager:
        return candidate

    if candidate:
        push_warning("GameManager node found but type mismatch: %s" % candidate.name)
    else:
        push_warning("GameManager node not found in scene tree")

    return null
