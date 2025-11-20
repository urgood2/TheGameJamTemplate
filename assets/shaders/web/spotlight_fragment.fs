#version 300 es
precision mediump float;

// interpolated inputs
in vec2 fragTexCoord;
in vec4 fragColor;

// built‐in Raylib uniforms
uniform sampler2D texture0;
uniform vec4     colDiffuse;

// your circle‐mask uniforms
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

    // 3) compute aspect‐corrected UV for a true circle
    float ratio       = screen_width / screen_height;
    vec2  adjustedUV  = vec2(
        mix(circle_position.x, fragTexCoord.x, ratio),
        fragTexCoord.y
    );

    // 4) distance from center, then smoothstep for feathering
    float dist       = distance(circle_position, adjustedUV);
    float edgeStart  = circle_size - feather;
    float edgeEnd    = circle_size + feather;
    float mask       = smoothstep(edgeStart, edgeEnd, dist);

    // after computing `mask = smoothstep(edgeStart, edgeEnd, dist);`
    float m = 1.0 - mask;
    // inside circle: m = 1.0, outside: m → 0.0

    vec3 darkened = base.rgb * m;       // black outside
    finalColor = vec4(darkened, base.a);

}
