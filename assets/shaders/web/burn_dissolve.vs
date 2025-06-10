#version 300 es

in vec2 vertexPosition;  // Vertex position attribute for 2D
in vec2 vertexTexCoord;  // Vertex texture coordinate attribute

uniform mat4 mvp;        // Model-View-Projection matrix

out vec2 fragTexCoord;

void main()
{
    // Transform the vertex position to clip space
    gl_Position = mvp * vec4(vertexPosition, 0.0, 1.0);
    fragTexCoord = vertexTexCoord;
}
