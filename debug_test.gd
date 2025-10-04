extends SceneTree

func _init():
	print("🔥 Fire Tower Survival - Debug Test Starting...")

	# Test screen size calculation
	var viewport = get_root().get_viewport()
	var screen_size = viewport.get_visible_rect().size
	print("📺 Screen size: %s" % screen_size)

	# Calculate tower bounds (same as TowerManager)
	var tower_width = screen_size.x * 0.85
	var tower_height = screen_size.y * 0.85
	var tower_x = (screen_size.x - tower_width) / 2
	var tower_y = (screen_size.y - tower_height) / 2

	print("🏗️ Tower bounds: x=%d, y=%d, width=%d, height=%d" % [tower_x, tower_y, tower_width, tower_height])

	# Camera position and zoom calculation
	var camera_pos = Vector2(tower_x + tower_width / 2, tower_y + tower_height / 2)
	var zoom_x = screen_size.x / tower_width
	var zoom_y = screen_size.y / tower_height
	var camera_zoom = min(zoom_x, zoom_y) * 0.95

	print("🎥 Camera position: %s, zoom: %s" % [camera_pos, camera_zoom])

	print("✅ Debug calculations complete!")
	quit()
