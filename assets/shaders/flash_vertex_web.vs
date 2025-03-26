#version 300 es
precision mediump float;

in vec3 vertexPosition; // Vertex position
in vec2 vertexTexCoord; // Texture coordinates
in vec4 vertexColor;    // Vertex color

uniform mat4 mvp;       // Model-View-Projection matrix

out vec2 fragTexCoord;  // Pass texture coordinates to fragment shader
out vec4 fragColor;     // Pass vertex color to fragment shader

void main()
{
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
