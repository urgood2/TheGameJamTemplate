#version 300 es

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;

// Output vertex attributes (to fragment shader)
out vec2 fragTexCoord;
out vec4 fragColor;

// Uniforms for transformation
uniform vec2 windowPosition; // Window position (top-left)
uniform vec2 windowSize;     // Window size
uniform float visualScale;   // Visual scale
uniform float visualRotation; // Visual rotation (degrees)

void main() {
    // Calculate the center of the window
    vec2 windowCenter = windowPosition + windowSize * 0.5;

    // Translate position to center
    vec2 centeredPos = vertexPosition.xy - windowCenter;

    // Apply scaling
    vec2 scaledPos = centeredPos * visualScale;

    // Apply rotation
    float s = sin(radians(visualRotation));
    float c = cos(radians(visualRotation));
    vec2 rotatedPos = vec2(
        scaledPos.x * c - scaledPos.y * s,
        scaledPos.x * s + scaledPos.y * c
    );

    // Transform back to window space
    vec2 finalPos = rotatedPos + windowCenter;

    // Apply MVP matrix
    gl_Position = mvp * vec4(finalPos, 0.0, 1.0);

    // Pass through texture coordinates and color
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
}
