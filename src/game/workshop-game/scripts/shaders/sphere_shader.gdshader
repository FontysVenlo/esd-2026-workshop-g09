shader_type canvas_item;

uniform vec4 circle_color : source_color = vec4(0.2, 0.6, 1.0, 1.0); // Player Color
uniform vec4 border_color : source_color = vec4(0.1, 0.4, 0.8, 1.0); // Darker Outline
uniform float border_thickness : hint_range(0.0, 0.2) = 0.08;

void fragment() {
    // Calculate distance from center (0.5, 0.5)
    float dist = distance(UV, vec2(0.5));
    
    // Discard pixels outside the circle
    if (dist > 0.5) {
        discard;
    }
    
    // Draw outer border vs inner circle
    if (dist > 0.5 - border_thickness) {
        COLOR = border_color;
    } else {
        COLOR = circle_color;
    }
}