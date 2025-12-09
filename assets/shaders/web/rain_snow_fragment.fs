#version 300 es
precision mediump float;


// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform float rain_amount;
uniform float near_rain_length;
uniform float far_rain_length;
uniform float near_rain_width;
uniform float far_rain_width;
uniform float near_rain_transparency;
uniform float far_rain_transparency;
uniform vec4 rain_color;
uniform float base_rain_speed;
uniform float additional_rain_speed;
uniform float slant;

// Output fragment color
out vec4 finalColor;

void main()
{
    float timeValue = 10000.0 + time;

    vec2 uv = vec2(0.0);
    float remainder = mod(fragTexCoord.x - fragTexCoord.y * slant, 1.0 / rain_amount);
    uv.x = (fragTexCoord.x - fragTexCoord.y * slant) - remainder;
    float rn = fract(sin(uv.x * rain_amount));
    uv.y = fract((fragTexCoord.y + rn));

    finalColor = texture(texture0, fragTexCoord);

    // No trail version (works well for snow)
    finalColor = mix(finalColor, rain_color,
        step(1.0 - (far_rain_length + (near_rain_length - far_rain_length) * rn),
             fract(uv.y - timeValue * (base_rain_speed + additional_rain_speed * rn))) *
        (far_rain_transparency + (near_rain_transparency - far_rain_transparency) * rn) *
        step(remainder * rain_amount, far_rain_width + (near_rain_width - far_rain_width) * rn));

    finalColor *= colDiffuse * fragColor;
}
