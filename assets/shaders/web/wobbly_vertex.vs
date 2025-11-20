#version 300 es

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;
uniform float shrink;

out vec2 fragTexCoord;
out vec4 fragColor;

void main() {
    vec2 modifiedUV = vertexTexCoord * shrink;
    modifiedUV -= vec2((shrink - 1.0) / 2.0);

    fragTexCoord = modifiedUV;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
