#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float outline_width;
uniform vec4 outline_color;
uniform vec4 texture_region;

// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 color = texture(texture0, fragTexCoord);
    vec2 texelSize = 1.0 / vec2(textureSize(texture0, 0));
    vec2 outline_offset = vec2(outline_width) * texelSize;
    vec4 uv_region = vec4(texture_region.xy * texelSize, texture_region.zw * texelSize);

    // If texture region size was not specified, then use entire texture
    uv_region.zw = mix(vec2(1.0), uv_region.zw, ceil(uv_region.zw));

    float uv_offset;
    float a;
    float max_a = 0.0;

    uv_offset = fragTexCoord.y - outline_offset.y;
    a = step(uv_region.y, uv_offset) * texture(texture0, vec2(fragTexCoord.x, uv_offset)).a;
    max_a = max(a, max_a);

    uv_offset = fragTexCoord.y + outline_offset.y;
    a = step(uv_offset, uv_region.y + uv_region.w) * texture(texture0, vec2(fragTexCoord.x, uv_offset)).a;
    max_a = max(a, max_a);

    uv_offset = fragTexCoord.x - outline_offset.x;
    a = step(uv_region.x, uv_offset) * texture(texture0, vec2(uv_offset, fragTexCoord.y)).a;
    max_a = max(a, max_a);

    uv_offset = fragTexCoord.x + outline_offset.x;
    a = step(uv_offset, uv_region.x + uv_region.z) * texture(texture0, vec2(uv_offset, fragTexCoord.y)).a;
    max_a = max(a, max_a);

    finalColor = mix(color, outline_color, max_a - color.a);
    finalColor *= colDiffuse * fragColor;
}
