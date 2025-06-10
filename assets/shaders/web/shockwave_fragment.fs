#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec2 resolution;
uniform vec4 colDiffuse;

uniform float strength;    // 0.0 – 0.1
uniform vec2 center;       // UV center
uniform float radius;      // 0.0 – 1.0

uniform float aberration;  // 0.0 – 1.0
uniform float width;       // 0.0 – 0.1
uniform float feather;     // 0.0 – 1.0

out vec4 finalColor;

void main()
{
    vec2 uv = fragTexCoord;

    // Compensate for aspect ratio (Y scaled down)
    float aspect_ratio = resolution.y / resolution.x;
    vec2 scaled_uv = (uv - vec2(0.0, 0.5)) / vec2(1.0, aspect_ratio) + vec2(0.0, 0.5);

    vec2 dist = scaled_uv - center;
    float len = length(dist);

    // Mask to define distortion region and feathering
    float outer = smoothstep(radius - feather, radius, len);
    float inner = smoothstep(radius - width - feather, radius - width, len);
    float mask = (1.0 - outer) * inner;

    // Distortion offset
    vec2 offset = normalize(dist) * strength * mask;
    vec2 biased_uv = scaled_uv - offset;

    // Chromatic aberration offsets
    vec2 aberr_offset = offset * aberration * mask;

    // Final blended UV
    vec2 final_uv = uv * (1.0 - mask) + biased_uv * mask;

    // Channel sampling
    float r = texture(texture0, final_uv + aberr_offset).r;
    float g = texture(texture0, final_uv).g;
    float b = texture(texture0, final_uv - aberr_offset).b;

    finalColor = vec4(r, g, b, 1.0) * fragColor * colDiffuse;
}
