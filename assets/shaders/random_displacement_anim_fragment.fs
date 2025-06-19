//----------------------------------------------------------------------------------
// Fragment Shader (jitter + atlas sampling)
//----------------------------------------------------------------------------------
#version 330 core

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4     colDiffuse;

// Time-based jitter controls
uniform float iTime;
uniform float interval;    // e.g. 0.5
uniform float timeDelay;   // per-sprite phase
uniform float intensityX;  // pixel jitter X
uniform float intensityY;  // pixel jitter Y
uniform float seed;        // random seed

// Atlas helpers
uniform vec4 uGridRect;    // (x,y,width,height)
uniform vec2 uImageSize;   // (atlasWidth, atlasHeight)

out vec4 finalColor;

// Simple 2D “random” based on a sin/fract trick
vec2 random2(vec2 uv) {
    // we use two different dot-products so x and y aren’t identical
    float a = dot(uv, vec2(12.9898, 78.233));
    float b = dot(uv, vec2(39.3467, 11.1353));
    return fract(sin(vec2(a, b)) * 43758.5453);
}

vec2 atlasUV(vec2 localUV) {
    // uGridRect.xy = pixel‐coords of the sprite in the atlas
    // uGridRect.zw = pixel size    of the sprite in the atlas
    // uImageSize     = atlas resolution in pixels
    return (uGridRect.xy + localUV * uGridRect.zw) / uImageSize;
}

void main()
{
    // // 1) determine which “chunk” of time we’re in
    // float chunk = floor((iTime + timeDelay) / interval);

    // // 2) compute jitter offsets in pixels
    // float offsetX = (random2(vec2(chunk + seed, seed)).x * 2.0 - 1.0) * intensityX;
    // float offsetY = (random2(vec2(chunk + seed, seed * 2.0)).y * 2.0 - 1.0) * intensityY;

    // // 3) convert to UV-space offsets
    // vec2 offsetUV = vec2(offsetX / uImageSize.x, offsetY / uImageSize.y);

    // // 4) sample your atlas at (jittered) UV
    // vec2 uv = atlasUV(fragTexCoord) + offsetUV;
    // vec4 texel = texture(texture0, uv);
    
    vec4 texel = texture(texture0, atlasUV(fragTexCoord));


    // 5) tint and output
    finalColor = texel * colDiffuse * fragColor;
}
