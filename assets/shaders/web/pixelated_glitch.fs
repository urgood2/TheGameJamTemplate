#version 300 es
precision mediump float;

in vec2 fragTexCoord;

uniform sampler2D texture0;     // Main texture
uniform float pixel;      // Pixelation level
uniform vec2 redOffset;    // Red channel offset
uniform vec2 greenOffset;  // Green channel offset
uniform vec2 blueOffset;   // Blue channel offset
uniform float alpha;      // Alpha transparency modifier
uniform float randStrength;  // Strength of the random alpha variation
uniform vec4 affected;  // Area affected by the effect

out vec4 finalColor;

// Hash function for generating pseudo-random values
float Hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Pixelization function
vec2 pixelize(vec2 uv) {
    float mult = 5000.0 / (pixel * pixel);
    uv.x = floor(uv.x * mult) / mult;
    uv.y = floor(uv.y * mult) / mult;
    return uv;
}

// Chromatic aberration function
vec4 chroma(vec2 uv, sampler2D tex) {
    vec4 col = texture(tex, uv);
    if (abs(redOffset.x) + abs(redOffset.y) > 0.001) {
        col.r = texture(tex, vec2(uv.x + redOffset.x, uv.y + redOffset.y)).r;
    }
    if (abs(greenOffset.x) + abs(greenOffset.y) > 0.001) {
        col.g = texture(tex, vec2(uv.x + greenOffset.x, uv.y + greenOffset.y)).g;
    }
    if (abs(blueOffset.x) + abs(blueOffset.y) > 0.001) {
        col.b = texture(tex, vec2(uv.x + blueOffset.x, uv.y + blueOffset.y)).b;
    }
    return col;
}

void main() {
    vec2 normalUV = fragTexCoord;
    vec4 normalCol = texture(texture0, fragTexCoord);

    // Check if the current UV is within the affected area
    if (normalUV.x < affected.x || normalUV.y < affected.y || 
        normalUV.x > affected.x + affected.z || normalUV.y > affected.y + affected.a) {
        finalColor = normalCol;
    } else {
        // Apply pixelation and chromatic aberration
        vec2 uv = pixelize(fragTexCoord);
        vec4 col = chroma(uv, texture0);
        col.a *= alpha;  // Modify alpha transparency
        
        // Generate a random alpha variation
        vec2 id = floor(uv * 10.0);
        float alphaRand = Hash21(id + floor(TIME * 10.0));
        col *= (alphaRand + (randStrength * (1.0 - alphaRand)));
        
        finalColor = col;
    }
}
