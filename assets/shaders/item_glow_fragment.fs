#version 330 core
in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// ───────────────────────────────
// Custom uniforms
uniform vec4 glow_color;     // vec4
uniform float intensity;     // float
uniform float spread;        // float
uniform float pulse_speed;   // float
uniform float iTime;         // float injected from C++
// ───────────────────────────────

out vec4 finalColor;

void main()
{
    // Center UV around 0.5,0.5
    vec2 centered_uv = fragTexCoord - vec2(0.5);

    float dist = length(centered_uv) * spread;

    float alpha = max(0.0, 1.0 - dist);

    // Pulsing factor
    alpha *= (1.0 + 0.2 * sin(iTime * pulse_speed));

    alpha = clamp(alpha * intensity, 0.0, 1.0);


    // Pure glow — ignores texture
    finalColor = glow_color * alpha;
    vec4 base = texture(texture0, fragTexCoord);

    finalColor = base + glow_color * alpha;  // additive



}
