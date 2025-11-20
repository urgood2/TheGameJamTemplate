#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Custom uniforms
uniform float circle_size = 0.5;
uniform float feather = 0.05;
uniform vec2 circle_position = vec2(0.5, 0.5);
uniform float screen_width = 1920.0;
uniform float screen_height = 1080.0;

// Output fragment color
out vec4 finalColor;

void main()
{
    float ratio = screen_width / screen_height;
    vec2 adjusted_uv = vec2(mix(circle_position.x, fragTexCoord.x, ratio), fragTexCoord.y);
    float dist = distance(circle_position, adjusted_uv);
    float edge_start = circle_size - feather;
    float edge_end = circle_size + feather;
    float alpha = smoothstep(edge_start, edge_end, dist);

    vec4 texelColor = texture(texture0, fragTexCoord);
    texelColor.a *= alpha;

    finalColor = texelColor * colDiffuse * fragColor;
}
