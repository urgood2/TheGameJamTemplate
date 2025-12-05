#version 330 core
precision mediump float;

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

out vec2 fragTexCoord;
out vec4 fragColor;

out mat3 invRotMat;
out vec2 worldMouseUV;
out vec2 tiltAmount; // Pass tilt to fragment shader

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
uniform float tilt_enabled;
uniform vec2 mouse_screen_pos;
uniform vec2 quad_center;
uniform vec2 quad_size;

void main()
{
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    // Derive a stable 0..1 quad-space UV from screen-space geometry so tilt math
    // is decoupled from atlas coordinates.
    vec2 safeQuadSize = max(abs(quad_size), vec2(1.0));
    vec2 quadUV = ((vertexPosition.xy - quad_center) / safeQuadSize) + vec2(0.5);

    // Compute pseudo-random subtle movement
    float tiltScale = tilt_enabled;
    float randScale = rand_trans_power * tiltScale;
    float hoverScale = hovering * tiltScale;

    float randAngle = randScale * mod(iTime * (0.9 + mod(rand_seed, 0.5)), 6.28318);
    vec2 randVec = vec2(cos(randAngle), sin(randAngle));

    // Circular ambient orbit so the tilt sweeps 360 degrees instead of just swaying.
    float orbitSpeed = 1.0 * (0.8 + mod(rand_seed, 0.4));
    float orbitAngle = iTime * orbitSpeed + rand_seed * 7.0;
    vec2 orbitVec = vec2(cos(orbitAngle), sin(orbitAngle)) * 0.04 * tiltScale;

    // Transform mouse screen position to UV offset
    vec2 localMouse = mouse_screen_pos / resolution;
    worldMouseUV = localMouse;

    // Compute mouse offset relative to the actual quad on screen
    // quad_center is the center of the sprite in screen coordinates
    // quad_size is the size of the sprite
    vec2 halfSize = max(quad_size * 0.5, vec2(1.0));
    vec2 relativeMouseDir = clamp((mouse_screen_pos - quad_center) / halfSize, -1.0, 1.0);
    
    // Screen Y goes down in screen coords
    // When mouse is above the sprite (negative relativeMouseDir.y), we want the top edge
    // to tilt toward the viewer (positive rotation around X axis)
    // Keep the sign as-is since the rotation logic handles it correctly

    // Final tilt force: hovering controls strength, add subtle random movement
    vec2 mouseForce = hoverScale * relativeMouseDir
                    + randVec * 0.01 * randScale
                    + orbitVec;
    tiltAmount = mouseForce;

    // Build rotation matrix for pseudo-3D effect
    // mouseForce.x controls rotation around Y axis (left-right tilt)
    // mouseForce.y controls rotation around X axis (up-down tilt)
    float tiltX = mouseForce.y * 0.5; // Rotation around X axis
    float tiltY = mouseForce.x * 0.5; // Rotation around Y axis
    
    // Build rotation matrices
    float cosX = cos(tiltX);
    float sinX = sin(tiltX);
    float cosY = cos(tiltY);
    float sinY = sin(tiltY);
    
    // Combined rotation matrix (Y then X rotation)
    mat3 rotX = mat3(
        1.0, 0.0, 0.0,
        0.0, cosX, -sinX,
        0.0, sinX, cosX
    );
    
    mat3 rotY = mat3(
        cosY, 0.0, sinY,
        0.0, 1.0, 0.0,
        -sinY, 0.0, cosY
    );
    
    mat3 rot = rotX * rotY;
    invRotMat = transpose(rot); // inverse of rotation for fragment shader

    // Apply vertex displacement for corner tilting
    // UV 0,0 is top-left, 1,1 is bottom-right
    // Center the UV for rotation (-0.5 to 0.5 range)
    vec2 centeredUV = quadUV - vec2(0.5);
    
    // Create 3D point on a flat plane
    vec3 point3D = vec3(centeredUV.x, centeredUV.y, 0.0);
    
    // Apply rotation
    vec3 rotatedPoint = rot * point3D;
    
    // Perspective projection factor (fake depth)
    float perspectiveStrength = abs(fov) * 50.0; // Scale fov to reasonable range
    float zOffset = rotatedPoint.z * perspectiveStrength;
    
    // Apply perspective: corners that rotate "away" should move inward
    vec2 perspectiveOffset = rotatedPoint.xy - centeredUV;
    perspectiveOffset *= quad_size * (1.0 - inset);
    
    // Additional depth-based scaling for perspective
    float depthScale = 1.0 + zOffset * 0.01;
    
    vec3 displaced = vertexPosition;
    displaced.xy += perspectiveOffset * depthScale;

    gl_Position = mvp * vec4(displaced, 1.0);
}
