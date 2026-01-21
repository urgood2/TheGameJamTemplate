#version 330 core
precision mediump float;

in vec2 fragTexCoord;
out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float progress;          // Range: [0.0, 1.0]
uniform vec2 slide_direction;    // (1,0)=right, (-1,0)=left, etc.
uniform vec3 fade_color;

void main() {
    // Apply sliding offset
    vec2 offset = slide_direction * (1.0 - progress);
    vec2 uv = fragTexCoord + offset;

    // Sample main texture
    vec4 texColor = texture(texture0, uv);

    // Fade to black as progress → 1.0
    float fade = smoothstep(0.0, 1.0, progress); // fade kicks in halfway
    vec4 color = mix(texColor, vec4(fade_color, 1.0), fade);

    finalColor = color * colDiffuse;
}
