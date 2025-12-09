#version 300 es
precision mediump float;


in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// ---- Sprite Atlas Inputs ----
uniform vec2 uImageSize;   // full atlas size (px)
uniform vec4 uGridRect;    // x,y = top-left px | z,w = width,height px

// ---- Effect Uniforms ----
uniform float burst_progress;
uniform float spread_strength;
uniform float distortion_strength;
uniform float fade_start;
uniform float iTime;

out vec4 finalColor;

// ----------------------------------------------------------
// Sprite-local UV helper
// fragTexCoord is in [0..1] for the whole atlas
// Returns UV in [0..1] relative to the sprite region only
// ----------------------------------------------------------
vec2 getSpriteUV(vec2 uv) {
    vec2 pixelUV   = uv * uImageSize;
    vec2 spriteLoc = pixelUV - uGridRect.xy;
    return spriteLoc / uGridRect.zw;
}

void main() {
    // Convert atlas UV → local sprite UV first
    vec2 baseUV = getSpriteUV(fragTexCoord);

    // Center local UV
    vec2 centered_uv = baseUV - vec2(0.5);

    // Safe normalize
    vec2 dir = (length(centered_uv) > 0.00001)
        ? normalize(centered_uv)
        : vec2(0.0);

    float dist = length(centered_uv);

    // Outward push
    vec2 uv_outward = centered_uv + dir * burst_progress * spread_strength;

    // Distortion wobble
    uv_outward += distortion_strength * vec2(
        sin(dist * 20.0 - iTime * 10.0),
        cos(dist * 20.0 - iTime * 8.0)
    ) * burst_progress;

    // Back to 0..1 local sprite coords
    vec2 final_uv_local = uv_outward + vec2(0.5);

    // Clamp to avoid atlas bleed if distortion goes outside
    final_uv_local = clamp(final_uv_local, 0.0, 1.0);

    // Transform back into atlas UV
    vec2 final_uv =
        (uGridRect.xy + final_uv_local * uGridRect.zw) / uImageSize;

    // Sample from atlas
    vec4 texelColor = texture(texture0, final_uv);

    // Fade out
    float alpha_factor = 1.0 - smoothstep(fade_start, 1.0, burst_progress);
    texelColor.a *= alpha_factor;

    finalColor = texelColor * colDiffuse * fragColor;
}
