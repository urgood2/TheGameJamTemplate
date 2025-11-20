#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform float outlineWidth;
uniform vec4 outlineColor;

out vec4 finalColor;

void main() {
    vec4 color = texture(texture0, fragTexCoord);
    vec2 pixelSize = 1.0 / vec2(textureSize(texture0, 0));
    vec2 outlineOffset = vec2(outlineWidth) * pixelSize;

    // Calculate UV region for atlas bounds checking
    vec4 uvRegion = vec4(uGridRect.xy * pixelSize, uGridRect.zw * pixelSize);

    // If texture region size was not specified, use entire texture
    uvRegion.zw = mix(vec2(1.0), uvRegion.zw, ceil(uvRegion.zw));

    float maxAlpha = 0.0;

    // Sample top
    float uvOffsetY = fragTexCoord.y - outlineOffset.y;
    float a = step(uvRegion.y, uvOffsetY) * texture(texture0, vec2(fragTexCoord.x, uvOffsetY)).a;
    maxAlpha = max(a, maxAlpha);

    // Sample bottom
    uvOffsetY = fragTexCoord.y + outlineOffset.y;
    a = step(uvOffsetY, uvRegion.y + uvRegion.w) * texture(texture0, vec2(fragTexCoord.x, uvOffsetY)).a;
    maxAlpha = max(a, maxAlpha);

    // Sample left
    float uvOffsetX = fragTexCoord.x - outlineOffset.x;
    a = step(uvRegion.x, uvOffsetX) * texture(texture0, vec2(uvOffsetX, fragTexCoord.y)).a;
    maxAlpha = max(a, maxAlpha);

    // Sample right
    uvOffsetX = fragTexCoord.x + outlineOffset.x;
    a = step(uvOffsetX, uvRegion.x + uvRegion.z) * texture(texture0, vec2(uvOffsetX, fragTexCoord.y)).a;
    maxAlpha = max(a, maxAlpha);

    vec4 result = mix(color, outlineColor, maxAlpha - color.a);
    finalColor = result * colDiffuse * fragColor;
}
