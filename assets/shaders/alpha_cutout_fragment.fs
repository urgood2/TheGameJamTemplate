#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float alphaCutoff;  // Threshold for alpha discard (default 0.5)

out vec4 finalColor;

// Alpha cutout shader for stencil mask drawing.
// Discards fragments with alpha below threshold so stencil only writes
// where the sprite is opaque.

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    // Use alphaCutoff uniform if set, otherwise default to 0.5
    float threshold = alphaCutoff > 0.0 ? alphaCutoff : 0.5;
    
    // Discard transparent pixels - prevents stencil write for these fragments
    if (texelColor.a < threshold) {
        discard;
    }
    
    // Color doesn't matter for stencil mask (color writes are disabled)
    // but we output something reasonable in case this shader is used elsewhere
    finalColor = texelColor * colDiffuse * fragColor;
}
