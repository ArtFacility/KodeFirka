@tool # Allows it to update in the editor while you tweak sliders
extends Control

@onready var color_rect: ColorRect = $PanelContainer/ColorRect

func update_preview(new_size: float, new_opacity: float, new_feathering: float, new_color: Color):
	if not is_inside_tree(): return # Avoid errors during initialization
	
	var mat = color_rect.material as ShaderMaterial
	if mat:
		# size in shader is 0.0 to 1.0, where 1.0 is full width
		# But we should probably scale it based on some reasonable max size
		# For now, let's just pass it through or scale it
		mat.set_shader_parameter("size", new_size / 20.0) # Scaling relative to max brush size of 20
		mat.set_shader_parameter("opacity", new_opacity)
		mat.set_shader_parameter("feathering", new_feathering)
		mat.set_shader_parameter("color", new_color)
