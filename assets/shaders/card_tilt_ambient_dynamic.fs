#version 330 core
in vec2 fragTexCoord; // Received texture coordinates from vertex shader

out vec4 finalColor; // Final color output

uniform sampler2D texture0; // Texture sampler from Raylib

void main() {
    finalColor = texture(texture0, fragTexCoord);
}