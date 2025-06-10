#version 300 es
precision mediump float;

// BATTLE TESTED, combine with a vertex shader.
in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform vec2 iResolution;
uniform float iTime;

uniform float uLineSpacing;
uniform float uLineWidth;
uniform float uBeamHeight;
uniform float uBeamIntensity;
uniform float uOpacity;

uniform float uBeamY;      // beam vertical center (pixels)
uniform float uBeamX;      // beam horizontal center (pixels)
uniform float uBeamWidth;  // beam horizontal width (pixels)

out vec4 finalColor;

void main()
{
    vec2 uv = fragTexCoord;
    vec2 screenUV = uv * iResolution;
    vec2 normUV = screenUV / iResolution;

    // Rainbow color cycle
    float xCol = (normUV.x - (iTime / 8.0)) * 3.0;
    xCol = mod(xCol, 3.0);
    vec3 horColour = vec3(0.25);
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

    // Scanline pattern
    float aspect = iResolution.x / iResolution.y;
    float scanX = mod(normUV.x * uLineSpacing * aspect, 1.0);
    float scanY = mod(normUV.y * uLineSpacing, 1.0);
    float lineMask = step(1.0 - uLineWidth, scanX) + step(1.0 - uLineWidth, scanY);
    float backValue = 1.0 + 0.15 * clamp(lineMask, 0.0, 1.0);
    vec3 backLines = vec3(backValue);

    // Beam vertical falloff (restored inverse style)
    float distY = abs(screenUV.y - uBeamY);
    float verticalFalloff = abs(1.0 / (uBeamHeight * (distY / iResolution.y)));

    // Add a soft limiter only for edges beyond ~1.0 units away from beam center
    float normalizedY = distY / uBeamHeight; // 0 = center, 1 = edge
    float softLimiter = 1.0 - smoothstep(1.0, 2.5, normalizedY); // trims extreme ends only

    verticalFalloff *= softLimiter;
    verticalFalloff = clamp(verticalFalloff * uBeamIntensity, 0.0, 1.5);

    // Beam horizontal mask
    float halfWidth = uBeamWidth * 0.5;
    float beamXMask = smoothstep(uBeamX - halfWidth, uBeamX - halfWidth + 10.0, screenUV.x) *
                      (1.0 - smoothstep(uBeamX + halfWidth - 10.0, uBeamX + halfWidth, screenUV.x));

    // Final beam color
    float beam = verticalFalloff * beamXMask;
    vec3 horBeam = vec3(beam);

    // Overlay
    vec3 overlayColor = backLines * horBeam * horColour;

    // Base color sample
    vec4 baseColor = texture(texture0, fragTexCoord) * fragColor * colDiffuse;

    // Final blend: add glow with opacity, clamp to preserve brightness
    vec3 finalRGB = baseColor.rgb + overlayColor * uOpacity;
    finalRGB = clamp(finalRGB, 0.0, 1.0);

    finalColor = vec4(finalRGB, baseColor.a);
}
