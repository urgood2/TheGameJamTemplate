#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Custom uniforms
uniform vec4 clr = vec4(0.0, 0.0, 0.0, 1.0);
uniform int outlineType = 2; // 0=disabled, 1=4-way, 2=8-way
uniform float thickness = 1.0;

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
    int maxDir = 4 * outlineType;
    for (int i = 0; i < 8; i++) {
        if (i < maxDir) {
            result += texture(tex, from + DIRECTIONS[i] * pixelSize * thickness).a;
        }
    }
    return gtz(result);
}

void main()
{
    vec2 texturePixelSize = 1.0 / vec2(textureSize(texture0, 0));
    vec4 texelColor = texture(texture0, fragTexCoord);

    float outline = check(texture0, fragTexCoord, texturePixelSize) * (1.0 - gtz(texelColor.a));
    vec4 color = mix(texelColor, clr, outline);

    finalColor = color * colDiffuse * fragColor;
}
