// web/cooldown_pie_fragment.fs
// Top-down fill cooldown overlay for trigger cards (WebGL version)
#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform float cooldown_progress;  // 0.0 = ready, 1.0 = full cooldown
uniform float dim_amount;         // How much to darken (e.g., 0.5)
uniform float flash_intensity;    // 0.0 = normal, 1.0 = full flash

// Atlas uniforms (injected by engine)
uniform vec2 uImageSize;
uniform vec4 uGridRect;

// Convert atlas UV to local 0-1 UV within sprite
vec2 getSpriteUV(vec2 uv) {
    vec2 pixelUV   = uv * uImageSize;
    vec2 spriteLoc = pixelUV - uGridRect.xy;
    return spriteLoc / uGridRect.zw;
}

void main() {
    // Sample texture at original atlas coordinates
    vec4 texColor = texture(texture0, fragTexCoord) * fragColor;

    // Convert atlas UV to local 0-1 UV within sprite
    vec2 localUV = getSpriteUV(fragTexCoord);

    // Top-down fill: localUV.y goes from 0 (top) to 1 (bottom)
    // When cooldown_progress = 0.5, top half is dimmed
    float inCooldown = step(localUV.y, cooldown_progress);

    // Apply dimming to cooldown region
    vec3 baseRGB = texColor.rgb * (1.0 - dim_amount * inCooldown);

    // Apply flash effect (blend toward white)
    vec3 finalRGB = mix(baseRGB, vec3(1.0), flash_intensity * 0.6);

    finalColor = vec4(finalRGB, texColor.a);
}
