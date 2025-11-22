#version 300 es
precision mediump float;

precision mediump float;

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec4 bottom_color;
uniform vec4 top_color;
uniform sampler2D tex;
uniform int layer_count;
uniform float time_scale;
uniform float base_intensity;
uniform float size;
uniform float time;

// Output fragment color
out vec4 finalColor;

vec4 lerp(vec4 a, vec4 b, float w) {
    return a + w * (b - a);
}

float fmod(float x, float y) {
    return x - floor(x / y) * y;
}

float rand(float n) {
    return fract(sin(n) * 43758.5453123);
}

bool cloud_layer(float x, float y, float h) {
    return y - sqrt((1.0 - pow(y - h, 2.0))) * base_intensity * texture(tex, vec2(fmod(x / size + rand(h), 1.0), fmod(y / size - time * time_scale, 1.0))).r < h;
}

void main()
{
    float y = 1.0 - fragTexCoord.y;

    finalColor = vec4(0.0); // Default transparent

    for (int i = 0; i < layer_count; i++) {
        float h = float(i) / float(layer_count - 1);
        if (cloud_layer(fragTexCoord.x, y, h)) {
            finalColor = lerp(bottom_color, top_color, h);
            break;
        }
    }

    finalColor *= colDiffuse * fragColor;
}
