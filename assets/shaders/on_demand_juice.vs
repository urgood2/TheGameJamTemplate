#version 330 core

in vec2 vertexPosition;  // Vertex position attribute for 2D
in vec2 vertexTexCoord;  // Vertex texture coordinate attribute

uniform mat4 mvp;        // Model-View-Projection matrix
uniform float time;      // Current time for animation
uniform float duration;  // Duration for which the animation runs
uniform float angleAmplitude; // Initial amplitude of angular oscillation
uniform float bounceAmplitude; // Initial amplitude of size bouncing

out vec2 fragTexCoord;

// Damping function to reduce amplitude over time
float dampen(float initialAmplitude, float t, float maxTime) {
    float progress = clamp(t / maxTime, 0.0, 1.0);
    return initialAmplitude * exp(-progress * 3.0); // Exponential damping
}

// Function for angular oscillation with dampening
float angularOscillation(float amplitude, float t) {
    return dampen(amplitude, t, duration) * sin(t * 10.0); // Frequency of oscillation can be adjusted
}

// Function for vertical size bouncing with dampening
float sizeBounce(float amplitude, float t) {
    return dampen(amplitude, t, duration) * abs(sin(t * 5.0)); // Adjust frequency as needed
}

void main()
{
    // Calculate the dampened angular oscillation and size bounce
    float angleEffect = angularOscillation(angleAmplitude, time);
    float bounceEffect = sizeBounce(bounceAmplitude, time);

    // Apply angular oscillation to rotate vertices
    float angle = angleEffect * (3.14159265 / 180.0); // Convert degrees to radians
    mat2 rotationMatrix = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
    vec2 rotatedPosition = rotationMatrix * vertexPosition;

    // Apply size bounce to scale vertices vertically
    vec2 scaledPosition = rotatedPosition * vec2(1.0, 1.0 + bounceEffect);

    // Set the final position
    gl_Position = mvp * vec4(scaledPosition, 0.0, 1.0);
    fragTexCoord = vertexTexCoord;
}
