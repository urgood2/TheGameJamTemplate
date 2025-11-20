#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform vec4 outlineColor;
uniform int outlineType;    // 0=4-way, 1=8-way (diagonal), 2=both
uniform float thickness;

out vec4 finalColor;

const vec2 DIRECTIONS[8] = vec2[8](
    vec2(1.0, 0.0),
    vec2(0.0, 1.0),
    vec2(-1.0, 0.0),
    vec2(0.0, -1.0),
    vec2(1.0, 1.0),
    vec2(-1.0, 1.0),
    vec2(-1.0, -1.0),
    vec2(1.0, -1.0)
);

// Returns 1 if input > 0, else 0
float gtz(float input) {
    return max(0.0, sign(input));
}

float checkOutline(sampler2D tex, vec2 uv, vec2 pixelSize) {
    float result = 0.0;
    int sampleCount = 4 * outlineType;
    for (int i = 0; i < sampleCount; i++) {
        vec2 sampleUV = uv + DIRECTIONS[i] * pixelSize * thickness;
        result += texture(tex, sampleUV).a;
    }
    return gtz(result);
}

void main() {
    vec4 texColor = texture(texture0, fragTexCoord);
    vec2 pixelSize = 1.0 / vec2(textureSize(texture0, 0));

    float outline = checkOutline(texture0, fragTexCoord, pixelSize);
    float isTransparent = 1.0 - gtz(texColor.a);

    vec4 color = mix(texColor, outlineColor, outline * isTransparent);

    finalColor = color * colDiffuse * fragColor;
}
