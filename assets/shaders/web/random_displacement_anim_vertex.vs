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

// height of the transform of the sprite we are rendering (assum)
// your existing atlas-rect (x,y,width,height), so w==spriteHeight
uniform vec4  uGridRect;


// ——————————————————————————————————————————————————————————————————————
// Outputs to fragment shader
// ——————————————————————————————————————————————————————————————————————
out vec2 fragTexCoord;
out vec4 fragColor;

// hard coded values since I don't know why the y offset keeps changing when drawing with sprite atlases
float getRatio(float h) {
    if (h <= 32.0) {
        // 32×32
        return 0.0000001*h*h + 0.0001*h + 0.25;
    } else if (h <= 50.0) {
        // 50×50
        return 0.0000007*h*h + 0.0002*h + 0.25;
    } else if (h <= 100.0) {
        // 100×100
        return 0.000004*h*h + 0.001*h + 0.25;
    } else if (h <= 200.0) {
        // 200×200
        return 0.000010*h*h + 0.002*h + 0.25;
    } else if (h <= 300.0) {
        // 300×300
        return 0.000030*h*h + 0.002*h + 0.25;
    } else if (h <= 400.0) {
        // 400×400
        return 0.000075*h*h + 0.0001*h + 0.25;
    } else {
        // 600×600 and above
        return 0.00010*h*h + 0.0001*h + 0.25;
    } 
}
 
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
    
    // *** NEW: shift the whole sprite down in *model*-space ***
    // — now apply your piecewise ratio —  
    //float h       = uTransformHeight;              // the drawn sprite height
    //float ratio   = getRatio(h);              // picks & evaluates the right poly
    //float customOffsetY = ratio * h;                // in‐shader pixel offset
    // displaced.y  -= 15; // this magic number is necessary to offset the y, which veers off for some reason.
    
    fragTexCoord = vertexTexCoord;
    fragColor    = vertexColor;
    // transform as normal
    gl_Position  = mvp * vec4(displaced, 1.0);
}
