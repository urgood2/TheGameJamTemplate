#version 300 es
precision mediump float;

precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform float fireball_scale_y;
uniform float glow_scale_y;
uniform float glow_strength;
uniform float glow_intensity;
uniform sampler2D noise;
uniform sampler2D noise2;
uniform sampler2D colo_curve;
uniform int pixel_size;
uniform vec2 glow_position;
uniform vec2 glow_size;
uniform bool pulsate;
uniform float pulsation_speed;
uniform float glow_intensity_start;
uniform float glow_intensity_stop;
uniform float iTime;

out vec4 finalColor;

vec4 f1(vec2 uv, float time) {
    vec4 nv2 = texture(noise, uv + vec2(time, 0.0));
    vec4 n2v2 = texture(noise2, uv + vec2(time * 0.8, 0.0));
    nv2.r = max(0.0, nv2.r + uv.x - 1.0);
    n2v2.r = max(0.0, n2v2.r + uv.x - 1.0);
    return nv2 * n2v2;
}

void main() {
    vec2 mUV = (fragTexCoord - glow_position) / glow_size;
    vec2 uv = (mUV - 0.5) * 2.0 * vec2(1.0, fireball_scale_y);
    float time = iTime;
    vec2 cuv = mUV - vec2(0.5);
    float d2c = length(cuv);
    vec4 color = fragColor;

    color *= (f1(uv, time) + f1(uv + vec2(0.1, 0.0), time + 11.514) + f1(uv + vec2(0.05, 0.0), time + 14.14));

    color.r -= 1.0;
    color.r = -pow(color.r, 2.0) + 1.0;

    color.rgb = texture(colo_curve, vec2(color.r, 0.0)).rgb;
    float randmoo = texture(noise2, mUV + vec2(time, -time)).r;
    randmoo = mix(randmoo, 0.0, mUV.x);
    color.r *= smoothstep(0.5, 0.48 - (0.2 - min(mUV.x, 1.0) * 0.2), d2c + randmoo * 0.4);
    finalColor = color;
    finalColor.rgb = mix(finalColor.rgb, vec3(0.0), smoothstep(0.00001, 0.0, color.r));

    // light
    vec2 glowUV = (fragTexCoord - glow_position) / glow_size;
    float d2c_l = length(glowUV * vec2(1.0, glow_scale_y) - vec2(0.58, 0.5 * glow_scale_y));

    // Oscillating glow_intensity if pulsate is true, otherwise use the default glow_intensity
    float glow_intensity_value = pulsate ? mix(glow_intensity_start, glow_intensity_stop, 0.5 + 0.5 * sin(time * pulsation_speed * 3.14159 * 2.0)) : glow_intensity;

    float l = -log(d2c_l + glow_intensity_value) * glow_strength;
    float randmoo2 = texture(noise2, vec2(time, -time)).r;

    finalColor += texture(colo_curve, vec2(1.0 - d2c_l - 0.1 * randmoo2, 0.0)) * l;

    color.r *= smoothstep(0.5, 0.1, length(fragTexCoord - vec2(0.5)));

    vec2 TEXTURE_PIXEL_SIZE = 1.0 / vec2(textureSize(texture0, 0));
    vec2 pos = fragTexCoord / TEXTURE_PIXEL_SIZE;
    vec2 square = vec2(float(pixel_size), float(pixel_size));
    vec2 top_left = floor(pos / square) * square;
    vec4 total = vec4(0.0, 0.0, 0.0, 0.0);
    for (int x = int(top_left.x); x < int(top_left.x) + pixel_size; x++) {
        for (int y = int(top_left.y); y < int(top_left.y) + pixel_size; y++) {
            total += texture(texture0, vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE);
        }
    }
    finalColor -= total / float(pixel_size * pixel_size);
    finalColor *= colDiffuse;
}
