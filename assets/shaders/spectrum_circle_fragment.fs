#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

// renders a small glowing circle that rotates. will only render over non-transparent pixels. provide location & radius in screen pixels.

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float iTime;
uniform vec2 iResolution;  // Full screen size in pixels
uniform vec2 uCenter;      // Glow center (relative to top-left corner)
uniform float uRadius;     // Glow radius in pixels

out vec4 finalColor;

void main()
{
    // Flip Y to use top-left as origin
    vec2 fragCoord = vec2(fragTexCoord.x * iResolution.x,
                          (1.0 - fragTexCoord.y) * iResolution.y);

    vec2 offset = fragCoord - uCenter;
    float dist = length(offset);

    vec4 baseColor = texture(texture0, fragTexCoord) * fragColor * colDiffuse;
    vec4 resultColor = baseColor;

    if (dist <= uRadius)
    {
        vec2 p = offset / uRadius;
        float a = atan(p.x, p.y);
        float r = length(p);
        vec2 uv = vec2(a / (2.0 * 3.1415926535), r);

        float xCol = mod((uv.x - (iTime / 8.0)) * 3.0, 3.0);
        vec3 horColour = vec3(0.25);

        if (xCol < 1.0) {
            horColour.r += 1.0 - xCol;
            horColour.g += xCol;
        } else if (xCol < 2.0) {
            xCol -= 1.0;
            horColour.g += 1.0 - xCol;
            horColour.b += xCol;
        } else {
            xCol -= 2.0;
            horColour.b += 1.0 - xCol;
            horColour.r += xCol;
        }

        uv = 2.0 * uv - 1.0;
        float beamWidth = abs(3.0 / (30.0 * uv.y));
        beamWidth = clamp(beamWidth, 0.0, 1.0);
        float fade = smoothstep(uRadius, uRadius * 0.7, dist);

        vec3 glowColor = horColour * beamWidth * fade;
        
        // additive blend
        resultColor.rgb += glowColor;
        resultColor.a = max(baseColor.a, 0.0);
        
        // screen blend
        // resultColor.rgb = 1.0 - (1.0 - baseColor.rgb) * (1.0 - glowColor);
        // resultColor.a = max(baseColor.a, fade * 0.5);
        
        // overlay blend
        // vec3 screenBlend = 1.0 - (1.0 - baseColor.rgb) * (1.0 - glowColor);
        // vec3 multiplyBlend = baseColor.rgb * glowColor;
        // resultColor.rgb = mix(multiplyBlend, screenBlend, step(0.5, baseColor.rgb));
        // resultColor.a = max(baseColor.a, fade * 0.5);
        
        // soft light
        // vec3 d = glowColor;
        // vec3 b = baseColor.rgb;
        // resultColor.rgb = mix(2.0 * b * d + b * b * (1.0 - 2.0 * d), sqrt(b) * (2.0 * d - 1.0) + 2.0 * b * (1.0 - d), step(0.5, d));
        // resultColor.a = max(baseColor.a, fade * 0.5);
        
        // linear dodge
        // resultColor.rgb = min(baseColor.rgb + glowColor, 1.0);
        // resultColor.a = max(baseColor.a, fade * 0.5);

    }

    finalColor = resultColor;
}
