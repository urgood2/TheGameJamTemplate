#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform vec2 frame_coords = vec2(0.0, 0.0);
uniform vec2 nb_frames = vec2(0.0, 0.0);
uniform vec2 velocity = vec2(0.0, 0.0);
uniform float velocity_max = 300.0;
uniform float trail_size = 6.0;
uniform float alpha_start = 0.8;
uniform float alpha_tail = 0.2;
uniform float alpha_factor = 1.2;
uniform float noise_margin = 0.68;
uniform sampler2D noise;

out vec4 finalColor;

vec2 get_mid_uv(vec2 coords, vec2 px_size) {
    float px_mid_x = 1.0 - px_size.x / 2.0;
    float px_mid_y = 1.0 - px_size.y / 2.0;
    if (coords.x < 1.0)
        px_mid_x = px_size.x * (floor(coords.x / px_size.x) + 1.0 / 2.0);
    if (coords.y < 1.0)
        px_mid_y = px_size.y * (floor(coords.y / px_size.y) + 1.0 / 2.0);
    return vec2(px_mid_x, px_mid_y);
}

void main() {
    vec2 TEXTURE_PIXEL_SIZE = 1.0 / vec2(textureSize(texture0, 0));

    finalColor = texture(texture0, fragTexCoord);

    float UV_X = (fragTexCoord.x * nb_frames.x - frame_coords.x);
    float UV_Y = (fragTexCoord.y * nb_frames.y - frame_coords.y);
    vec2 uv = vec2(UV_X, UV_Y);

    // Limit velocity to trail_size pixels max
    vec2 v_dir = normalize(velocity);
    float v_length = length(velocity) * trail_size / velocity_max;

    float alpha_step = (alpha_start - alpha_tail) / trail_size;
    float alpha = alpha_tail;

    // Convert while loop to for loop with max iterations
    for (int i = 0; i < 20; i++) {
        if (v_length <= 0.0) break;

        vec2 velo = v_length * v_dir * TEXTURE_PIXEL_SIZE;
        vec2 px_mid_uv = get_mid_uv(fragTexCoord, TEXTURE_PIXEL_SIZE) + velo;
        float noiseValue = texture(noise, px_mid_uv).r;
        vec4 new_color = texture(texture0, px_mid_uv);
        if (noiseValue > noise_margin && new_color.a > 0.0) {
            if (finalColor.a == 0.0) {
                finalColor = new_color;
                finalColor.a = new_color.a * alpha;
            }
            break;
        }
        v_length -= 0.5;
        alpha *= alpha_factor;
        alpha = min(alpha, alpha_start);
    }

    finalColor *= colDiffuse * fragColor;
}
