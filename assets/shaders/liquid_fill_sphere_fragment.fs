#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform vec3 backFillColour = vec3(0.62, 1.00, 1.00);
uniform vec3 frontFillInnerColour = vec3(0.35, 1.00, 1.00);
uniform vec3 frontFillOuterColour = vec3(0.00, 0.35, 1.00);
uniform vec3 ringColour = vec3(0.00, 0.16, 0.13);
uniform vec3 fresnelColour = vec3(0.00, 0.88, 1.00);
uniform vec3 innerRingGlowColour = vec3(0.00, 1.00, 1.00);
uniform vec4 fillcolour = vec4(1.0);
uniform float ringWidth = 0.15;
uniform float innerCircleRadiusOffset = 0.0;
uniform float fill_value = 0.25;
uniform float iTime;

out vec4 finalColor;

const float PI = 3.14159265359;

// Calculate point to arc distance
float sdArc(in vec2 p, in vec2 sc, in float ra, float rb) {
    p.x = abs(p.x);
    return ((sc.y * p.x > sc.x * p.y) ? length(p - sc * ra) : abs(length(p) - ra)) - rb;
}

// Calculate 2D rotation matrix
mat2 Get2DRotationMatrix(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    vec2 V1 = vec2(c, -s);
    vec2 V2 = vec2(s, c);
    return mat2(V1, V2);
}

void main() {
    vec2 uv = ((fragTexCoord / -0.48)) + vec2(1.038, 1.038);
    vec2 normalizedCenteredUV = (uv - 0.5) * 2.0;

    // Get circle SDF -> clip 3x circles
    float circleSDF = length(uv);

    float oneMinusRingWidth = 1.0 - ringWidth;

    // 2x circles used to generate outer ring
    float circleA = step(circleSDF, 1.0);
    float circleB = step(circleSDF, oneMinusRingWidth);

    float ring = circleA - circleB;

    // 1x circle used for the actual container/shell (as its mask)
    float fillMaskCircle = step(circleSDF, oneMinusRingWidth - innerCircleRadiusOffset);

    // Ring glow
    float ringGlowCircleSDF = circleSDF - 1.0;
    const float innerRingGlowRadiusOffset = 0.15;

    float innerRingGlow = ringGlowCircleSDF + innerRingGlowRadiusOffset;
    float outerRingGlow = ringGlowCircleSDF;

    const float outerRingGlowWidth = 0.01;
    float outerRingGlowPower = 0.8;

    const float innerRingGlowWidth = 0.01;
    const float innerRingGlowPower = 1.2;

    const float outerRingGlowAnimation = 12.0;
    const float outerRingGlowAnimationRange = 0.2;

    innerRingGlow = pow(innerRingGlowWidth / innerRingGlow, innerRingGlowPower);
    innerRingGlow = clamp(innerRingGlow - fillMaskCircle, 0.0, 1.0);

    outerRingGlowPower += (sin(iTime * outerRingGlowAnimation) * outerRingGlowAnimationRange);

    outerRingGlow = pow(outerRingGlowWidth / outerRingGlow, outerRingGlowPower);
    outerRingGlow = clamp(outerRingGlow - fillMaskCircle, 0.0, 1.0);

    // Progress/fill. Animated.
    const float fillAnimationFrequency = 4.0;
    const float fillAnimationAmplitude = 0.05;

    float fillAnimationPhase = iTime * fillAnimationFrequency;

    float fillAnimation = sin(fillAnimationPhase) * fillAnimationAmplitude;

    const float waveFrequency = 2.0;
    const float waveAmplitude = 0.05;

    const float waveAnimation = 2.0;

    // Waves as repeating sine/band offsets to the horizontal gradient
    float frontWavePhase = (iTime * waveAnimation) + uv.x;
    float backWavePhase = (iTime * -waveAnimation) + uv.x;

    frontWavePhase *= waveFrequency;
    backWavePhase *= waveFrequency;

    const float backWavesPhaseOffset = PI;

    float frontWaves = sin(frontWavePhase) * waveAmplitude;
    float backWaves = sin(backWavePhase + backWavesPhaseOffset) * waveAmplitude;

    float verticalBand = sin(uv.x + (PI * 0.5)) - 0.3;
    verticalBand = smoothstep(0.1, 0.9, verticalBand);

    // Stretch waves up/down near center, synced as they bob up/down
    const float animatedVerticalBandStrength = 0.125;
    float animatedVerticalBand = verticalBand * animatedVerticalBandStrength;

    animatedVerticalBand *= sin(iTime * fillAnimationFrequency);

    frontWaves += animatedVerticalBand;
    backWaves -= animatedVerticalBand;

    // Pinch sides (mask by the vertical gradient band) so they don't move
    fillAnimation *= verticalBand;

    // Centered fill progress
    float fillProgressAnimationFrequency = 1.0;
    float fillProgressAnimationAmplitude = 0.1;

    float fillProgress = fill_value;

    fillProgress += sin((iTime * fillProgressAnimationFrequency) * PI) * fillProgressAnimationAmplitude;

    float frontFill = step(uv.y, (fillAnimation + frontWaves) + fillProgress);
    float backFill = step(uv.y, (-fillAnimation + backWaves) + fillProgress);

    frontFill *= fillMaskCircle;
    backFill *= fillMaskCircle;

    // Mask back fill to only parts that would be visible separate from frontFill
    backFill = clamp(backFill - frontFill, 0.0, 1.0);

    float fillMask = 1.0 - (frontFill + backFill);
    fillMask *= fillMaskCircle;

    float fill = frontFill + backFill;

    // Simple edge glow using radial gradient (circle SDF)
    const float fresnelOffset = 0.01;
    float fresnel = (circleSDF + fresnelOffset) * fillMask;

    const float fresnelPower = 5.0;
    fresnel = clamp(pow(fresnel, fresnelPower), 0.0, 1.0);

    const float frontFillFresnelPower = 5.0;
    const float frontFillFresnelOffset = 0.02;

    float frontFillFresnel = (circleSDF + frontFillFresnelOffset) * (1.0 - fillMask);
    frontFillFresnel = clamp(pow(frontFillFresnel, frontFillFresnelPower), 0.0, 1.0);

    // Specular reflection, drawn (stylized, like a cartoon) as two arcs
    float specularArcAngle1 = radians(15.0);
    float specularArcAngle2 = radians(2.0);

    float specularArcRotation1 = radians(60.0);
    float specularArcRotation2 = radians(28.0);

    vec2 specularArcSC1 = vec2(sin(specularArcAngle1), cos(specularArcAngle1));
    vec2 specularArcSC2 = vec2(sin(specularArcAngle2), cos(specularArcAngle2));

    const float specularArcOffset = 0.35;
    const float specularArcWidth = 0.07;

    vec2 specularArcUV1 = Get2DRotationMatrix(specularArcRotation1) * uv;
    vec2 specularArcUV2 = Get2DRotationMatrix(specularArcRotation2) * uv;

    float specularArc1 = sdArc(specularArcUV1, specularArcSC1, 1.0 - specularArcOffset, specularArcWidth);
    float specularArc2 = sdArc(specularArcUV2, specularArcSC2, 1.0 - specularArcOffset, specularArcWidth);

    specularArc1 = step(specularArc1, 0.0);
    specularArc2 = step(specularArc2, 0.0);

    const float specularStrength = 0.2;
    float specular = specularArc1 + specularArc2;

    specular *= specularStrength;

    // Final mask
    float mask = ring + fill + fresnel + specular;

    // Per-mask RGB colour
    vec3 frontFillColour = mix(frontFillInnerColour, frontFillOuterColour, frontFillFresnel);

    const vec3 specularColour = vec3(1.0, 1.0, 0.9);
    const vec3 outerRingGlowColour = vec3(1.0, 0.8, 0.1);

    vec3 rgb =
        (ring * ringColour) +

        (innerRingGlow * innerRingGlowColour) +
        (outerRingGlow * outerRingGlowColour) +

        ((frontFill * frontFillColour) +
        (backFill * backFillColour)) * fillcolour.rgb +
        (fresnel * fresnelColour) +
        (specular * specularColour);

    // Background gradient
    const float backgroundGradientPower = 0.6;

    float backgroundGradient = length(normalizedCenteredUV);

    backgroundGradient = pow(backgroundGradient, backgroundGradientPower);
    backgroundGradient = smoothstep(0.0, 1.0, backgroundGradient);

    vec3 backgroundGradientInnerColour = vec3(0.13, 0.0, 0.4);
    vec3 backgroundGradientOuterColour = vec3(0.0, 0.0, 0.0);

    vec3 background = mix(backgroundGradientInnerColour, backgroundGradientOuterColour, backgroundGradient);

    background = clamp(background - (fill + ring), 0.0, 1.0);

    const float backgroundStrength = 0.65;
    background *= backgroundStrength;

    rgb += background;

    finalColor = vec4(rgb, mask) * colDiffuse * fragColor;
}
