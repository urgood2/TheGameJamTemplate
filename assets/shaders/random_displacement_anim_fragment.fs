// fragment.fs
#version 330 core

in  vec2 fragTexCoord;
in  vec4 fragColor;

uniform vec4 uGridRect;   // (x, y, width, height) in pixels within the atlas
uniform vec2 uImageSize;  // (atlasWidth, atlasHeight)

uniform sampler2D texture0;
uniform vec4     colDiffuse;   // Raylib’s tint

out vec4 finalColor;


vec2 atlasUV(vec2 localUV) {
    return (uGridRect.xy + localUV * uGridRect.zw) / uImageSize;
}


void main() {
    // vec4 texel = texture(texture0, atlasUV(fragTexCoord));
    vec4 texel = texture(texture0, fragTexCoord);
    finalColor = texel * colDiffuse * fragColor;
    
    vec2 uv = fragTexCoord; // this is already atlas‐mapped if you applied step (1)
    finalColor = vec4(uv, 0.0, 1.0);
    
    // finalColor = vec4(fragTexCoord.x, fragTexCoord.y, 0.0, 1.0);

}
