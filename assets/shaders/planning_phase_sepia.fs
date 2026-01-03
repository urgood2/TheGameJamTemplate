#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float u_phase_blend;
uniform float u_intensity;

out vec4 finalColor;

void main() {
    vec4 texColor = texture(texture0, fragTexCoord) * fragColor * colDiffuse;
    
    if (u_phase_blend < 0.01) {
        finalColor = texColor;
        return;
    }
    
    float gray = dot(texColor.rgb, vec3(0.299, 0.587, 0.114));
    vec3 desaturated = mix(texColor.rgb, vec3(gray), u_intensity);
    
    vec3 sepia = vec3(0.9, 0.75, 0.55);
    vec3 tinted = mix(desaturated, desaturated * sepia, u_intensity * 0.6);
    
    vec3 result = mix(texColor.rgb, tinted, u_phase_blend);
    
    finalColor = vec4(result, texColor.a);
}
