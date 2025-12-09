#version 300 es
precision mediump float;


// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Custom uniforms
uniform vec4 background_color;
uniform vec4 shadow_color;
uniform vec2 offset_in_pixels;
uniform sampler2D screen_texture;
uniform vec2 screen_pixel_size;

// Output fragment color
out vec4 finalColor;

void main()
{
	// Read screen texture
	vec4 current_color = textureLod(screen_texture, fragTexCoord, 0.0);

	// Check if the current color is our background color
	if (length(current_color - background_color) < 0.01) {

		vec4 offset_color = textureLod(screen_texture, fragTexCoord - offset_in_pixels * screen_pixel_size, 0.0);

		// Check if at our offset position we have a color which is not the background (meaning here we need a shadow actually)
		if (length(offset_color - background_color) > 0.01) {
			// If so set it to our shadow color
			current_color = shadow_color;
		}
	}

	finalColor = current_color;
}
