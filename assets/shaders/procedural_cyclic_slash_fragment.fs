#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// ANIMATION uniforms
uniform float progress;
uniform float derive_progress;  // 0.0 = use progress, -1.0 = use time (loop), 1.0 = use lifetime (particle)
uniform float ease_progress;    // 0.0 = no easing, -1.0 = ease in, 1.0 = ease out
uniform float time_scale;
uniform float anim_rot_amt;
uniform float time;  // TIME from Godot

// SHAPE uniforms
uniform sampler2D base_noise;
uniform sampler2D width_gradient_mask;
uniform sampler2D length_gradient_mask;
uniform sampler2D highlight;
uniform float zoom;
uniform float rotate_all;

// COLORING uniforms
uniform float emission_strength;
uniform float mix_strength;
uniform sampler2D color_lookup;

out vec4 finalColor;

#define PI 3.1415926535897932384626433832795

vec2 polar_coordinates(vec2 uv, vec2 center, float zoomm, float repeat) {
    vec2 dir = uv - center;
    float radius = length(dir) * 2.0;
    float angle = atan(dir.y, dir.x) * 1.0/(PI * 2.0);
    return mod(vec2(radius * zoomm, angle * repeat), 1.0);
}

vec2 rotate(vec2 uv, vec2 pivot, float angle) {
    mat2 rotation = mat2(vec2(sin(angle), -cos(angle)),
                        vec2(cos(angle), sin(angle)));
    uv -= pivot;
    uv = uv * rotation;
    uv += pivot;
    return uv;
}

// Easing Functions
float easeOutExpo(float x) {
    return 1.0 - pow(2.0, -10.0 * x);
}

float easeInExpo(float x) {
    return pow(2.0, 10.0 * x - 10.0);
}

float easeInOut(float x) {
    float result;
    if (x < 0.5) {
        result = (1.0 - sqrt(1.0 - pow(2.0 * x, 2.0))) / 2.0;
    } else {
        result = (sqrt(1.0 - pow(-2.0 * x + 2.0, 2.0)) + 1.0) / 2.0;
    }
    return result;
}

float get_progress() {
    float p;
    float final;

    if (derive_progress > 0.0) {
        // For particles, use a time-based alternative since we don't have LIFETIME
        p = mod(time * time_scale, 1.0);
    } else if (derive_progress < 0.0) {
        p = mod(time * time_scale, 1.0);
    } else {
        p = progress;
    }

    if (ease_progress > 0.0) {
        final = easeOutExpo(p);
    } else if (ease_progress < 0.0) {
        final = easeInExpo(p);
    } else {
        final = p;
    }

    return final;
}

void main() {
    vec2 UV = fragTexCoord;

    // Get Values
    float p = get_progress();
    vec2 aUV = polar_coordinates(rotate(UV, vec2(0.5), radians(rotate_all)), vec2(0.5), zoom, 1.0);
    vec4 b = texture(base_noise, aUV - vec2(0.0, p));
    vec4 wm = texture(width_gradient_mask, aUV);
    vec4 lm = texture(length_gradient_mask, rotate(aUV - vec2(0.0, easeInOut(p * anim_rot_amt)), vec2(0.5), radians(180.0)));

    // Combine Them
    vec4 prefinal = (b - wm) - lm;
    vec3 albe = vec3(1.0) * (texture(color_lookup, vec2(clamp(prefinal.r * UV.x, 0.0, 1.0), 0.0)).rgb * mix_strength);
    vec4 high = clamp(texture(highlight, aUV) - lm, 0.0, 1.0);

    // Apply color
    vec4 COLOR = vec4(0.0);
    COLOR.rgb = clamp(albe + high.rgb, 0.0, 1.0);
    COLOR.rgb *= clamp(albe + high.rgb, 0.0, 1.0) * (3.0 * emission_strength);

    float start = abs(cos(p * PI));
    float end = abs(cos(p * PI));
    COLOR.a *= clamp(smoothstep(start, end, prefinal.r) + smoothstep(clamp(start, 0.0, 0.2), clamp(end, 0.0, 0.2), (high.r * 0.2)), 0.0, 1.0);

    finalColor = COLOR * colDiffuse * fragColor;
}
