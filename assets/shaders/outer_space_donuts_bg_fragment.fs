#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float grayAmount;       // range 0.0 to 1.0
uniform float desaturateAmount; // range 0.0 to 1.0
uniform float speedFactor;        // e.g. 0.2 = very slow, 2.0 = very fast

uniform float u_brightness;   // Controls the overall brightness of the effect. Range: 0.0 (black) to 1.0 (full brightness).
uniform float u_noisiness;    // Controls the amount of wavy distortion. Range: 0.0 (none) to ~1.0 (very wavy).
uniform float u_hueOffset;    // Shifts the entire color palette. Range: 0.0 to 1.0 for a full spectrum shift.
uniform float u_donutWidth;   // Controls the thickness of the colored rings. Range: ~0.1 (thin) to 1.0 (thick).
// ← NEW uniform to control pixelation
uniform float pixel_filter;


uniform float iTime;
uniform vec2 iResolution;

out vec4 finalColor;

#define NOISINESS   0.445
#define HUEOFFSET   0.53
#define DONUTWIDTH  0.3

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1,311.7)), dot(p, vec2(269.5,183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
    vec2 i = floor(p + (p.x + p.y) * K1);
    vec2 a = p - i + (i.x + i.y) * K2;
    float m = step(a.y, a.x);
    vec2 o = vec2(m, 1.0 - m);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0 * K2;
    vec3 h = max(0.5 - vec3(dot(a,a), dot(b,b), dot(c,c)), 0.0);
    vec3 n = h*h*h*h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
    return dot(n, vec3(70.0));
}

vec2 cartesian2polar(vec2 cartesian){
    return vec2(atan(cartesian.x, cartesian.y), length(cartesian));
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float donutFade(float distToMid, float radius, float thickness) {
    return clamp((distToMid - radius) / thickness + 0.5, 0.0, 1.0);
}

void main() {
    // 1) compute screen-space and pixelate
    vec2 screenSize = iResolution;
    float pixel_size   = length(screenSize) / pixel_filter;
    vec2 screen_coords = fragTexCoord * screenSize;
    screen_coords      = floor(screen_coords / pixel_size) * pixel_size;
    vec2 uv            = (screen_coords - 0.5 * screenSize) / screenSize.y;
    
    // Apply speedFactor to time for animation speed control
    float time = iTime * speedFactor;
    
    // uv = (fragTexCoord * iResolution - 0.5 * iResolution) / iResolution.y;
    uv *= 3.0;

    // Apply noise distortion using the new uniform
    uv += noise(uv + (time + sin(time * 0.1) * 10.0 + vec2(cos(time * 0.144), sin(time * 0.2) * 14.0)) * 0.2) * u_noisiness;

    vec2 uvPol = cartesian2polar(uv);
    vec3 col = vec3(0.0);
    float colorAccum = 0.5;

    for (int i = 0; i < 4; i++) {
        float radius = fract(time / 3.0) * 5.0;
        if (i == 1) radius = 0.5;
        else if (i == 2) radius = 1.1;
        else if (i == 3) radius = 1.5;

        // Use the new donut width uniform
        float torus = donutFade(uvPol.y, radius, u_donutWidth);
        float contrib = min(smoothstep(torus, 1.0, 0.95), smoothstep(torus, 0.0, 0.05));
        colorAccum += contrib;
        
        // Use the new hue offset uniform
        col += hsv2rgb(vec3(torus * 1.3 + u_hueOffset, 1.0, 1.0)) * contrib;
    }

    // --- Apply final color adjustments ---

    // NEW: Apply brightness control before other effects
    col *= u_brightness;

    // Grayscale blend
    float gray = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 grayscaleColor = vec3(gray);
    col = mix(col, grayscaleColor, grayAmount);

    // Full wash-out (fade to black)
    col = mix(col, vec3(0.0), desaturateAmount);

    // --- Alpha calculation ---
    float alphaNoise = (noise(uv * 10.0 + time) + 1.0) * 0.5;
    float finalAlpha = mix(1.0, alphaNoise, desaturateAmount);

    // Output final color, combined with pipeline colors
    finalColor = vec4(col, finalAlpha) * colDiffuse * fragColor;
}