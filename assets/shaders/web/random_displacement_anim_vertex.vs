#version 300 es
precision mediump float;

// ——————————————————————————————————————————————————————————————————————
// Inputs (match Raylib default locations)
// ——————————————————————————————————————————————————————————————————————
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// ——————————————————————————————————————————————————————————————————————
// Uniforms
// ——————————————————————————————————————————————————————————————————————
uniform mat4 mvp;         // model-view-projection matrix
uniform float interval;   // how often to re-seed movement
uniform float timeDelay;  // per-sprite phase offset
uniform float intensityX; // displacement strength X
uniform float intensityY; // displacement strength Y
uniform float seed;       // base random seed
uniform float iTime;      // total elapsed time in seconds

// ——————————————————————————————————————————————————————————————————————
// Outputs to fragment shader
// ——————————————————————————————————————————————————————————————————————
out vec2 fragTexCoord;
out vec4 fragColor;


void main() {
    // compute which “chunk” of time we’re in
    float chunk    = floor((iTime + timeDelay)/interval);
    // build a pseudo-random seed per-vertex
    float seedNum  = vertexPosition.x + vertexPosition.y + chunk + seed;
    // generate two noise values via sin() → large multiplier → fract()
    float offsetX  = fract(sin(seedNum * 12.9898) * 43758.5453) * 2.0 - 1.0;
    float offsetY  = fract(sin(seedNum * 32.9472) * 94726.0482) * 2.0 - 1.0;
    // apply intensity
    vec3 displaced = vertexPosition + vec3(offsetX * intensityX,
                                            offsetY * intensityY,
                                            0.0);
    
    fragTexCoord = vertexTexCoord;
    fragColor    = vertexColor;
    // transform as normal
    gl_Position  = mvp * vec4(displaced, 1.0);
}
