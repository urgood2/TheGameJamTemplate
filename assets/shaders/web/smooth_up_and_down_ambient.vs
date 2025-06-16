#version 300 es

in vec3 vertexPosition;  // Vertex position attribute for 2D
in vec2 vertexTexCoord;  // Texture coordinate attribute 
in vec4 vertexColor;

uniform mat4 mvp;        // Model-View-Projection matrix
uniform float iTime;      // Time value for animation
uniform float amplitude; // Amplitude of the up-and-down motion
uniform float frequency; // how fast the bobbing happens

out vec2 fragTexCoord;
out vec4 fragColor;

//REVIEW: battle-tested

void main()
{
    // Calculate vertical offset based on sine wave
    float offset = amplitude * sin(iTime * frequency);

    // Apply vertical offset to the vertex position
    vec2 animatedPosition = vertexPosition.xy + vec2(0.0, offset);

    fragColor = vertexColor;

    // Set the transformed position
    gl_Position = mvp * vec4(animatedPosition, 0.0, 1.0);
    fragTexCoord = vertexTexCoord;
}
