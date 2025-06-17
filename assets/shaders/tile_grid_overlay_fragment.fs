// GRID_OVERLAY.fs
#version 330

in vec2  fragTexCoord;
in vec4  fragColor;
in vec2  world_position;

uniform sampler2D texture0;
uniform sampler2D atlas;
uniform vec4   colDiffuse;

uniform vec2  uImageSize;
uniform vec4  uGridRect;

uniform float scale;
uniform float base_opacity;
uniform float highlight_opacity;
uniform float distance_scaling;
uniform vec2  mouse_position;

out vec4 finalColor;

vec2 atlasUV(vec2 localUV) {
    return (uGridRect.xy + localUV * uGridRect.zw) / uImageSize;
}

void main()
{
    // compute your usual values
    vec4  sceneColor = texture(texture0, fragTexCoord)*colDiffuse*fragColor;
    vec2  gridLocal  = fract(world_position * scale);
    vec2  gridUV     = atlasUV(gridLocal);
    vec4  gridColor  = texture(texture0, gridUV);

    // NORMAL MODE: composite base + grid+highlight
    float d = distance(mouse_position, world_position);
    float n = 1.0 - clamp(d / distance_scaling, 0.0, 1.0);
    float a = gridColor.a * (base_opacity + highlight_opacity * n);
    finalColor = mix(sceneColor, gridColor, a);
    
    finalColor = texture(atlas, fragTexCoord);

}
