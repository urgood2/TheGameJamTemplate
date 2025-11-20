#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

out vec4 finalColor;

void main() {
    finalColor = texture(texture0, fragTexCoord) * colDiffuse * fragColor;
}
