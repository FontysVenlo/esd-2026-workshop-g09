shader_type canvas_item;

uniform vec4 void_color : source_color = vec4(0.03, 0.03, 0.05, 1.0); // Pitch dark navy/black
uniform vec4 glow_color : source_color = vec4(0.08, 0.08, 0.12, 1.0); // Subtle ambient glow
uniform float speed = 0.5;

void fragment() {
    vec2 st = UV * 3.0;
    
    // Simple drifting ambient wave
    float wave = sin(st.x + TIME * speed) * cos(st.y + TIME * speed);
    wave = smoothstep(-1.0, 1.0, wave);
    
    COLOR = mix(void_color, glow_color, wave * 0.3);
}