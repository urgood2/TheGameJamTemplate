#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Shadow parameters
uniform float shadowAngle;      // Angle in degrees (0-360)
uniform float wallHeight;        // Shadow height multiplier
uniform ivec2 floorStart;        // Start of the floor in pixels
uniform vec4 shadowColor;        // Shadow color
uniform ivec2 shadowCutoffStart; // Cutoff from top left
uniform ivec2 shadowCutoffEnd;   // Cutoff from bottom right
uniform ivec2 shadowOffset;      // Shadow offset in pixels
uniform float maskWrap;          // 1.0 = wrap, 0.0 = no wrap
uniform sampler2D maskTop;       // Mask for Y values
uniform sampler2D maskLeft;      // Mask for X values
uniform sampler2D coverMask;     // Mask for parts in front of shadow

// Depth setup
uniform float wallDepth;
uniform int sampleMult;
uniform float floorDepthAutoCutoff;

// Tilemap setup
uniform float isTileMap;
uniform ivec2 tileSize;

out vec4 finalColor;

#define PI 3.1415926535897932384626433832795

// Tilemap converter by Award
vec2 get_tile_uvs(vec2 p_uv, vec2 p_tex_size, vec2 p_region_size) {
    vec2 uv = p_uv - p_tex_size;
    uv = fract(uv * p_tex_size / p_region_size);
    return uv * p_region_size / p_region_size;
}

void main() {
    vec2 UV = fragTexCoord;
    vec4 COLOR = texture(texture0, UV);

    vec2 uv = UV;
    vec2 tileUV = UV;

    // Change uv value for tilemap
    if (isTileMap > 0.5) {
        ivec2 texSize = textureSize(texture0, 0);
        tileUV = get_tile_uvs(UV, vec2(texSize), vec2(tileSize));
        uv = tileUV;
    }

    ivec2 texSize = textureSize(texture0, 0);
    vec2 pixSize = vec2(1.0) / vec2(texSize);
    if (isTileMap > 0.5) {
        pixSize *= vec2(texSize) / vec2(tileSize);
    }

    uv += vec2(shadowOffset) * pixSize;

    // Test for cutoff or cover mask
    vec2 modCutoff = vec2(shadowCutoffStart) * pixSize;
    vec2 modCutoffEnd = vec2(1.0) - (vec2(shadowCutoffEnd) * pixSize);

    if (clamp(tileUV, modCutoff, modCutoffEnd) == tileUV && texture(coverMask, tileUV).a == 0.0) {
        // Find direction of angle
        float angleRad = shadowAngle * (PI / 180.0);
        vec2 direct = vec2(cos(angleRad), sin(angleRad));

        vec2 depthUV = uv;
        vec2 floorCorner = vec2(floorStart) * pixSize;
        vec2 floorAutoStart = sign(uv - floorCorner);

        int maxLoops = max(int(wallDepth * 10.0) * sampleMult, 1);
        for (int loopTimeout = 0; loopTimeout < maxLoops; loopTimeout++) {
            vec2 floorDifference = depthUV - floorCorner;
            bvec2 skip = bvec2(
                sign(depthUV.x - floorCorner.x) != floorAutoStart.x && floorDepthAutoCutoff > 0.5,
                sign(depthUV.y - floorCorner.y) != floorAutoStart.y && floorDepthAutoCutoff > 0.5
            );

            // Find UV for Shadow
            vec2 flipUV = floorCorner - ((floorDifference / direct) / wallHeight);
            vec2 maskUVTop = vec2(uv.x, flipUV.y) + vec2(-(floorDifference.y / direct.y) * direct.x, 0.0);
            vec2 maskUVLeft = vec2(flipUV.x, uv.y) + vec2(0.0, -(floorDifference.x / direct.x) * direct.y);

            if (maskWrap > 0.5) {
                maskUVTop = vec2(fract(maskUVTop.x), maskUVTop.y);
                maskUVLeft = vec2(maskUVLeft.x, fract(maskUVLeft.y));
            }

            // Test if UV is beyond usual values
            bool offMaskTop = clamp(maskUVTop, vec2(0.0), vec2(1.0)) != maskUVTop;
            bool offMaskLeft = clamp(maskUVLeft, vec2(0.0), vec2(1.0)) != maskUVLeft;

            // Test if modified UV collides with mask
            if ((texture(maskTop, maskUVTop).a > 0.0 && !offMaskTop && !skip.y) ||
                (texture(maskLeft, maskUVLeft).a > 0.0 && !offMaskLeft && !skip.x)) {
                COLOR.rgb = mix(COLOR.rgb, shadowColor.rgb, shadowColor.a);
                break;
            } else {
                // Change UV for depth
                depthUV.y += (0.005 / float(sampleMult)) * sign(direct.y);
                depthUV.x += (0.005 / float(sampleMult)) * sign(direct.x);
            }
        }
    }

    finalColor = COLOR * colDiffuse * fragColor;
}
