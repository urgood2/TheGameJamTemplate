#version 330

// UIEffect: Color Filter
// Applies various color blend modes: multiply, additive, subtractive, replace

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform vec4 filterColor;    // Color to blend with
uniform float intensity;     // Effect intensity (0.0-1.0)
uniform int blendMode;       // 0=none, 1=multiply, 2=additive, 3=subtractive, 4=replace, 5=multiplyLuminance, 6=multiplyAdditive
uniform float glow;          // Glow effect (reduces alpha, 0.0-1.0)

out vec4 finalColor;

// Calculate luminance using standard weights
float luminance(vec3 color) {
    return dot(color.rgb, vec3(0.299, 0.587, 0.114));
}

vec4 applyColorFilter(vec4 inColor, vec4 factor) {
    vec4 outColor = inColor;

    if (blendMode == 1) { // Multiply
        outColor.rgb = inColor.rgb * factor.rgb;
        outColor *= factor.a;
    }
    else if (blendMode == 2) { // Additive
        outColor.rgb = inColor.rgb + factor.rgb * inColor.a * factor.a;
    }
    else if (blendMode == 3) { // Subtractive
        outColor.rgb = inColor.rgb - factor.rgb * inColor.a * factor.a;
    }
    else if (blendMode == 4) { // Replace
        outColor.rgb = factor.rgb * inColor.a;
        outColor *= factor.a;
    }
    else if (blendMode == 5) { // MultiplyLuminance
        outColor.rgb = (1.0 + luminance(inColor.rgb)) * factor.rgb * factor.a / 2.0 * inColor.a;
    }
    else if (blendMode == 6) { // MultiplyAdditive
        outColor.rgb = inColor.rgb * (1.0 + factor.rgb * factor.a);
    }

    return outColor;
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Apply color filter
    vec4 filtered = applyColorFilter(color, filterColor);

    // Mix based on intensity
    color = mix(color, filtered, intensity);

    // Apply glow effect (reduces alpha)
    color.a *= 1.0 - glow * intensity;

    finalColor = color;
}
