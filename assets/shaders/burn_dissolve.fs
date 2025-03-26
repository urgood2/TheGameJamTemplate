#version 330 core

in vec2 fragTexCoord;

uniform sampler2D texture0;        // Main texture (replacing TEXTURE)
uniform sampler2D dissolveTexture; // Dissolve texture (replacing dissolve_texture)
uniform float dissolveValue;       // Dissolve value
uniform float burnSize;            // Size of the burning edge
uniform vec4 burnColor;            // Color of the burning edge

out vec4 finalColor;

//TODO: make a dissove texture (512x512? size doesn't matter) and load it in

void main()
{
    // Sample the main texture and dissolve noise texture
    vec4 mainTexture = texture(texture0, fragTexCoord);
    vec4 noiseTexture = texture(dissolveTexture, fragTexCoord);

    // Ensure the burn size applies only when dissolveValue is in a valid range
    float burnSizeStep = burnSize * step(0.001, dissolveValue) * step(dissolveValue, 0.999);

    // Calculate the threshold and border for the dissolve effect
    float threshold = smoothstep(noiseTexture.r - burnSizeStep, noiseTexture.r, dissolveValue);
    float border = smoothstep(noiseTexture.r, noiseTexture.r + burnSizeStep, dissolveValue);

    // Apply the threshold to the alpha channel and blend the burn color with the main texture
    finalColor = mainTexture;
    finalColor.a *= threshold;
    finalColor.rgb = mix(burnColor.rgb, mainTexture.rgb, border);
}
