#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;
uniform int intensity = 50;

out vec2 fragTexCoord;
out vec4 fragColor;
out vec2 o;
out vec2 f;

void main() {
    // Expands the vertices so we have space to draw the outline if we were on the edge
    o = vertexPosition.xy;
    vec2 uv = (vertexTexCoord - 0.5);
    vec3 expandedPos = vertexPosition;
    expandedPos.xy += uv * float(intensity);
    f = expandedPos.xy;

    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(expandedPos, 1.0);
}
