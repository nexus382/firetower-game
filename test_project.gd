# Quick test script to verify Godot project setup
extends SceneTree

func _init():
	print("Testing Fire Tower Survival Godot project...")
	
	# Test loading main systems
	var army_time = ArmyTimeSystem.new()
	var body_weight = BodyWeightSystem.new()
	var survival_stats = SurvivalStats.new()
	var inventory = Inventory.new()
	var weather = WeatherSystem.new()
	
	print("✅ All core systems loaded successfully!")
	print("Current time: %s" % army_time.get_display_time())
	print("Weight: %.1fkg (%s)" % [body_weight.current_weight, body_weight.get_weight_status()])
	print("Health: %.0f%%" % survival_stats.get_health_percentage() * 100)
	print("Weather: %s" % weather.current_weather)
	
	# Test inventory
	inventory.add_item("Wild Berries", 3)
	var food_items = inventory.get_food_items()
	print("Food in inventory: %s" % str(food_items))
	
	print("🎮 Project setup complete! Ready to run in Godot editor.")
	
	quit()
