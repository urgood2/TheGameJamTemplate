#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform float scroll_speed;
uniform float angle_degrees;
uniform float repeat_x;
uniform float repeat_y;
uniform float row_offset;
uniform sampler2D texture_to_scroll;

// Output fragment color
out vec4 finalColor;

void main()
{
    float angle_rad = radians(angle_degrees);
    vec2 direction = vec2(cos(angle_rad), sin(angle_rad));
    vec2 offset_uv = fragTexCoord - (time * scroll_speed * direction);

    float offset = fract(floor(offset_uv.y * repeat_y) * 0.5) > 0.0 ? (row_offset * 0.324) : 0.0;
    offset_uv.x += offset;

    vec2 scaled_uv = vec2(fract(offset_uv.x * repeat_x), fract(offset_uv.y * repeat_y));

    vec2 texelSize = vec2(1.0) / vec2(textureSize(texture_to_scroll, 0));
    vec2 snappedUV = round(scaled_uv / texelSize) * texelSize;

    finalColor = texture(texture_to_scroll, snappedUV);
    finalColor *= colDiffuse * fragColor;
}
