#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Uniform parameters
uniform float sensitivity;
uniform sampler2D noise_texture;
uniform int material_type;  // 0=Steel, 1=Aluminium, 2=Magnesium, 3=Titanium, 4=Plastic, 5=CarbonFiber, 6=Rubber
uniform vec3 import_new_color;

out vec4 finalColor;

// Small tolerance value for color comparison
const float epsilon = 0.01;
const float edge_width = 0.13;

// Function to compare colors with a small tolerance
bool compare_colors(vec4 c1, vec4 c2) {
    return abs(c1.r - c2.r) < epsilon &&
           abs(c1.g - c2.g) < epsilon &&
           abs(c1.b - c2.b) < epsilon &&
           abs(c1.a - c2.a) < epsilon;
}

void main() {
    vec2 UV = fragTexCoord;

    // Sample the original texture
    vec4 color = texture(texture0, UV);

    // Check if the pixel is transparent
    if (color.a < 0.01) {
        finalColor = color * colDiffuse * fragColor;
        return;
    }

    // Definitions from Paint Selector for original colors
    vec4 light_origin       = vec4(0.0, 1.0, 0.0, 1.0);
    vec4 normal_origin      = vec4(1.0, 1.0, 0.0, 1.0);
    vec4 normal_dark_origin = vec4(1.0, 0.0, 0.0, 1.0);
    vec4 dark_origin        = vec4(1.0, 0.0, 1.0, 1.0);
    vec4 darker_dark_origin = vec4(0.0, 1.0, 1.0, 1.0);
    vec4 darkest_origin     = vec4(0.0, 0.0, 1.0, 1.0);

    // Corresponding new colors based on import_new_color
    vec4 light_color       = vec4(import_new_color.rgb * 1.15, 1.0);
    vec4 normal_color      = vec4(import_new_color.rgb * 1.0, 1.0);
    vec4 normal_dark_color = vec4(import_new_color.rgb * 0.92, 1.0);
    vec4 dark_color        = vec4(import_new_color.rgb * 0.7, 1.0);
    vec4 darker_dark_color = vec4(import_new_color.rgb * 0.4, 1.0);
    vec4 darkest_color     = vec4(import_new_color.rgb * 0.2, 1.0);

    // Apply the color replacement
    if (compare_colors(color, light_origin)) {
        color = light_color;
    } else if (compare_colors(color, normal_origin)) {
        color = normal_color;
    } else if (compare_colors(color, normal_dark_origin)) {
        color = normal_dark_color;
    } else if (compare_colors(color, dark_origin)) {
        color = dark_color;
    } else if (compare_colors(color, darker_dark_origin)) {
        color = darker_dark_color;
    } else if (compare_colors(color, darkest_origin)) {
        color = darkest_color;
    }

    // Define the replace_color and edge_color based on material_type
    vec4 replace_color;
    vec4 edge_color;

    if (material_type == 0) {
        // Steel
        replace_color = vec4(0.68, 0.35, 0.24, 1.0);
        edge_color    = vec4(0.4, 0.4, 0.4, 1.0);
    } else if (material_type == 1) {
        // Aluminium
        replace_color = vec4(0.58, 0.58, 0.58, 1.0);
        edge_color    = vec4(0.8, 0.8, 0.8, 1.0);
    } else if (material_type == 2) {
        // Magnesium
        replace_color = vec4(0.61, 0.62, 0.63, 1.0);
        edge_color    = vec4(0.5, 0.5, 0.5, 1.0);
    } else if (material_type == 3) {
        // Titanium
        replace_color = vec4(0.51, 0.502, 0.478, 1.0);
        edge_color    = vec4(0.49, 0.48, 0.48, 1.0);
    } else if (material_type == 4) {
        // Plastic
        replace_color = vec4(0.21, 0.21, 0.21, 1.0);
        edge_color    = vec4(0.4, 0.4, 0.4, 1.0);
    } else if (material_type == 5) {
        // Carbon Fiber
        replace_color = vec4(0.24, 0.24, 0.24, 1.0);
        edge_color    = vec4(0.45, 0.45, 0.45, 1.0);
    } else {
        // Rubber (material_type == 6)
        replace_color = vec4(0.25, 0.25, 0.25, 1.0);
        edge_color    = vec4(0.22, 0.22, 0.22, 1.0);
    }

    // Get the size of the texture in pixels
    ivec2 texSize = textureSize(texture0, 0);
    float size_x = float(texSize.x);
    float size_y = float(texSize.y);

    // Create a new UV coordinate that snaps to pixel grid for pixel-perfect effect
    vec2 UVr = vec2(floor(UV.x * size_x) / size_x, floor(UV.y * size_y) / size_y);

    // Sample the noise texture at the UVr coordinates
    float noise_value = texture(noise_texture, UVr).r;

    // Define thresholds for smoothstep
    float edge_lower = sensitivity - edge_width;
    float edge_upper = sensitivity + edge_width;

    // Calculate the interpolation factor using smoothstep
    float factor = smoothstep(edge_lower, edge_upper, noise_value);

    // Interpolate between colors based on the factor
    vec4 color1 = mix(replace_color, edge_color, factor);
    vec4 finalColorCalc = mix(color1, color, factor);

    // Preserve the original alpha
    finalColor = vec4(finalColorCalc.rgb, color.a) * colDiffuse * fragColor;
}
