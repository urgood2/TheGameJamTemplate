#version 300 es

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;
uniform float time;

// Custom uniforms for displacement
uniform float interval;
uniform float timeDelay;
uniform float intensityX;
uniform float intensityY;
uniform float seed;

// Output vertex attributes (to fragment shader)
out vec2 fragTexCoord;
out vec4 fragColor;

void main()
{
    vec3 vertex = vertexPosition;

    // Apply random displacement animation
    float chunk = floor((time + timeDelay) / interval);
    float seedNum = vertex.x + vertex.y + chunk + seed;
    float offsetX = sin(seedNum * 12.9898) * 43758.5453;
    float offsetY = sin(seedNum * 32.9472) * 94726.0482;
    offsetX = fract(offsetX);
    offsetX = offsetX * 2.0 - 1.0;
    offsetY = fract(offsetY);
    offsetY = offsetY * 2.0 - 1.0;
    vertex += vec3(offsetX * intensityX, offsetY * intensityY, 0.0);

    // Send vertex attributes to fragment shader
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    // Calculate final vertex position
    gl_Position = mvp*vec4(vertex, 1.0);
}
