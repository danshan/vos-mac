extends RefCounted


func configure_java_reference_viewport(viewport: SubViewport, base_size: Vector2i, hidpi_scale: int) -> void:
	viewport.size = base_size * maxi(hidpi_scale, 1)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_snap_controls_to_pixels = false
