// cooldown_pie_fragment.fs
#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform float cooldown_progress;  // 0.0 = ready, 1.0 = full cooldown
uniform float dim_amount;         // How much to darken (e.g., 0.4)
uniform float flash_intensity;    // 0.0 = normal, 1.0 = full flash

// Atlas bounds for local UV calculation
uniform vec4 sprite_bounds;       // x, y, width, height in atlas UV space

const float PI = 3.14159265359;

void main() {
    // Convert atlas UV to local 0-1 UV within sprite
    vec2 localUV = (fragTexCoord - sprite_bounds.xy) / sprite_bounds.zw;
    vec2 centered = localUV - 0.5;

    // Calculate angle from center (0 at top, clockwise)
    float angle = atan(centered.x, -centered.y);  // -centered.y so 0 is at top
    float normalizedAngle = (angle + PI) / (2.0 * PI);  // 0 to 1

    // Determine if this pixel is in the cooldown region
    float inCooldown = step(normalizedAngle, cooldown_progress);

    // Sample texture at original atlas coordinates
    vec4 texColor = texture(texture0, fragTexCoord) * fragColor;

    // Apply dimming to cooldown region
    vec3 dimmed = texColor.rgb * (1.0 - dim_amount * inCooldown);

    // Apply flash effect (blend toward white)
    vec3 finalRGB = mix(dimmed, vec3(1.0), flash_intensity * 0.6);

    finalColor = vec4(finalRGB, texColor.a);
}
