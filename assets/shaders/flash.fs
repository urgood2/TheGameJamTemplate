#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float iTime;  // Time for animation

out vec4 finalColor;

//REVIEW: battle-tested

void main()
{
    // Calculate flashing intensity using a sine wave
    float flashIntensity = 0.5 + 0.5 * sin(iTime * 40.0);  // Adjusted to range between 0.0 and 1.0

    // Sample the texture color
    vec4 texelColor = texture(texture0, fragTexCoord);

    // Interpolate between the normal color and white, preserving alpha
    vec4 whiteColor = vec4(1.0, 1.0, 1.0, texelColor.a);
    finalColor = mix(texelColor * colDiffuse * fragColor, whiteColor, flashIntensity);

    // Ensure the alpha is preserved
    finalColor.a = texelColor.a * colDiffuse.a * fragColor.a;
}
