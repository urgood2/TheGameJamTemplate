#version 300 es
precision mediump float;

precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform vec4 color;
uniform float inner_stroke_thickness;
uniform float inner_stroke_opacity;
uniform float inside_opacity;
uniform float frequency;
uniform float phase_speed;
uniform float iTime;

out vec4 finalColor;

const float PI = 3.14159265359;

void main() {
    // Final outputs
    vec4 inner_stroke;
    vec4 circle_outline;

    // INNER STROKE
    float radius = inner_stroke_thickness / float(textureSize(texture0, 0).x);
    // Initialize alpha to maximum
    float minAlpha = 1.0;

    // Sample a grid around the pixel based on the defined radius to find the minimum alpha
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(float(x), float(y)) * radius;
            float sampleAlpha = texture(texture0, fragTexCoord + offset).a;
            minAlpha = min(minAlpha, sampleAlpha);
        }
    }

    // Get the original alpha value at the fragment
    float originalAlpha = texture(texture0, fragTexCoord).a;

    // Compare and apply the inner stroke color if in the inner stroke region
    if (originalAlpha > minAlpha) {
        float innerStrokeAlpha = originalAlpha * (originalAlpha - minAlpha) * inner_stroke_opacity;
        inner_stroke = vec4(1.0, 1.0, 1.0, innerStrokeAlpha);
    } else {
        float insideAlpha = originalAlpha * inside_opacity;
        inner_stroke = vec4(1.0, 1.0, 1.0, insideAlpha);
    }
    // INNER STROKE END

    // CIRCLE OUTLINE
    vec2 pos = fragTexCoord - vec2(0.5);
    float outer_radius = inner_stroke_thickness / 2.0;
    float inner_radius = outer_radius - inner_stroke_thickness;
    float outer_circle = step(length(pos), outer_radius);
    float inner_circle = step(length(pos), inner_radius);

    float angle = atan(pos.y, pos.x);
    if (angle < 0.0) {
        angle += 2.0 * PI;
    }

    float wave = 0.5 * sin(frequency * angle + iTime * phase_speed) + 0.5;
    float ring = outer_circle - inner_circle;
    ring *= step(0.5, wave);

    circle_outline = vec4(color.rgb, ring * color.a);
    // CIRCLE OUTLINE END

    finalColor = inner_stroke * circle_outline * colDiffuse * fragColor;
}
