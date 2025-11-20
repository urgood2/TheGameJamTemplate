#version 300 es

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;
uniform bool do_abs;
uniform bool do_quantize;
uniform float quantize_to;
uniform vec2 sine_amplitude;
uniform vec2 sine_speed;
uniform float iTime;

out vec2 fragTexCoord;
out vec4 fragColor;

void main() {
    vec2 s = sin(iTime * sine_speed);
    if (do_abs) {
        s = abs(s);
    }

    vec3 modifiedPos = vertexPosition;
    modifiedPos.xy += s * sine_amplitude;

    if (do_quantize) {
        modifiedPos.xy = round(modifiedPos.xy / quantize_to);
        modifiedPos.xy *= quantize_to;
    }

    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(modifiedPos, 1.0);
}
