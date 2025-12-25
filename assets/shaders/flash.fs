#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float iTime;           // Global time for animation
uniform float flashStartTime;  // Per-entity: when this entity's flash started (default 0.0)

out vec4 finalColor;

void main()
{
    // Compute per-entity local time (time since flash started)
    float localTime = iTime - flashStartTime;

    // Create a square wave that toggles between 0.0 and 1.0 rapidly
    // +0.5 phase offset ensures flash starts on WHITE when localTime=0
    float flashIntensity = step(0.5, fract(localTime * 10.0 + 0.5));
    // ↑ 10.0 = flash frequency; higher = faster blinking

    // Sample the texture
    vec4 texelColor = texture(texture0, fragTexCoord);

    // Instant switch between normal color and white
    vec4 baseColor = texelColor * colDiffuse * fragColor;
    vec4 flashColor = vec4(1.0, 1.0, 1.0, baseColor.a);
    finalColor = mix(baseColor, flashColor, flashIntensity);

    // Preserve alpha
    finalColor.a = texelColor.a * colDiffuse.a * fragColor.a;
}
