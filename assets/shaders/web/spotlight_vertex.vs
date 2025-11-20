#version 300 es

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;

// Output to fragment shader
out vec2 fragTexCoord;
out vec4 fragColor;

void main() {
    // pass UV and color straight through
    fragTexCoord = vertexTexCoord;
    fragColor     = vertexColor;
    // standard MVP transform
    gl_Position   = mvp * vec4(vertexPosition, 1.0);
}
