#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform float iTime;

uniform int m;
uniform int n;

uniform bool hasNeonEffect;
uniform bool hasDot;
uniform bool haszExpend;

uniform float theta;
uniform float addH;
uniform float scale;
uniform float light_disperse;
uniform float stertch;
uniform float speed;
uniform float modTime;

uniform float rotate_speed;
uniform float rotate_plane_speed;
uniform float theta_sine_change_speed;

uniform bool iswhite;
uniform bool isdarktotransparent;
uniform bool bemask;

uniform int debugMode = 0;     // ⬅ NEW! choose mode 0–5

out vec4 finalColor;

// -------------------------------------------------------------
// Utilities
// -------------------------------------------------------------
float random2(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

bool vec3lower(vec3 A, float v) {
    return (A.r <= v && A.g <= v && A.b <= v);
}

// -------------------------------------------------------------
// Main
// -------------------------------------------------------------
void main()
{
    vec2 suv = fragTexCoord - 0.5;

    float PI = 3.14159265359;
    float TAU = 6.28318530718;

    // SAFETY FIXES
    float safeScale = max(scale, 0.03);
    float angle = clamp(theta + iTime * theta_sine_change_speed, -80.0, 80.0);
    float angleRad = angle * PI / 180.0;

    vec4 COLOR = vec4(0.0);

    //--------------------------------------------
    // DEBUG VISUALIZATION MODE SHORTCUTS
    //--------------------------------------------
    if (debugMode == 1) {
        // Z-depth stripes
        float zDbg = abs(sin(iTime + suv.x * 20.0 + suv.y * 10.0));
        finalColor = vec4(vec3(zDbg), 1.0);
        return;
    }

    if (debugMode == 5) {
        // Theta/tan distortion visualization
        float th = (angle + 80.0) / 160.0;
        finalColor = vec4(th, 1.0 - th, 0.5 + 0.5*sin(iTime), 1.0);
        return;
    }

    //--------------------------------------------
    // Main Loop
    //--------------------------------------------
    for (int j = 0; j < n; j++)
    {
        float jfix = (j == 0) ? 0.001 : float(j);
        float seed = random2(vec2(2.0 - jfix, jfix * 37.0));

        for (int i = 0; i < m; i++)
        {
            float rawz = mod(
                5.0 + float(n)/jfix * 10.0 +
                iTime * speed + 8.0 + float(i) * safeScale * stertch,
                modTime
            );

            float z = rawz * safeScale;

            float aphla = seed * TAU + iTime * rotate_speed;

            float H = addH * safeScale + z * tan(angleRad);

            float zscale = haszExpend
                ? min(z + 0.06, modTime) * safeScale * modTime * 0.5
                : safeScale;

            zscale = max(zscale, 0.02);

            vec2 nuv = vec2(
                H * cos(aphla + iTime * rotate_plane_speed),
                H * sin(aphla)
            );

            //------------------------------------
            // DEBUG MODE 2: show NU VECTORS
            //------------------------------------
            if (debugMode == 2)
            {
                float d = distance(suv, nuv);
                if (d < 0.01) {
                    finalColor = vec4(1.0, 1.0, 1.0, 1.0);
                    return;
                }
                continue; // skip other effects
            }

            //------------------------------------
            // DEBUG MODE 3: neon falloff
            //------------------------------------
            if (debugMode == 3)
            {
                float d = distance(suv / zscale, nuv / zscale);
                float l = exp(-d / max(light_disperse, 0.1));
                finalColor = vec4(vec3(l), 1.0);
                return;
            }

            //------------------------------------
            // DEBUG MODE 4: contribution mask
            //------------------------------------
            if (debugMode == 4)
            {
                float contrib = 1.0 / (1.0 + float(i) + float(j));
                finalColor = vec4(contrib, float(i)/float(m), float(j)/float(n), 1.0);
                return;
            }

            //------------------------------------
            // NORMAL RENDERING
            //------------------------------------
            if (debugMode == 0)
            {
                // Neon effect
                if (hasNeonEffect)
                {
                    float d = distance(suv / zscale, nuv / zscale);
                    float l = exp(-d / max(light_disperse, 0.1));

                    vec4 L = iswhite
                        ? vec4(l)
                        : vec4(
                              random2(vec2(seed, jfix * 37.0)) * l,
                              random2(vec2(7.0 + jfix, seed)) * l,
                              random2(vec2(seed, 3.0 - jfix)) * l,
                              1.0
                          );

                    COLOR += L;
                    COLOR = min(COLOR, vec4(1.0));
                }

                // Dot mode
                if (hasDot && distance(suv, nuv) < zscale)
                {
                    COLOR = vec4(1.0);
                }
            }
        }
    }

    if (debugMode == 0)
    {
        if (isdarktotransparent) {
            COLOR = vec3lower(COLOR.rgb, 0.16) ? vec4(0.0) : COLOR;
        } else {
            COLOR = bemask
                ? (!vec3lower(COLOR.rgb,0.16) ? vec4(0.0) : COLOR)
                : COLOR;
        }

        finalColor = COLOR;
        return;
    }
}
