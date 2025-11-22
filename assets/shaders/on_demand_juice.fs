#version 330 core
in vec2 fragTexCoord;
uniform sampler2D texture0;  // Main texture

out vec4 finalColor;

void main()
{
    // Simple pass-through of the texture color
    finalColor = texture(texture0, fragTexCoord);
}
