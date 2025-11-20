#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 o;
flat in vec2 o_flat;
in vec3 p;
in vec2 direction_to;
in vec2 passthrough;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform bool cull_back;
uniform vec3 foilcolor;
uniform float threshold;
uniform float fuzziness;
uniform float period;
uniform float scroll;
uniform float normal_strength;
uniform float effect_alpha_mult;
uniform float direction;
uniform float max_tilt;
uniform float max_distance;
uniform sampler2D foil_mask;
uniform sampler2D gradient;
uniform sampler2D noise;
uniform sampler2D normal_map;

out vec4 finalColor;

const float PI = 3.14159265359;

float color_mask(vec3 mask, vec3 color, float mask_threshold, float mask_fuzziness) {
    float d = distance(mask, color);
    return clamp(1.0 - smoothstep(mask_threshold, mask_threshold + mask_fuzziness, d), 0.0, 1.0);
}

vec3 rotate_vector(vec3 v, float angleX, float angleY, float magnitude) {
    mat3 rotX = mat3(
        vec3(1.0, 0.0, 0.0),
        vec3(0.0, cos(angleX), -sin(angleX)),
        vec3(0.0, sin(angleX), cos(angleX))
    );
    mat3 rotY = mat3(
        vec3(cos(angleY), 0.0, sin(angleY)),
        vec3(0.0, 1.0, 0.0),
        vec3(-sin(angleY), 0.0, cos(angleY))
    );
    mat3 combinedRotation = rotX * rotY;
    vec3 rotatedVector = combinedRotation * v;
    rotatedVector = normalize(rotatedVector) * magnitude;
    return rotatedVector;
}

void main() {
    if (cull_back && p.z <= 0.0) discard;

    vec2 uv = (p.xy / p.z).xy - o_flat;
    vec2 adjusted_uv = uv + 0.5;

    vec4 albedo_tex = texture(texture0, adjusted_uv);
    finalColor = albedo_tex;

    vec4 mask = texture(foil_mask, adjusted_uv);
    float texture_similarity = color_mask(foilcolor, albedo_tex.rgb, threshold, fuzziness);

    float d = length(direction_to);
    float magnitude = min(max_tilt, d / max_distance);
    float angle = atan(direction_to.x, direction_to.y);
    float x_rota = abs(angle) / PI;
    float y_rota = abs(atan(direction_to.y, direction_to.x)) / PI;

    vec3 normal_map_tex = texture(normal_map, adjusted_uv).rgb * 2.0 - 1.0;
    vec3 normal = rotate_vector(vec3(1.0, 1.0, 1.0), x_rota, y_rota, magnitude * magnitude);
    normal = rotate_vector(normal, normal_map_tex.x, normal_map_tex.y, length(normal_map_tex)) * normal_strength;

    vec4 noise_tex = texture(noise, adjusted_uv);

    vec2 gradiant_sample = vec2((0.25 + (normal.y * direction * 2.0 - normal.x * (1.0 - direction) * 2.0) / 2.0 + (uv.y * direction + uv.x * (1.0 - direction)) / 2.0), 0.0);
    gradiant_sample += vec2(magnitude, 0.0) * scroll;
    gradiant_sample = mod((gradiant_sample + adjusted_uv * period), 1.0);
    vec4 gradient_tex = texture(gradient, gradiant_sample);
    float strength = effect_alpha_mult * mask.r * texture_similarity;

    finalColor.rgb = mix(albedo_tex.rgb, gradient_tex.rgb * (noise_tex.rgb * 2.0), strength);
    finalColor.a *= step(max(abs(uv.x), abs(uv.y)), 0.5);
    finalColor *= colDiffuse * fragColor;
}
