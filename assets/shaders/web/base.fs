#version 300 es
precision mediump float;

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord);

    // NOTE: Implement here your fragment shader code

    // Multiply RGB channels separately from alpha to prevent darkening
    // when opacity < 1.0 (straight alpha blending fix)
    vec3 rgb = texelColor.rgb * colDiffuse.rgb * fragColor.rgb;
    float alpha = texelColor.a * colDiffuse.a * fragColor.a;

    finalColor = vec4(rgb, alpha);
}
