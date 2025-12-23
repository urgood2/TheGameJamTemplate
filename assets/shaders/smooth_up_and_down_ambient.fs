#version 330 core
in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;  // Main texture
uniform vec4 colDiffuse;

out vec4 finalColor;

void main()
{
    // Simple pass-through (straight alpha: multiply RGB and alpha separately)
    vec4 tex = texture(texture0, fragTexCoord);
    vec3 rgb = tex.rgb * colDiffuse.rgb * fragColor.rgb;
    float alpha = tex.a * colDiffuse.a * fragColor.a;
    finalColor = vec4(rgb, alpha);
}
