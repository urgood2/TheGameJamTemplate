#version 300 es
in vec2 fragTexCoords;
out vec4 color;

uniform sampler2D textureSampler; // The texture of the button
uniform float flashIntensity;      // Control parameter for the flash effect (0.0 to 1.0)

void main() {
    vec4 baseColor = texture(textureSampler, fragTexCoords);
    vec4 flashColor = vec4(1.0, 1.0, 1.0, flashIntensity); // Pure white color

    // Blend the flash color with the base color, controlled by flashIntensity
    color = mix(baseColor, flashColor, flashIntensity);
}
