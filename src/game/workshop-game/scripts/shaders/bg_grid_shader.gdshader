shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.07, 0.07, 0.07, 1.0); // #121212 Dark Background
uniform vec4 line_color : source_color = vec4(0.16, 0.16, 0.16, 1.0); // #292929 Grid Lines
uniform float grid_size = 64.0; // Distance between grid lines in pixels
uniform float line_thickness = 2.0; // Thickness of the grid lines

void fragment() {
	// Calculate pixel position relative to grid size
	vec2 grid_pos = mod(FRAGCOORD.xy, vec2(grid_size));
	
	// Check if current fragment falls within the line thickness
	if (grid_pos.x < line_thickness || grid_pos.y < line_thickness) {
		COLOR = line_color;
	} else {
		COLOR = bg_color;
	}
}