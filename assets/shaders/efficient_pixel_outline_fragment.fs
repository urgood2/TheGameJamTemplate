#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Outline uniforms
uniform vec4 outlineColor;
uniform int outlineType; // 0=none, 1=4-way, 2=8-way
uniform float thickness;

// Output fragment color
out vec4 finalColor;

const vec2[8] DIRECTIONS = vec2[8](
    vec2(1.0, 0.0),
    vec2(0.0, 1.0),
    vec2(-1.0, 0.0),
    vec2(0.0, -1.0),
    vec2(1.0, 1.0),
    vec2(-1.0, 1.0),
    vec2(-1.0, -1.0),
    vec2(1.0, -1.0)
);

float gtz(float input) {
    return max(0.0, sign(input));
}

float check(sampler2D tex, vec2 from, vec2 pixelSize) {
    float result = 0.0;
    int samples = 4 * outlineType;
    for (int i = 0; i < samples; i++) {
        result += texture(tex, from + DIRECTIONS[i] * pixelSize * thickness).a;
    }
    return gtz(result);
}

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);

    // Calculate texture pixel size
    vec2 texelSize = 1.0 / vec2(textureSize(texture0, 0));

    // Check for outline
    float outlineAmount = check(texture0, fragTexCoord, texelSize) * (1.0 - gtz(texelColor.a));

    // Mix color with outline
    finalColor = mix(texelColor * colDiffuse * fragColor, outlineColor, outlineAmount);
}
