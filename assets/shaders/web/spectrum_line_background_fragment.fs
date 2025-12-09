#version 300 es
precision mediump float;


// a background I really liked, just attach a generic vertex shader file and it should work.

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0; // Not used here, but required
uniform vec4 colDiffuse;

uniform vec2 iResolution;
uniform float iTime;

out vec4 finalColor;

void main()
{
    vec2 uv = fragTexCoord;

    // Convert to screen space UVs
    vec2 screenUV = uv * iResolution;
    vec2 normUV = screenUV / iResolution;

    // Horizontal color band animation
    float xCol = (normUV.x - (iTime / 8.0)) * 3.0;
    xCol = mod(xCol, 3.0);
    vec3 horColour = vec3(0.25, 0.25, 0.25);

    if (xCol < 1.0) {
        horColour.r += 1.0 - xCol;
        horColour.g += xCol;
    }
    else if (xCol < 2.0) {
        xCol -= 1.0;
        horColour.g += 1.0 - xCol;
        horColour.b += xCol;
    }
    else {
        xCol -= 2.0;
        horColour.b += 1.0 - xCol;
        horColour.r += xCol;
    }

    // Background scanlines
    float backValue = 1.0;
    float aspect = iResolution.x / iResolution.y;
    if (mod(normUV.y * 100.0, 1.0) > 0.75 || mod(normUV.x * 100.0 * aspect, 1.0) > 0.75) {
        backValue = 1.15;
    }
    vec3 backLines = vec3(backValue);

    // Central horizontal beam distortion
    vec2 beamUV = normUV * 2.0 - 1.0; // [-1,1] range
    float beamWidth = abs(1.0 / (30.0 * beamUV.y));
    vec3 horBeam = vec3(beamWidth);

    // Compose final color
    vec3 color = (backLines * horBeam) * horColour;

    finalColor = vec4(color, 1.0);
}
