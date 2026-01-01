#version 300 es
precision highp float;

// Interpolated inputs from vertex shader
in vec2 fragTexCoord;
in vec4 fragColor;

// Raylib built-in uniforms
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Lighting system uniforms
#define MAX_LIGHTS 16

uniform int u_lightCount;                       // Number of active lights (0-16)
uniform vec2 u_lightPositions[MAX_LIGHTS];      // UV-space positions (0-1)
uniform float u_lightRadii[MAX_LIGHTS];         // Radius in UV-space
uniform float u_lightIntensities[MAX_LIGHTS];   // 0-1 brightness
uniform vec3 u_lightColors[MAX_LIGHTS];         // RGB 0-1
uniform int u_lightTypes[MAX_LIGHTS];           // 0=point, 1=spot
uniform float u_lightAngles[MAX_LIGHTS];        // Spot cone half-angle (cosine)
uniform float u_lightDirections[MAX_LIGHTS];    // Spot direction in radians
uniform int u_lightBlendModes[MAX_LIGHTS];      // 0=layer default, 1=force additive

uniform float u_ambientLevel;                   // Base brightness for subtractive (0-1)
uniform int u_blendMode;                        // 0=subtractive, 1=additive
uniform float u_feather;                        // Edge softness (0-1)

uniform float screen_width;
uniform float screen_height;

out vec4 finalColor;

// Calculate contribution from a single point light
float pointLightContribution(vec2 fragPos, vec2 lightPos, float radius, float feather) {
    float dist = distance(fragPos, lightPos);
    float inner = radius * (1.0 - feather);
    float outer = radius;
    return 1.0 - smoothstep(inner, outer, dist);
}

// Calculate contribution from a spotlight
float spotLightContribution(vec2 fragPos, vec2 lightPos, float radius, float directionRad, float coneAngleCos, float feather) {
    // First get point light falloff
    float radialFalloff = pointLightContribution(fragPos, lightPos, radius, feather);
    
    // Calculate direction from light to fragment
    vec2 toFrag = normalize(fragPos - lightPos);
    
    // Light's forward direction
    vec2 lightDir = vec2(cos(directionRad), sin(directionRad));
    
    // Cone falloff based on dot product
    float dotProduct = dot(toFrag, lightDir);
    float coneFalloff = smoothstep(coneAngleCos - 0.1, coneAngleCos, dotProduct);
    
    return radialFalloff * coneFalloff;
}

void main() {
    // Sample base texture
    vec4 texel = texture(texture0, fragTexCoord);
    vec4 base = texel * colDiffuse * fragColor;
    
    // Early exit if no lights
    if (u_lightCount <= 0) {
        if (u_blendMode == 0) {
            // Subtractive with no lights = ambient only
            finalColor = vec4(base.rgb * u_ambientLevel, base.a);
        } else {
            // Additive with no lights = no change
            finalColor = base;
        }
        return;
    }
    
    // Aspect ratio correction for proper circles
    float aspect = screen_width / screen_height;
    vec2 correctedFrag = vec2(fragTexCoord.x * aspect, fragTexCoord.y);
    
    // Accumulate light contributions
    vec3 totalAdditiveLight = vec3(0.0);
    float totalSubtractiveLight = 0.0;
    
    // WebGL2 requires constant loop bounds
    for (int i = 0; i < MAX_LIGHTS; i++) {
        if (i >= u_lightCount) break;
        
        // Skip zero-intensity lights
        if (u_lightIntensities[i] <= 0.0) continue;
        
        // Correct light position for aspect ratio
        vec2 correctedLightPos = vec2(u_lightPositions[i].x * aspect, u_lightPositions[i].y);
        float correctedRadius = u_lightRadii[i] * aspect;
        
        // Calculate light contribution based on type
        float contribution;
        if (u_lightTypes[i] == 1) {
            // Spotlight
            contribution = spotLightContribution(
                correctedFrag, 
                correctedLightPos, 
                correctedRadius,
                u_lightDirections[i],
                u_lightAngles[i],
                u_feather
            );
        } else {
            // Point light (default)
            contribution = pointLightContribution(
                correctedFrag, 
                correctedLightPos, 
                correctedRadius, 
                u_feather
            );
        }
        
        // Apply intensity
        contribution *= u_lightIntensities[i];
        
        // Determine if this light is additive
        bool isAdditive = (u_blendMode == 1) || (u_lightBlendModes[i] == 1);
        
        if (isAdditive) {
            // Additive: add colored light
            totalAdditiveLight += u_lightColors[i] * contribution;
        } else {
            // Subtractive: accumulate brightness (max to prevent over-brightening)
            totalSubtractiveLight = max(totalSubtractiveLight, contribution);
        }
    }
    
    // Apply lighting based on blend mode
    vec3 result;
    if (u_blendMode == 0) {
        // Subtractive mode: ambient + lights reveal the scene
        float brightness = clamp(u_ambientLevel + totalSubtractiveLight, 0.0, 1.0);
        result = base.rgb * brightness + totalAdditiveLight;
    } else {
        // Additive mode: lights add brightness
        result = base.rgb + totalAdditiveLight;
    }
    
    // Clamp final result
    finalColor = vec4(clamp(result, 0.0, 1.0), base.a);
}
