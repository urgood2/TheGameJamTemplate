#version 330 core
// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect; // texture_region in Godot (x, y, width, height in pixels)
uniform vec2 uImageSize; // atlas texture size in pixels

// Outline uniforms
uniform float outlineWidth;
uniform vec4 outlineColor;

// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 color = texture(texture0, fragTexCoord);

    // Calculate texture pixel size
    vec2 texelSize = 1.0 / uImageSize;
    vec2 outlineOffset = vec2(outlineWidth) * texelSize;

    // Calculate UV region for the sprite
    vec4 uvRegion = vec4(uGridRect.xy * texelSize, uGridRect.zw * texelSize);

    // If texture region size was not specified, then use entire texture
    uvRegion.zw = mix(vec2(1.0), uvRegion.zw, ceil(uvRegion.zw));

    float uvOffset;
    float a;
    float maxA = 0.0;

    // Check top
    uvOffset = fragTexCoord.y - outlineOffset.y;
    a = step(uvRegion.y, uvOffset) * texture(texture0, vec2(fragTexCoord.x, uvOffset)).a;
    maxA = max(a, maxA);

    // Check bottom
    uvOffset = fragTexCoord.y + outlineOffset.y;
    a = step(uvOffset, uvRegion.y + uvRegion.w) * texture(texture0, vec2(fragTexCoord.x, uvOffset)).a;
    maxA = max(a, maxA);

    // Check left
    uvOffset = fragTexCoord.x - outlineOffset.x;
    a = step(uvRegion.x, uvOffset) * texture(texture0, vec2(uvOffset, fragTexCoord.y)).a;
    maxA = max(a, maxA);

    // Check right
    uvOffset = fragTexCoord.x + outlineOffset.x;
    a = step(uvOffset, uvRegion.x + uvRegion.z) * texture(texture0, vec2(uvOffset, fragTexCoord.y)).a;
    maxA = max(a, maxA);

    finalColor = mix(color * colDiffuse * fragColor, outlineColor, maxA - color.a);
}
