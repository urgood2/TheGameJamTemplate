#version 330 core
precision mediump float;
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

uniform mat4 mvp;
uniform float iTime;
uniform float jiggleIntensity;

out vec2 fragTexCoord;
out vec4 fragColor;

void main()
{
    vec2 jiggleOffset = vec2(
        sin(iTime * 10.0 + vertexPosition.y * 5.0) * jiggleIntensity,
        cos(iTime * 10.0 + vertexPosition.x * 5.0) * jiggleIntensity
    );
    vec3 modifiedPosition = vertexPosition + vec3(jiggleOffset, 0.0);
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(modifiedPosition, 1.0);
}