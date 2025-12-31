#version 330 core
// interpolated inputs
in vec2 fragTexCoord;
in vec4 fragColor;

// built‐in Raylib uniforms
uniform sampler2D texture0;
uniform vec4     colDiffuse;

// circle‐mask uniforms
uniform float circle_size;      // radius of circle in UV‐space (0..1)
uniform float feather;          // width of the smooth edge
uniform vec2  circle_position;  // center of circle in UV (0..1)
uniform float screen_width;     // pass GetScreenWidth()
uniform float screen_height;    // pass GetScreenHeight()

out vec4 finalColor;

void main()
{
    // 1) sample your sprite/texture
    vec4 texel = texture(texture0, fragTexCoord);
    // 2) apply tint & vertex color
    vec4 base  = texel * colDiffuse * fragColor;

    // 3) compute aspect‐corrected distance for a true circle
    // Scale X coordinate so circle doesn't stretch with aspect ratio
    float aspect = screen_width / screen_height;

    // Adjust both fragment and center X by aspect ratio
    vec2 adjustedFrag = vec2(fragTexCoord.x * aspect, fragTexCoord.y);
    vec2 adjustedCenter = vec2(circle_position.x * aspect, circle_position.y);

    // 4) distance from center, then smoothstep for feathering
    float dist       = distance(adjustedFrag, adjustedCenter);
    float edgeStart  = circle_size - feather;
    float edgeEnd    = circle_size + feather;
    float mask       = smoothstep(edgeStart, edgeEnd, dist);

    // inside circle: m = 1.0, outside: m → 0.0
    float m = 1.0 - mask;

    vec3 darkened = base.rgb * m;       // black outside
    finalColor = vec4(darkened, base.a);
}
