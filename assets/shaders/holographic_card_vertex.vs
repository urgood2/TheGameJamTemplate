#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;

// Custom uniforms
uniform vec2 mouse_position;
uniform vec2 sprite_position;
uniform float fov;
uniform bool cull_back;
uniform float inset;
uniform float max_tilt;
uniform float max_distance;
uniform vec2 texture_pixel_size;

// Output vertex attributes (to fragment shader)
out vec2 fragTexCoord;
out vec4 fragColor;
out vec2 direction_to;
out vec3 p;
flat out vec2 o;

const float PI = 3.14159265359;

void main()
{
	direction_to = mouse_position - sprite_position;
	float d = length(direction_to);
	float magnitude = min(max_tilt, d / max_distance);
	float angle = atan(direction_to.x, direction_to.y);
	float x_rota = abs(angle) / PI;
	float y_rota = abs(atan(direction_to.y, direction_to.x)) / PI;

	float sin_b = sin((-y_rota + 0.5) * magnitude * (PI / 2.0));
	float cos_b = cos((-y_rota + 0.5) * magnitude * (PI / 2.0));
	float sin_c = sin((x_rota - 0.5) * magnitude * (PI / 2.0));
	float cos_c = cos((x_rota - 0.5) * magnitude * (PI / 2.0));

	mat3 inv_rot_mat;
	inv_rot_mat[0][0] = cos_b;
	inv_rot_mat[0][1] = 0.0;
	inv_rot_mat[0][2] = -sin_b;

	inv_rot_mat[1][0] = sin_b * sin_c;
	inv_rot_mat[1][1] = cos_c;
	inv_rot_mat[1][2] = cos_b * sin_c;

	inv_rot_mat[2][0] = sin_b * cos_c;
	inv_rot_mat[2][1] = -sin_c;
	inv_rot_mat[2][2] = cos_b * cos_c;

	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((vertexTexCoord - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;

	vec3 modifiedPosition = vertexPosition + vec3((vertexTexCoord - 0.5) / texture_pixel_size * t * (1.0 - inset), 0.0);

	// Send vertex attributes to fragment shader
	fragTexCoord = vertexTexCoord;
	fragColor = vertexColor;

	// Calculate final vertex position
	gl_Position = mvp * vec4(modifiedPosition, 1.0);
}
