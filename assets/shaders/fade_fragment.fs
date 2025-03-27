#version 330 core
precision mediump float;

in vec2 fragTexCoord;
out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float progress;          // Range: [0.0, 1.0]

void main() {
    // Apply sliding offset
    vec2 uv = fragTexCoord;

    // Sample main texture
    vec4 texColor = texture(texture0, uv);

    // Fade to black as progress → 1.0
    vec4 black = vec4(0.0, 0.0, 0.0, 1.0);
    float fade = smoothstep(0.5, 1.0, progress); // fade kicks in halfway
    vec4 color = mix(texColor, black, fade);

    finalColor = color * colDiffuse;
}
