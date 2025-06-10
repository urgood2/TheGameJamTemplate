#version 300 es

in vec2 vertexPosition;  // 2D vertex position attribute
in vec2 vertexTexCoord;  // 2D texture coordinate attribute

uniform mat4 mvp;        // Model-View-Projection matrix
uniform float iTime;      // Current time for animation
uniform float appearTime = 2; // Duration for the appearance animation

out vec2 fragTexCoord;

//TODO: test this and make a disappearing animation as well

// Function to simulate easing (smooth appearance with bounce)
float easeOutElastic(float t) {
    if (t == 0.0 || t == 1.0) return t;
    float p = 0.3;
    return pow(2.0, -10.0 * t) * sin((t - p / 4.0) * (2.0 * 3.14159265) / p) + 1.0;
}

// Function to add a jiggle effect
float jiggleEffect(float angle, float t) {
    return sin(t * 10.0 + angle) * 0.05; // Adjust frequency and amplitude as needed
}

void main()
{
    // Calculate normalized time for animation
    float progress = clamp(iTime / appearTime, 0.0, 1.0);
    float scale = easeOutElastic(progress);

    // Add a jiggle effect to the scale for animation
    float angle = atan(vertexPosition.y, vertexPosition.x);
    float jiggle = jiggleEffect(angle, iTime);
    scale += jiggle;

    // Apply scaling to vertex position
    vec2 scaledPosition = vertexPosition * scale;

    // Output transformed position
    gl_Position = mvp * vec4(scaledPosition, 0.0, 1.0);
    fragTexCoord = vertexTexCoord;
}
