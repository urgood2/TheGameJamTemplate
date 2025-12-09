#version 300 es
precision mediump float;


in  vec2 fragTexCoord;
in  vec4 fragColor;

uniform vec4 uGridRect;   // (x, y, width, height) in pixels within the atlas
uniform vec2 uImageSize;  // (atlasWidth, atlasHeight)

uniform sampler2D texture0;
uniform vec4     colDiffuse;   // Raylib’s tint

out vec4 finalColor;


// vec2 atlasUV(vec2 localUV) {
//     float y = (uImageSize.y - (uGridRect.y + localUV.y*uGridRect.w));
//     return vec2(uGridRect.x + localUV.x*uGridRect.z, y) / uImageSize;

// }

// non flipped version
vec2 atlasUV(vec2 localUV) {
    // Compute pixel coords inside the atlas sub-rectangle
    vec2 pixelPos = uGridRect.xy + localUV * uGridRect.zw;
    // Normalize to 0…1
    return pixelPos / uImageSize;
}


void main() {
    vec4 texel = texture(texture0, atlasUV(fragTexCoord));
    // vec4 texel = texture(texture0, fragTexCoord);
    finalColor = texel * colDiffuse * fragColor;
    
}
