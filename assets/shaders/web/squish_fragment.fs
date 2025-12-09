#version 300 es
precision mediump float;


in vec2 fragTexCoord;
in vec4 fragColor;

in mat3 trans_inv;
in vec2 trans_scale;
in vec2 trans_offset;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

out vec4 finalColor;

vec2 mult_mat_inv_point(mat3 mat_inv, vec2 point) {
    vec3 result = mat_inv * vec3(point, 1.0);
    return vec2(result.x / result.z, result.y / result.z);
}

void main()
{
    vec2 warpedUV = mult_mat_inv_point(trans_inv, fragTexCoord * trans_scale + trans_offset);

    if (warpedUV.x < 0.0 || warpedUV.x > 1.0 || warpedUV.y < 0.0 || warpedUV.y > 1.0) {
        finalColor = vec4(0.0);
    } else {
        vec4 texel = texture(texture0, warpedUV);
        finalColor = texel * fragColor * colDiffuse;
    }
}
