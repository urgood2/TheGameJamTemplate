#version 300 es
precision mediump float; 

// ——————————————————————————————————————————————————————————————————————
// Inputs (match Raylib default locations)
// ——————————————————————————————————————————————————————————————————————
in vec3  vertexPosition;
in vec2  vertexTexCoord;
in vec3  vertexNormal;
in vec4  vertexColor;

// ——————————————————————————————————————————————————————————————————————
// Uniforms
// ——————————————————————————————————————————————————————————————————————
uniform mat4 mvp;

// ——————————————————————————————————————————————————————————————————————
// Outputs to fragment shader
// ——————————————————————————————————————————————————————————————————————
out vec2 fragTexCoord;
out vec4 fragColor;

void main()
{
    fragTexCoord = vertexTexCoord;
    fragColor    = vertexColor;
    gl_Position  = mvp * vec4(vertexPosition, 1.0);
}
