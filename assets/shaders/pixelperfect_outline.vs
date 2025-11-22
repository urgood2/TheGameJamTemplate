#version 330 core
in vec3 vertexPosition;  // Vertex position attribute
in vec3 vertexNormal;    // Vertex normal attribute

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform vec2 viewportSize;  // Size of the viewport (screen width and height)
uniform float outlineWidth; // Width of the outline

void main()
{
    // Calculate the clip-space position of the vertex
    vec4 clipPosition = projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    // Calculate the normal in clip space
    vec3 clipNormal = mat3(projectionMatrix) * (mat3(modelViewMatrix) * vertexNormal);

    // Offset the position based on the normal and outline width
    vec2 offset = normalize(clipNormal.xy) / viewportSize * clipPosition.w * outlineWidth * 2.0;
    clipPosition.xy += offset;

    // Set the final position
    gl_Position = clipPosition;
}
