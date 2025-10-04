# This script helps debug any remaining startup issues
extends Node

func _ready():
	print("🔥 Fire Tower Survival - Godot Version Starting...")
	print("✅ Base Node system working")
	
	# Test that all custom classes can be instantiated
	test_systems()

func test_systems():
	print("Testing core systems...")
	
	try:
		var army_time = ArmyTimeSystem.new()
		print("✅ ArmyTimeSystem: OK")
	except:
		print("❌ ArmyTimeSystem: FAILED")
	
	try:
		var body_weight = BodyWeightSystem.new()
		print("✅ BodyWeightSystem: OK")
	except:
		print("❌ BodyWeightSystem: FAILED")
	
	try:
		var survival = SurvivalStats.new()
		print("✅ SurvivalStats: OK")
	except:
		print("❌ SurvivalStats: FAILED")
	
	try:
		var inventory = Inventory.new()
		print("✅ Inventory: OK")
	except:
		print("❌ Inventory: FAILED")
	
	try:
		var weather = WeatherSystem.new()
		print("✅ WeatherSystem: OK")
	except:
		print("❌ WeatherSystem: FAILED")
	
	print("🎮 System check complete!")

func try(callable: Callable):
	return callable.call()

func except():
	pass
