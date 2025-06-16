#version 300 es
precision mediump float;

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

out vec2 fragTexCoord;
out vec4 fragColor;

out mat3 trans_inv;
out vec2 trans_scale;
out vec2 trans_offset;

uniform mat4 mvp;
uniform vec2 up_left;
uniform vec2 up_right;
uniform vec2 down_right;
uniform vec2 down_left;
uniform vec2 plane_size;
uniform float squish_x ;
uniform float squish_y;


mat3 perspective_transform(vec2[4] poly) {
    float dx1 = poly[1].x - poly[2].x;
    float dx2 = poly[3].x - poly[2].x;
    float dx3 = poly[0].x - poly[1].x + poly[2].x - poly[3].x;
    float dy1 = poly[1].y - poly[2].y;
    float dy2 = poly[3].y - poly[2].y;
    float dy3 = poly[0].y - poly[1].y + poly[2].y - poly[3].y;

    float a13 = (dx3 * dy2 - dy3 * dx2) / (dx1 * dy2 - dy1 * dx2);
    float a23 = (dx1 * dy3 - dy1 * dx3) / (dx1 * dy2 - dy1 * dx2);
    float a11 = poly[1].x - poly[0].x + a13 * poly[1].x;
    float a21 = poly[3].x - poly[0].x + a23 * poly[3].x;
    float a31 = poly[0].x;
    float a12 = poly[1].y - poly[0].y + a13 * poly[1].y;
    float a22 = poly[3].y - poly[0].y + a23 * poly[3].y;
    float a32 = poly[0].y;

    mat3 transform_mat = mat3(
        vec3(a11, a12, a13),
        vec3(a21, a22, a23),
        vec3(a31, a32, 1.0)
    );

    return inverse(transform_mat);
}

void main()
{
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    vec2 poly[4] = vec2[4](up_left, up_right, down_right, down_left);
    vec2 center = vec2(0.5);
    vec2 offset = /*hover_enabled * mouse_effect */ vec2(squish_x, squish_y);




    poly[0] += vec2(-offset.x, -offset.y);
    poly[1] += vec2( offset.x, -offset.y);
    poly[2] += vec2( offset.x,  offset.y);
    poly[3] += vec2(-offset.x,  offset.y);

    trans_inv = perspective_transform(poly);

    trans_scale = vec2(
        max(max(up_right.x, down_right.x) - min(up_left.x, down_left.x), 1.0),
        max(max(down_left.y, down_right.y) - min(up_left.y, up_right.y), 1.0)
    );
    trans_offset = vec2(
        min(min(up_left.x, down_left.x), 0.0),
        min(min(up_left.y, up_right.y), 0.0)
    );

    vec2 adjusted = vertexPosition.xy * trans_scale + plane_size * trans_offset;
    gl_Position = mvp * vec4(adjusted, vertexPosition.z, 1.0);
}
