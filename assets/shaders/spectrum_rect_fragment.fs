#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 iResolution;   // Screen resolution in pixels
uniform float iTime;        // Time in seconds (used for animation)
uniform vec2 rectSize;      // Size of the rectangle (width, height)
uniform float rectRadius;   // Corner radius (with a basic default value)
uniform float duration;     // Duration (in seconds) for a full loop around the rect
uniform float lineWidth;    // Thickness of the animated line (in pixels)

out vec4 finalColor;

// --- Rounded Rect SDF function ---
// Computes the signed distance to a rounded rectangle. 'halfSize' is half the rect’s size.
float roundedRectSDF(vec2 p, vec2 halfSize, float r)
{
    vec2 d = abs(p) - halfSize + vec2(r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

// --- HSV to RGB conversion ---
// Converts a color from HSV to RGB. We use the 'hue' (first component) to sweep through the spectrum.
vec3 hsv2rgb(vec3 c)
{
    vec3 rgb = clamp( abs(mod(c.x * 6.0 + vec3(0.0,4.0,2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0 );
    return c.z * mix(vec3(1.0), rgb, c.y);
}

void main()
{
    // Map fragTexCoord to pixel coordinates.
    vec2 uv = fragTexCoord * iResolution;
    // Center the rectangle on screen.
    vec2 center = iResolution * 0.5;
    // p will be our coordinate relative to the center.
    vec2 p = uv - center;
    
    // Define half-size from the supplied rectangle size.
    vec2 halfSize = rectSize * 0.5;
    
    // Compute signed distance from the point to the rounded rectangle border.
    float dist = roundedRectSDF(p, halfSize, rectRadius);
    
    // Build a mask that is nonzero only near the border.
    float borderMask = smoothstep(lineWidth, lineWidth * 0.5, abs(dist));
    
    // --- Approximate a parameter that runs continuously along the border ---
    // We “normalize” p by the half-size. This squashes the rectangle to a circle.
    // (This isn’t an exact arc‑length, but it is continuous and works reasonably well.)
    vec2 normP = p / halfSize;
    float angle = atan(normP.y, normP.x);
    // Map angle from [-PI, PI] to [0, 1].
    float borderParam = (angle + 3.14159265) / (2.0 * 3.14159265);
    
    // Animate: subtract a time‑dependent phase so the highlight travels along the border.
    float phase = mod(borderParam - iTime / duration, 1.0);
    
    // Generate a spectrum color from the phase (using hue as the driver).
    vec3 spectrumCol = hsv2rgb(vec3(phase, 1.0, 1.0));
    
    // Mix the spectrum color with a black background based on the border mask.
    vec3 col = mix(vec3(0.0), spectrumCol, borderMask);
    
    finalColor = vec4(col, 1.0);
}
