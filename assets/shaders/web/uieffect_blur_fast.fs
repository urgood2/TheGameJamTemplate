#version 300 es
precision mediump float;

precision mediump float;

// UIEffect: Blur - Fast (5x5 kernel)
// Fast Gaussian blur using a 5x5 kernel

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity;     // Blur intensity (0.0-1.0)
uniform vec2 texelSize;      // Size of one texel (1.0/textureWidth, 1.0/textureHeight)
uniform float samplingScale; // Scale factor for blur (default 1.0)

out vec4 finalColor;

const int KERNEL_SIZE = 5;
const float KERNEL[5] = float[](0.2486, 0.7046, 1.0, 0.7046, 0.2486);

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);

    if (intensity <= 0.0) {
        finalColor = texelColor * colDiffuse * fragColor;
        return;
    }

    vec4 sum = vec4(0.0);
    float totalWeight = 0.0;
    vec2 blur = texelSize * samplingScale * intensity * 2.0;

    // Apply 5x5 blur kernel
    for (int x = 0; x < KERNEL_SIZE; x++) {
        vec2 offsetX = vec2(blur.x * (float(x) - float(KERNEL_SIZE) / 2.0), 0.0);
        for (int y = 0; y < KERNEL_SIZE; y++) {
            vec2 offsetY = vec2(0.0, blur.y * (float(y) - float(KERNEL_SIZE) / 2.0));
            vec2 sampleUV = fragTexCoord + offsetX + offsetY;

            float weight = KERNEL[x] * KERNEL[y];
            sum += texture(texture0, sampleUV) * weight;
            totalWeight += weight;
        }
    }

    vec4 blurred = totalWeight > 0.0 ? sum / totalWeight : vec4(0.0);
    finalColor = blurred * colDiffuse * fragColor;
}
