#version 300 es
precision mediump float;


// UIEffect: Blur - Medium (9x9 kernel)
// Medium quality Gaussian blur using a 9x9 kernel

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity;     // Blur intensity (0.0-1.0)
uniform vec2 texelSize;      // Size of one texel
uniform float samplingScale; // Scale factor for blur

out vec4 finalColor;

const int KERNEL_SIZE = 9;
const float KERNEL[9] = float[](0.0438, 0.1719, 0.4566, 0.8204, 1.0, 0.8204, 0.4566, 0.1719, 0.0438);

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);

    if (intensity <= 0.0) {
        finalColor = texelColor * colDiffuse * fragColor;
        return;
    }

    vec4 sum = vec4(0.0);
    float totalWeight = 0.0;
    vec2 blur = texelSize * samplingScale * intensity * 2.0;

    // Apply 9x9 blur kernel
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
