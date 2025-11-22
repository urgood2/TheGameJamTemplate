#version 330 core
// Input uniforms from Raylib
uniform vec2 mouse_screen_pos; // Mouse position in screen space
uniform float screen_scale;     // Screen scaling factor (for high-DPI awareness)

in vec3 vertexPosition; // Vertex position input
in vec2 vertexTexCoord; // Vertex texture coordinate input

out vec2 fragTexCoord; // Pass texture coordinates to fragment shader

uniform mat4 mvp; // Model-View-Projection matrix

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    // Find the center of the image (assuming it's normalized to be in the range [0, 1] for simplicity)
    vec2 center = vec2(0.5, 0.5) * screen_scale;

    // Calculate the offset from the center of the image to the current vertex position
    vec2 offset = (vertex_position.xy - center);

    // Normalize the offset for rotation input (make it relative to the size of the image)
    vec2 normalized_offset = offset / length(vec2(0.5));

    // Calculate the mouse influence by measuring its position relative to the center
    vec2 mouse_offset = (mouse_screen_pos - center) / screen_scale;

    // Calculate tilt amount based on normalized offset and mouse position
    float tilt_x = 0.05 * normalized_offset.y + 0.02 * mouse_offset.y;
    float tilt_y = 0.05 * normalized_offset.x + 0.02 * mouse_offset.x;

    // Create a rotation matrix for the tilt effect
    mat4 tilt_matrix = mat4(
        1.0, 0.0, 0.0, 0.0,
        0.0, cos(tilt_x), -sin(tilt_x), 0.0,
        0.0, sin(tilt_x), cos(tilt_x), 0.0,
        0.0, 0.0, 0.0, 1.0
    ) * mat4(
        cos(tilt_y), 0.0, sin(tilt_y), 0.0,
        0.0, 1.0, 0.0, 0.0,
        -sin(tilt_y), 0.0, cos(tilt_y), 0.0,
        0.0, 0.0, 0.0, 1.0
    );

    // Apply the tilt matrix to the vertex position
    return transform_projection * tilt_matrix * vertex_position;
}

void main() {
    fragTexCoord = vertexTexCoord;
    gl_Position = position(mvp, vec4(vertexPosition, 1.0));
}