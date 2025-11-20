#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec3 color;
uniform float lineWidth;
uniform vec2 size;
uniform sampler2D noise;
uniform sampler2D noise2;
uniform float edge_fade;
uniform float wave_speed;
uniform float time;

// Output fragment color
out vec4 finalColor;

void main()
{
    float n = texture(noise, mod(fragTexCoord + (-time * wave_speed / 21.2), 1.0)).r;
    float n2 = texture(noise2, mod(fragTexCoord + 14.7 + (time * wave_speed / 40.3), 1.0)).r;
    float n3 = clamp(0.3 + pow(n + (n2 * 0.4), 3.0) * 1.5, 0.0, 1.0);
    finalColor.rgb = color + vec3(n3);

    vec2 m = 1.0 - (edge_fade * abs(fragTexCoord - 0.5) * 2.0 * size - size + 1.0 + lineWidth / 50.0);
    float ma = min(m.x, m.y);

    float uvx = mod(fragTexCoord.x - ((n3 - 0.5) / 100.0) - (mod(size.x, 2.0) / 2.0 + 0.5), 1.0 / size.x) * size.x;
    float uvy = mod(fragTexCoord.y - ((n3 - 0.5) / 100.0) - (mod(size.y, 2.0) / 2.0 + 0.5), 1.0 / size.y) * size.y;
    vec2 uv = vec2(uvx, uvy);
    vec2 w = size * max(n3, 0.5) * lineWidth / 1000.0;

    if (((uv.x >= w.x) && (uv.x <= 1.0 - w.x)) && ((uv.y >= w.y) && (uv.y <= 1.0 - w.y))) {
        discard;
    }

    finalColor.a = ma * n3;
    finalColor *= colDiffuse * fragColor;
}
