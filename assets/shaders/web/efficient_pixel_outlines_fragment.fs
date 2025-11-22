#version 300 es
precision mediump float;

precision mediump float;

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec4 clr;
uniform int type;
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

float check(sampler2D tex, vec2 from, vec2 size) {
    float result = 0.0;
    for (int i = 0; i < 4 * type; i++) {
        result += texture(tex, from + DIRECTIONS[i] * size * thickness).a;
    }
    return gtz(result);
}

void main()
{
    finalColor = texture(texture0, fragTexCoord);
    vec2 texelSize = 1.0 / vec2(textureSize(texture0, 0));
    finalColor = mix(finalColor, clr, check(texture0, fragTexCoord, texelSize) * (1.0 - gtz(finalColor.a)));
    finalColor *= colDiffuse * fragColor;
}
