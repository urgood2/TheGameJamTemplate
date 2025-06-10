#version 300 es

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;  // Main texture
uniform vec4 colDiffuse;

out vec4 finalColor;

void main()
{
    // Simple pass-through of the texture color
    finalColor = texture(texture0, fragTexCoord) * colDiffuse * fragColor;
}
