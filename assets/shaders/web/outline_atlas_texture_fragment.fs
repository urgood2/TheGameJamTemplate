#version 300 es
precision mediump float;

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Custom uniforms
uniform float outline_width;
uniform vec4 outline_color;
uniform vec4 uGridRect; // texture region in pixels (x, y, width, height)
uniform vec2 uImageSize; // atlas size in pixels

// Output fragment color
out vec4 finalColor;

void main()
{
    vec2 texturePixelSize = 1.0 / vec2(textureSize(texture0, 0));
    vec4 color = texture(texture0, fragTexCoord);
    vec2 outline_offset = vec2(outline_width) * texturePixelSize;

    // Convert texture region to UV space
    vec4 uv_region = vec4(uGridRect.xy * texturePixelSize, uGridRect.zw * texturePixelSize);

    // If texture region size was not specified, then use entire texture
    uv_region.zw = mix(vec2(1.0), uv_region.zw, ceil(uv_region.zw));

    float uv_offset;
    float a;
    float max_a = 0.0;

    // Check top
    uv_offset = fragTexCoord.y - outline_offset.y;
    a = step(uv_region.y, uv_offset) * texture(texture0, vec2(fragTexCoord.x, uv_offset)).a;
    max_a = max(a, max_a);

    // Check bottom
    uv_offset = fragTexCoord.y + outline_offset.y;
    a = step(uv_offset, uv_region.y + uv_region.w) * texture(texture0, vec2(fragTexCoord.x, uv_offset)).a;
    max_a = max(a, max_a);

    // Check left
    uv_offset = fragTexCoord.x - outline_offset.x;
    a = step(uv_region.x, uv_offset) * texture(texture0, vec2(uv_offset, fragTexCoord.y)).a;
    max_a = max(a, max_a);

    // Check right
    uv_offset = fragTexCoord.x + outline_offset.x;
    a = step(uv_offset, uv_region.x + uv_region.z) * texture(texture0, vec2(uv_offset, fragTexCoord.y)).a;
    max_a = max(a, max_a);

    vec4 outlinedColor = mix(color, outline_color, max_a - color.a);
    finalColor = outlinedColor * colDiffuse * fragColor;
}
