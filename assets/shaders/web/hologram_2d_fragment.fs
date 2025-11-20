#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform vec4 baseColor;
uniform float speed;
uniform vec4 linesColor;
uniform float linesColorIntensity;
uniform sampler2D hologramTexture;
uniform vec2 hologramTextureTiling;
uniform float iTime;

out vec4 finalColor;

vec2 tilingAndOffset(vec2 uv, vec2 tiling, vec2 offset) {
    return mod(uv * tiling + offset, 1.0);
}

void main() {
    vec2 offset = vec2(iTime * speed / 100.0);
    vec2 tiling = tilingAndOffset(fragTexCoord, hologramTextureTiling, offset);

    vec4 noise = texture(hologramTexture, tiling);

    float fresnel = 0.71;
    vec4 colorLines = linesColor * vec4(vec3(linesColorIntensity), 1.0);
    vec4 emission = colorLines * fresnel * noise;

    vec4 albedo = baseColor;
    float alpha = dot(noise.rgb, vec3(1.0));
    vec4 hologram;
    hologram.rgb = emission.rgb + (1.0 - emission.rgb) * albedo.rgb * albedo.a;
    hologram.a = emission.a + (1.0 - emission.a) * alpha;
    hologram.a = hologram.a + (1.0 - hologram.a) * albedo.a;

    vec4 texColor = texture(texture0, fragTexCoord);
    finalColor.rgb = texColor.rgb + (1.0 - texColor.rgb) * hologram.rgb;
    finalColor.a = min(texColor.a, hologram.a);
    finalColor *= colDiffuse * fragColor;
}
