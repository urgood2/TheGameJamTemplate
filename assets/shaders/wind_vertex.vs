#version 330 core
precision mediump float;

// Attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

// Outputs
out vec2 fragTexCoord;
out vec4 fragColor;

// Uniforms
uniform mat4 mvp; // Model-View-Projection
uniform float iTime;

uniform float speed;
uniform float minStrength;
uniform float maxStrength;
uniform float strengthScale;
uniform float interval;
uniform float detail;
uniform float distortion;
uniform float heightOffset;
uniform float offset;

float getWind(vec2 vertex, vec2 uv, float time)
{
    float diff = pow(maxStrength - minStrength, 2.0);
    float strength = clamp(minStrength + diff + sin(time / interval) * diff, minStrength, maxStrength) * strengthScale;
    float wind = (sin(time) + cos(time * detail)) * strength * max(0.0, (1.0 - uv.y) - heightOffset);
    return wind;
}

void main()
{
    float time = iTime * speed + offset;

    vec3 displaced = vertexPosition;
    displaced.x += getWind(vertexPosition.xy, vertexTexCoord, time) * distortion;

    gl_Position = mvp * vec4(displaced, 1.0);
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
}
