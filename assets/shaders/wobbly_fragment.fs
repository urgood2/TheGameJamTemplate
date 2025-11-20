#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform float alpha_tresh = 0.8;
uniform float shrink = 2.0;
uniform float offset_mul = 2.0;
uniform float coff_angle = 0.0;
uniform float coff_mul = 0.5;
uniform float coff_std = 0.2;
uniform float amp1 = 0.125;
uniform float freq1 = 4.0;
uniform float speed1 = 5.0;
uniform float amp2 = 0.125;
uniform float freq2 = 9.0;
uniform float speed2 = 1.46;
uniform sampler2D cols;
uniform sampler2D base_offset;
uniform float iTime;

out vec4 finalColor;

const float PI = 3.14159265359;

void main() {
    if (fragColor.a <= alpha_tresh) {
        float angle = atan(fragTexCoord.y - 0.5, fragTexCoord.x - 0.5);
        if (angle < 0.0) {
            angle += 2.0 * PI;
        }
        float h = amp1 * sin(angle * freq1 + iTime * speed1) + amp2 * sin(angle * freq2 + iTime * speed2);
        h += amp1 + amp2;
        float b_off = texture(base_offset, vec2(1.0 - angle / (2.0 * PI), 0.0)).r;
        h += b_off * offset_mul;
        float c_diff1 = angle - mod(coff_angle, 2.0 * PI);
        float c_diff = min(min(abs(c_diff1), abs(c_diff1 - 2.0 * PI)), abs(c_diff1 + 2.0 * PI));
        float c_off = exp(-c_diff * c_diff / (2.0 * coff_std * coff_std));
        h += c_off * coff_mul;
        h /= 2.0 * (amp1 + amp2) + offset_mul;

        float r = length(vec2(fragTexCoord.x - 0.5, fragTexCoord.y - 0.5)) * 2.0 / shrink;
        if (r < h) {
            finalColor = texture(cols, vec2(r / h, 0.0));
        } else {
            finalColor = vec4(0.0, 0.0, 0.0, 0.0);
        }
    } else {
        finalColor = fragColor;
    }
    finalColor *= colDiffuse;
}
