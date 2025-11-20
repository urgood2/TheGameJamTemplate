#version 300 es
precision mediump float;

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform sampler2D dissolve_texture;
uniform float dissolve_value;
uniform float burn_size;
uniform vec4 burn_color;

// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 main_texture = texture(texture0, fragTexCoord);
    vec4 noise_texture = texture(dissolve_texture, fragTexCoord);

    // This is needed to avoid keeping a small burn_color dot with dissolve being 0 or 1
    float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);
    float threshold = smoothstep(noise_texture.x - burn_size_step, noise_texture.x, dissolve_value);
    float border = smoothstep(noise_texture.x, noise_texture.x + burn_size_step, dissolve_value);

    finalColor.a = main_texture.a * threshold;
    finalColor.rgb = mix(burn_color.rgb, main_texture.rgb, border);
    finalColor *= colDiffuse * fragColor;
}
