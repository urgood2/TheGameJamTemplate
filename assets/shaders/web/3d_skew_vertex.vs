#version 300 es

precision mediump float;

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

out vec2 fragTexCoord;
out vec4 fragColor;

out mat3 invRotMat;
out vec2 worldMouseUV;

uniform mat4 mvp;
uniform vec2 resolution;
uniform float iTime;

// Camera and distortion parameters
uniform vec2 regionRate;
uniform vec2 pivot;
uniform float fov;
uniform float y_rot;
uniform float x_rot;
uniform float inset;
uniform float hovering;
uniform float rand_trans_power;
uniform float rand_seed;
uniform float vortex_amt;
uniform float rotation;
uniform vec2 mouse_screen_pos;
uniform vec2 quad_center;
uniform vec2 quad_size;

void main()
{
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    // Compute region size from UV space
    vec2 localUV = vertexTexCoord;
    vec2 size = vec2(1.0); // Assuming full sprite region

    // Compute pseudo-random rotation vector
    float randAngle = rand_trans_power * mod(iTime * (0.9 + mod(rand_seed, 0.5)), 6.28318);
    vec2 randVec = vec2(cos(randAngle), sin(randAngle));

    // Transform mouse screen position to UV offset
    vec2 localMouse = mouse_screen_pos / resolution;
    worldMouseUV = localMouse;

    // Compute mouse offset relative to the actual quad on screen
    vec2 halfSize = max(quad_size * 0.5, vec2(1.0));
    vec2 relativeMouseDir = clamp((mouse_screen_pos - quad_center) / halfSize, -1.0, 1.0);
    relativeMouseDir.y = -relativeMouseDir.y; // screen Y goes down; convert to up

    // Final force
    vec2 mouseForce = hovering * relativeMouseDir + randVec * 0.05 * rand_trans_power;

    // Build orientation so the quad normal points toward the mouse
    vec3 forward = normalize(vec3(mouseForce.x, mouseForce.y, 1.0));
    vec3 upRef = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(upRef, forward));
    if (length(right) < 1e-4) right = vec3(1.0, 0.0, 0.0);
    vec3 up = normalize(cross(forward, right));
    mat3 rot = mat3(right, up, forward); // columns
    invRotMat = transpose(rot); // inverse of rotation

    // Apply perspective shift to vertex
    float t = tan(radians(fov) / 2.0);
    vec2 centeredUV = (localUV - pivot);
    vec2 offset = centeredUV * size * t * (1.0 - inset);

    vec3 displaced = vertexPosition;
    displaced.xy += offset;

    gl_Position = mvp * vec4(displaced, 1.0);
}
