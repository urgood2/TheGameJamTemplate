#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;     // Raylib default texture sampler
uniform vec4 colDiffuse;        // Raylib default tint color

uniform vec2 iResolution;       // Screen resolution
uniform float iTime;            // Time for animation
uniform vec2 rectSize;          // Size of the rectangle
uniform float rectRadius;       // Rounded corner radius
uniform float duration;         // Time for full loop animation
uniform float lineWidth;        // Thickness of the spectrum border
uniform vec2 rectTopLeft;       // Top-left corner of the rectangle

out vec4 finalColor;

// Rounded rectangle SDF
float roundedRectSDF(vec2 p, vec2 halfSize, float r)
{
    vec2 d = abs(p) - halfSize + vec2(r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

// HSV to RGB
vec3 hsv2rgb(vec3 c)
{
    vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0,4.0,2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return c.z * mix(vec3(1.0), rgb, c.y);
}

void main()
{
    vec2 uv = fragTexCoord * iResolution;

    vec2 halfSize = rectSize * 0.5;
    vec2 rectCenter = rectTopLeft + halfSize;
    vec2 p = uv - rectCenter;

    float dist = roundedRectSDF(p, halfSize, rectRadius);
    float borderMask = smoothstep(lineWidth, lineWidth * 0.5, abs(dist));

    vec2 normP = p / halfSize;
    float angle = atan(normP.y, normP.x);
    float borderParam = (angle + 3.14159265) / (2.0 * 3.14159265);
    float phase = mod(borderParam - iTime / duration, 1.0);
    vec3 spectrumCol = hsv2rgb(vec3(phase, 1.0, 1.0));

    // Sample the base texture color (default white if no texture)
    vec4 texColor = texture(texture0, fragTexCoord) * colDiffuse;

    // Blend the animated border color into the base texture
    vec3 finalRGB = mix(texColor.rgb, spectrumCol, borderMask);

    finalColor = vec4(finalRGB, texColor.a); // retain original alpha
}
