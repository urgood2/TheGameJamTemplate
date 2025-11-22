#version 300 es
precision mediump float;

precision mediump float;

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Custom uniforms
uniform sampler2D dissolve_texture;
uniform float dissolve_value;
uniform float burn_size;
uniform vec4 ash_color;
uniform vec4 burn_color;
uniform vec4 proburn_color;

// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 main_texture = texture(texture0, fragTexCoord);
    vec4 noise_texture = texture(dissolve_texture, fragTexCoord);

	// This is needed to avoid keeping a small burn_color dot with dissolve being 0 or 1
	// is there another way to do it?
	float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);
	float threshold = smoothstep(noise_texture.x-burn_size_step, noise_texture.x, dissolve_value);
	float border = smoothstep(noise_texture.x, noise_texture.x + burn_size_step, dissolve_value);

	finalColor.a = main_texture.a * threshold;
	vec3 new_burn_color1 = mix(proburn_color.rgb, burn_color.rgb, 1.0-pow(1.0-border, 5.0));
	vec3 new_burn_color2 = mix(ash_color.rgb, new_burn_color1, 1.0-pow(1.0-border, 1000.0));
	finalColor.rgb = mix(new_burn_color2, main_texture.rgb, border);
	finalColor *= colDiffuse * fragColor;
}
