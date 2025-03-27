#version 330 core
precision mediump float;

in vec2 fragTexCoord;
out vec4 finalColor;

uniform sampler2D fromTexture;
uniform sampler2D toTexture;

uniform float progress;      // [0.0, 1.0]
uniform vec2 slide_direction; // (1, 0)=right, (-1, 0)=left, etc.
uniform vec3 fade_color;     // Color between scenes (black/white/etc.)

void main() {
    // Slide offset
    vec2 offset = slide_direction * (1.0 - progress);
    
    // Sample the fromTexture with offset
    vec4 fromColor = texture(fromTexture, fragTexCoord + offset);
    vec4 toColor = texture(toTexture, fragTexCoord);

    // Blend with fade color in the middle
    vec4 midFade = vec4(fade_color, 1.0);
    vec4 blended = mix(fromColor, midFade, smoothstep(0.0, 0.5, progress));
    finalColor = mix(blended, toColor, smoothstep(0.5, 1.0, progress));
}
