#version 300 es

uniform vec4 outlineColor;  // Color of the outline

out vec4 finalColor;

void main()
{
    // Set the color of the outline
    finalColor = outlineColor;
}
