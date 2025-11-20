#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;
uniform vec2 mouse_position = vec2(0.0);
uniform vec2 sprite_position = vec2(0.0);
uniform float fov = 90.0;
uniform bool cull_back = true;
uniform float inset = 0.0;
uniform float max_tilt = 1.0;
uniform float max_distance = 500.0;

out vec2 fragTexCoord;
out vec4 fragColor;
out vec2 o;
flat out vec2 o_flat;
out vec3 p;
out vec2 direction_to;
out vec2 passthrough;

const float PI = 3.14159265359;

void main() {
    direction_to = mouse_position - sprite_position;
    float d = length(direction_to);
    float magnitude = min(max_tilt, d / max_distance);
    float angle = atan(direction_to.x, direction_to.y);
    float x_rota = abs(angle) / PI;
    float y_rota = abs(atan(direction_to.y, direction_to.x)) / PI;

    float sin_b = sin((-y_rota + 0.5) * magnitude * (PI / 2.0));
    float cos_b = cos((-y_rota + 0.5) * magnitude * (PI / 2.0));
    float sin_c = sin((x_rota - 0.5) * magnitude * (PI / 2.0));
    float cos_c = cos((x_rota - 0.5) * magnitude * (PI / 2.0));

    mat3 inv_rot_mat;
    inv_rot_mat[0][0] = cos_b;
    inv_rot_mat[0][1] = 0.0;
    inv_rot_mat[0][2] = -sin_b;

    inv_rot_mat[1][0] = sin_b * sin_c;
    inv_rot_mat[1][1] = cos_c;
    inv_rot_mat[1][2] = cos_b * sin_c;

    inv_rot_mat[2][0] = sin_b * cos_c;
    inv_rot_mat[2][1] = -sin_c;
    inv_rot_mat[2][2] = cos_b * cos_c;

    float t = tan(fov / 360.0 * PI);
    p = inv_rot_mat * vec3((vertexTexCoord - 0.5), 0.5 / t);
    float v = (0.5 / t) + 0.5;
    p.xy *= v * inv_rot_mat[2].z;
    o = v * inv_rot_mat[2].xy;
    o_flat = o;

    vec2 TEXTURE_PIXEL_SIZE = 1.0 / vec2(800.0, 600.0); // Approximate, adjust if needed
    vec3 modifiedPos = vertexPosition;
    modifiedPos.xy += (vertexTexCoord - 0.5) / TEXTURE_PIXEL_SIZE * t * (1.0 - inset);

    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(modifiedPos, 1.0);
}
