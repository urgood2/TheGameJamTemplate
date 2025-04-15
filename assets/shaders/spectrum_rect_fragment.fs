#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float iTime;
uniform vec4 glowRect = vec4(0.0, 0.0, 1.0, 1.0); // x, y, w, h

out vec4 finalColor;

vec2 getGlowPositionFromEdge(float t, vec4 rect)
{
    float x = rect.x, y = rect.y, w = rect.z, h = rect.w;
    t = mod(t, 1.0);

    if (t < 0.25) return vec2(x + t / 0.25 * w, y);
    if (t < 0.5)  return vec2(x + w, y + (t - 0.25) / 0.25 * h);
    if (t < 0.75) return vec2(x + (1.0 - (t - 0.5) / 0.25) * w, y + h);
    return vec2(x, y + (1.0 - (t - 0.75) / 0.25) * h);
}

float getEdgeCoord(vec2 uv, vec4 rect, float borderWidth)
{
    float x = rect.x, y = rect.y, w = rect.z, h = rect.w;

    if (abs(uv.y - y) < borderWidth) return (uv.x - x) / w * 0.25;
    if (abs(uv.x - (x + w)) < borderWidth) return 0.25 + (uv.y - y) / h * 0.25;
    if (abs(uv.y - (y + h)) < borderWidth) return 0.5 + (1.0 - (uv.x - x) / w) * 0.25;
    if (abs(uv.x - x) < borderWidth) return 0.75 + (1.0 - (uv.y - y) / h) * 0.25;

    return -1.0;
}

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 baseColor = texelColor * colDiffuse * fragColor;

    float borderWidth = 0.015;

    float pulsePos = mod(iTime * 0.2, 1.0);
    float glowAmount = 0.0;

    // === Soft trail along edge ===
    float edgeCoord = getEdgeCoord(fragTexCoord, glowRect, borderWidth);
    if (edgeCoord >= 0.0)
    {
        float delta = mod(pulsePos - edgeCoord + 1.0, 1.0);

        // Use Gaussian-style falloff for smooth trail
        float trailFalloff = exp(-pow(delta * 15.0, 2.0)); // smooth, wide
        glowAmount += trailFalloff;
    }

    // === Soft blur aura around glow ===
    vec2 glowCenter = getGlowPositionFromEdge(pulsePos, glowRect);
    float radialDist = distance(fragTexCoord, glowCenter);
    float blurMask = exp(-pow(radialDist / 0.05, 2.0));
    glowAmount += blurMask * 0.4;

    // Final color blend
    vec3 glowColor = vec3(1.0, 0.6, 0.2); // warm yellow-orange
    vec4 glow = vec4(glowColor * glowAmount, glowAmount);

    finalColor = baseColor + glow;
    finalColor.a = clamp(finalColor.a, 0.0, 1.0);
}
