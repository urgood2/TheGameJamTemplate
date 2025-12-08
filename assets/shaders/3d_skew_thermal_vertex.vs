#version 330 core
precision mediump float;

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

out vec2 fragTexCoord;
out vec4 fragColor;

flat out vec2 tiltSin;
flat out vec2 tiltCos;
flat out float angleFlat;

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

    vec2 safeQuadSize = max(abs(quad_size), vec2(1.0));
    vec2 quadUV = ((vertexPosition.xy - quad_center) / safeQuadSize) + vec2(0.5);

    float tiltScale = tilt_enabled;
    float randScale = rand_trans_power * tiltScale;
    float hoverScale = hovering * tiltScale;

    float randAngle = randScale * mod(iTime * (0.9 + mod(rand_seed, 0.5)), 6.28318);
    vec2 randVec = vec2(cos(randAngle), sin(randAngle));

    float orbitSpeed = 1.0 * (0.8 + mod(rand_seed, 0.4));
    float orbitAngle = iTime * orbitSpeed + rand_seed * 7.0;
    vec2 orbitVec = vec2(cos(orbitAngle), sin(orbitAngle)) * 0.04 * tiltScale;

    vec2 halfSize = max(quad_size * 0.5, vec2(1.0));
    vec2 relativeMouseDir = clamp((mouse_screen_pos - quad_center) / halfSize, -1.0, 1.0);

    vec2 mouseForce = hoverScale * relativeMouseDir
                    + randVec * 0.01 * randScale
                    + orbitVec;

    float tiltStrength = abs(fov) * 2.0;
    float tiltXFrag = mouseForce.y * tiltStrength;
    float tiltYFrag = mouseForce.x * tiltStrength;
    tiltSin = vec2(sin(tiltXFrag), sin(tiltYFrag));
    tiltCos = vec2(cos(tiltXFrag), cos(tiltYFrag));

    float jitter = rand_trans_power * 0.05 *
        sin(iTime * (0.9 + mod(rand_seed, 0.5)) + rand_seed * 123.8985);
    angleFlat = rotation + jitter;

    float tiltXGeom = mouseForce.y * 0.5;
    float tiltYGeom = mouseForce.x * 0.5;
    float cosX = cos(tiltXGeom);
    float sinX = sin(tiltXGeom);
    float cosY = cos(tiltYGeom);
    float sinY = sin(tiltYGeom);
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

    vec2 centeredUV = quadUV - vec2(0.5);
    vec3 point3D = vec3(centeredUV.x, centeredUV.y, 0.0);
    vec3 rotatedPoint = rot * point3D;

    float perspectiveStrength = abs(fov) * 50.0;
    float zOffset = rotatedPoint.z * perspectiveStrength;

    vec2 perspectiveOffset = rotatedPoint.xy - centeredUV;
    perspectiveOffset *= quad_size * (1.0 - inset);

    float depthScale = 1.0 + zOffset * 0.01;

    vec3 displaced = vertexPosition;
    displaced.xy += perspectiveOffset * depthScale;

    gl_Position = mvp * vec4(displaced, 1.0);
}
