#version 300 es
precision mediump float;

// Inputs from vertex shader
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 screenVertexPos;

//TODO: there is a bug where moving to teh top left corner creates an artifact

// Uniforms
uniform sampler2D texture0;       // Texture sampler
uniform vec2 topLeftCorner;       // Top-left corner of the shape
uniform vec2 size;                // Size of the shape (width, height)
uniform float scale = 2.0;        // Scaling factor
uniform vec2 shadow_offset = vec2(-2.0, -2.0); // Default shadow offset
uniform float shadow_scale = 1.8;
uniform float blur_amount = 1.3;
uniform bool disable_rotating = false; // Disable rotating feature
uniform float sprite_rotation;        // Rotation of the sprite in degrees
uniform vec2 screen_center = vec2(700, 700);           // Center coordinate of the screen (e.g., in normalized screen coordinates)
uniform float parallax_strength = 0.003; // Strength of the parallax effect

uniform float uMin;                   // UV bounds for the sprite being rendered (From sprite atlas)
uniform float uMax;
uniform float vMin;
uniform float vMax;

uniform bool debug = false;            // Debug mode flag
uniform vec4 debugColor = vec4(1, 0, 0, 0.3); // Color for the debug border

// Output fragment color
out vec4 finalColor;

//FIXME: problem is with this method, it blurs around the edges
// sample_texture_safe: Safely sample a texture at a given UV coordinate, otherwise return a transparent color
vec4 sample_texture_safe(sampler2D tex, vec2 uv) {
    // sample within uv coordinates (for sprite sheet)
    return (uv.x < uMin || uv.x > uMax || uv.y < vMin || uv.y > vMax)
        ? vec4(0.0, 0.0, 0.0, 0.0) 
        : texture(tex, uv);
}

vec2 rotate_point(vec2 point, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(
        point.x * c - point.y * s,
        point.x * s + point.y * c
    );
}

vec2 rotate_point_around_center(vec2 point, vec2 center, float angle) {
    // Translate point to origin (relative to the center)
    vec2 translated = point - center;
    
    // Rotate the translated point
    float s = sin(angle);
    float c = cos(angle);
    vec2 rotated = vec2(
        translated.x * c - translated.y * s,
        translated.x * s + translated.y * c
    );
    
    // Translate back to the original center
    return rotated + center;
}


vec4 apply_gaussian_blur(sampler2D tex, vec2 uv, vec2 pixel_size) {
    if (blur_amount <= 0.0) return sample_texture_safe(tex, uv);

    vec4 color_blur = vec4(0.0);
    float total_weight = 0.0;
    int kernel_radius = int(blur_amount * 3.0);

    for (int x = -kernel_radius; x <= kernel_radius; x++) {
        for (int y = -kernel_radius; y <= kernel_radius; y++) {
            if (length(vec2(x, y)) > kernel_radius) continue; // Circular sampling region
            vec2 blur_offset = vec2(float(x), float(y)) * pixel_size;
            float dist = length(vec2(x, y));
            float weight = exp(-0.5 * (dist * dist) / (blur_amount * blur_amount)); // True Gaussian weight
            vec2 safe_uv = clamp(uv + blur_offset, vec2(uMin, vMin), vec2(uMax, vMax));
            color_blur += sample_texture_safe(tex, safe_uv) * weight;
            total_weight += weight;
        }
    }

    return total_weight > 0.0 ? color_blur / total_weight : vec4(0.0);
}


// Calculates a fade effect based on how far a UV coordinate is from the edges of the texture.
float calculate_fade(float coord, float scale, float min, float max) {
    float range = max - min;

    if (coord < min) {
        // Fade in when below the min
        return clamp(1.0 + ((coord - min) / (scale * range)), 0.0, 1.0);
    } else if (coord > max) {
        // Fade out when above the max
        return clamp(1.0 - ((coord - max) / (scale * range)), 0.0, 1.0);
    }

    // Fully opaque within the range
    return 1.0;
}



vec4 process_texture(vec2 uv, sampler2D tex, bool is_main, vec2 pixel_size) {
    if (is_main) {
        return sample_texture_safe(tex, uv);
    }
    
    vec4 blurred = apply_gaussian_blur(tex, uv, pixel_size); // blur is fine
    // float fade_x = calculate_fade(uv.x, shadow_scale, uMin, uMax);
    // float fade_y = calculate_fade(uv.y, shadow_scale, vMin, vMax);
    // float fade = smoothstep(0.0, 1.0, min(fade_x, fade_y)); //REVIEW: removing fade for now
    
    // return vec4(fragColor.rgb, (blurred.a - (1.0 - fragColor.a)) * fade);
    return vec4(fragColor.rgb, (blurred.a - (1.0 - fragColor.a)));
}

vec2 scaleUVWithinAtlasUVBounds(vec2 uv, float scale) {
    // Original texture coordinates
    vec2 texCoord = fragTexCoord;

    // Compute UV bounds center
    float uCenter = (uMin + uMax) * 0.5;
    float vCenter = (vMin + vMax) * 0.5;

    // Scale fragTexCoord towards the center
    vec2 scaledTexCoord = vec2(
        uCenter + (uv.x - uCenter) * scale,
        vCenter + (uv.y - vCenter) * scale
    );

    // Clamp the scaled coordinates to the UV bounds
    scaledTexCoord = clamp(scaledTexCoord, vec2(uMin, vMin), vec2(uMax, vMax));

    return scaledTexCoord;
}

float wrap(float coord, float min, float max) {
    float range = max - min;
    return mod(coord - min, range) + min;
}

void main() {
    float final_scale = max(scale, scale * shadow_scale);

    vec2 uv_range = vec2(uMax - uMin, vMax - vMin);
    vec2 pixel_size = vec2(uv_range.x / size.x, uv_range.y / size.y);

    // Compute the main texture coordinates
    vec2 scaledTexCoord = scaleUVWithinAtlasUVBounds(fragTexCoord, final_scale);
    vec4 mainColor = sample_texture_safe(texture0, scaledTexCoord) * fragColor;
    mainColor = process_texture(scaledTexCoord, texture0, true, pixel_size) * fragColor;

    // Calculate the parallax-adjusted shadow offset
    vec2 distance_from_center = screenVertexPos.xy - screen_center;
    vec2 parallax_adjusted_offset = shadow_offset - parallax_strength * distance_from_center;

    // Apply rotation if needed
    float angle = radians(sprite_rotation);
    vec2 adjusted_offset = disable_rotating 
        ? parallax_adjusted_offset 
        : rotate_point(parallax_adjusted_offset, -angle);

    // Compute shadow texture coordinates
    vec2 uvForShadowGen = fragTexCoord + adjusted_offset * pixel_size;
    uvForShadowGen = scaleUVWithinAtlasUVBounds(uvForShadowGen, final_scale);

    vec4 shadowColor = process_texture(uvForShadowGen, texture0, false, pixel_size);
    shadowColor = vec4(0.0, 0.0, 0.0, shadowColor.a);

    // Blend shadow and main texture
    finalColor = mix(shadowColor, mainColor, mainColor.a);

    // Debug mode: highlight texture bounds
    if (debug) {
        finalColor = mix(debugColor, finalColor, finalColor.a);
    }
}