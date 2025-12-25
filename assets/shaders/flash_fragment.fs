#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float iTime;           // Global time for animation
uniform float flashStartTime;  // Per-entity: when this entity's flash started (default 0.0)

out vec4 finalColor;

//REVIEW: battle-tested

void main()
{
    // Compute per-entity local time (time since flash started)
    float localTime = iTime - flashStartTime;

    // Calculate flashing intensity using a sine wave
    // +1.5708 (π/2) phase offset ensures flash starts on WHITE when localTime=0
    float flashIntensity = 0.5 + 0.5 * sin(localTime * 5.0 + 1.5708);

    // Sample the texture color
    vec4 texelColor = texture(texture0, fragTexCoord);

    // Interpolate between the normal color and white, preserving alpha
    vec4 whiteColor = vec4(1.0, 1.0, 1.0, texelColor.a);
    finalColor = mix(texelColor * colDiffuse * fragColor, whiteColor, flashIntensity);

    // Ensure the alpha is preserved
    finalColor.a = texelColor.a * colDiffuse.a * fragColor.a;
}
