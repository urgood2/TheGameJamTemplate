// web/cooldown_pie_fragment.fs
#version 100

precision mediump float;

varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform float cooldown_progress;
uniform float dim_amount;
uniform float flash_intensity;
uniform vec4 sprite_bounds;

const float PI = 3.14159265359;

void main() {
    vec2 localUV = (fragTexCoord - sprite_bounds.xy) / sprite_bounds.zw;
    vec2 centered = localUV - 0.5;

    float angle = atan(centered.x, -centered.y);
    float normalizedAngle = (angle + PI) / (2.0 * PI);

    float inCooldown = step(normalizedAngle, cooldown_progress);

    vec4 texColor = texture2D(texture0, fragTexCoord) * fragColor;

    vec3 dimmed = texColor.rgb * (1.0 - dim_amount * inCooldown);
    vec3 finalRGB = mix(dimmed, vec3(1.0), flash_intensity * 0.6);

    gl_FragColor = vec4(finalRGB, texColor.a);
}
