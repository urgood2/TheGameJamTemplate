#version 300 es
precision mediump float;

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform bool EnableShader;
uniform bool LinearGradient;
uniform bool ClampDist;
uniform float DistOffset;
uniform float DistAdd;
uniform int GridScale;
uniform vec4 ModulateColor;
uniform float GradientOpacity;

// Output fragment color
out vec4 finalColor;

vec2 grid(vec2 uv, vec2 tex_size) {
    return fract(uv * tex_size / vec2(float(GridScale)));
}

void main()
{
    if (EnableShader) {
        vec4 orig_color = texture(texture0, fragTexCoord);
        vec2 tex_size = vec2(textureSize(texture0, 0));

        vec2 grid_uv = grid(fragTexCoord, tex_size);
        float dist = 0.0;
        if (LinearGradient) {
            dist = 1.0 - (grid_uv.y + DistOffset);
        } else {
            dist = sqrt(pow(1.0 - (grid_uv.x + DistOffset), 2.0) + pow(1.0 - (grid_uv.y + DistOffset), 2.0));
        }
        dist += DistAdd;
        if (ClampDist) dist = clamp(dist, 0.0, 1.0);
        finalColor = mix(orig_color, ModulateColor, (1.0 - dist) * GradientOpacity);
    } else {
        finalColor = texture(texture0, fragTexCoord);
    }

    finalColor *= colDiffuse * fragColor;
}
