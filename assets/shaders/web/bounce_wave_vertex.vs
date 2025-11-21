#version 300 es
precision mediump float;

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;
uniform float time;
uniform bool do_abs;
uniform bool do_quantize;
uniform float quantize_to;
uniform vec2 sine_amplitude;
uniform vec2 sine_speed;

// Output vertex attributes (to fragment shader)
out vec2 fragTexCoord;
out vec4 fragColor;

void main()
{
    vec3 position = vertexPosition;
    vec2 s = sin(time * sine_speed);
    if (do_abs) {
        s = abs(s);
    }
    position.xy += s * sine_amplitude;
    if (do_quantize) {
        position.xy = round(position.xy / quantize_to);
        position.xy *= quantize_to;
    }

    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(position, 1.0);
}
