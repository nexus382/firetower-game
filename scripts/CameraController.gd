# CameraController.gd overview:
# - Purpose: hold a static tower-wide frame so UI mockups stay centered.
# - Sections: _ready() pins transform, sets current camera, and logs the setup.
extends Camera2D
class_name CameraController

func _ready():
    print("📷 CameraController initialized")

    # Set up fixed camera position for full screen view
    position = Vector2(640, 360)  # Center of 1280x720 screen
    zoom = Vector2(1, 1)  # No zoom for full view

    # Make sure camera is current
    make_current()
    enabled = true

    print("✅ Camera setup complete - fixed view of entire screen")
