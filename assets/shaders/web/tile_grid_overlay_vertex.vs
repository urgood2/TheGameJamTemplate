#version 300 es
precision mediump float;


// Raylib default inputs
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

// Raylib default uniforms
uniform mat4 mvp;

// Outputs to FS
out vec2 fragTexCoord;
out vec4 fragColor;
out vec2 world_position;

void main()
{
    fragTexCoord    = vertexTexCoord;
    fragColor       = vertexColor;

    // Pass along world‐space XY (for overlay lookup)
    world_position  = vertexPosition.xy;

    gl_Position     = mvp * vec4(vertexPosition, 1.0);
}