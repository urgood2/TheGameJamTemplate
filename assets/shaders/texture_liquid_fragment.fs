#version 330 core
// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Water effect uniforms
uniform vec4 waterColor1;
uniform vec4 waterColor2;
uniform float waterLevelPercentage;
uniform float waveFrequency1;
uniform float waveAmplitude1;
uniform float waveFrequency2;
uniform float waveAmplitude2;
uniform float iTime;

// Output fragment color
out vec4 finalColor;

// Simple noise function to generate random values
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth noise function to create more natural noise
float smoothNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(rand(i), rand(i + vec2(1.0, 0.0)), u.x),
        mix(rand(i + vec2(0.0, 1.0)), rand(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

// Encapsulates wave calculation logic
float calculateWaveOffset(float frequency, float amplitude, float timeMultiplier, vec2 uv) {
    return sin(uv.x * frequency + iTime * timeMultiplier) * amplitude;
}

// Encapsulates color blending logic
vec4 blendWaterColor(vec4 baseColor, vec4 waterColor, float mask) {
    return mix(baseColor, waterColor, waterColor.a * mask);
}

void main()
{
    vec2 uv = fragTexCoord;
    // Get texture color
    vec4 texColor = texture(texture0, uv);
    // Use texture alpha as mask
    float mask = texColor.a;

    // Calculate first wave offset
    float waveOffset1 = calculateWaveOffset(waveFrequency1, waveAmplitude1, 2.0, uv);
    // Calculate second wave offset
    float waveOffset2 = calculateWaveOffset(waveFrequency2, waveAmplitude2, 3.0, uv);

    // Adjusted water level for first wave
    float waterLevel1 = 1.0 - waterLevelPercentage + waveOffset1;
    // Adjusted water level for second wave
    float waterLevel2 = 1.0 - waterLevelPercentage + waveOffset2;

    // Determine if below first wave water level
    bool isBelowWater1 = uv.y >= waterLevel1;
    // Determine if below second wave water level
    bool isBelowWater2 = uv.y >= waterLevel2;

    // Add noise and animation to simulate water flow
    vec2 noiseUv = uv * 10.0 + vec2(iTime * 0.5, 0.0);
    float noise = smoothNoise(noiseUv);
    float noiseOffset = noise * 0.05;

    vec4 finalCol = texColor;

    if (isBelowWater1 && mask > 0.0) {
        finalCol = blendWaterColor(finalCol, waterColor1, mask);
    }

    if (isBelowWater2 && mask > 0.0) {
        finalCol = blendWaterColor(finalCol, waterColor2, mask);
    }

    finalColor = finalCol * colDiffuse * fragColor;
}
