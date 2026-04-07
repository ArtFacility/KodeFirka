shader_type canvas_item;

uniform float size : hint_range(0.0, 1.0) = 0.5;      // 0 to 1 relative to container
uniform float opacity : hint_range(0.0, 1.0) = 1.0;   // Transparency
uniform float feathering : hint_range(0.0, 1.0) = 0.2; // Edge softness
uniform vec3 color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
    float dist = distance(UV, vec2(0.5));
    float radius = size * 0.5;
    
    // Smoothstep creates the soft edge. 
    // Higher feathering = wider transition zone.
    float alpha = smoothstep(radius, radius - (feathering * radius), dist);
    
    COLOR = vec4(color, alpha * opacity);
}