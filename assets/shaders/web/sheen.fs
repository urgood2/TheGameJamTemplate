#version 300 es

// raylib provided uniforms
in vec2 fragTexCoord;
in vec4 fragColor;
uniform vec4 colDiffuse;
uniform sampler2D texture0;       // Base texture

// custom uniforms here
uniform vec4 highlightColor = vec4(1, 1, 1, 1);
uniform float frequency = 0.35;
uniform float highlightSpeed = 5;
uniform float highlightWidth = 25.0;
uniform float iTime;              // Time passed from the application
uniform vec2 screenResolution = vec2(800, 600);    // Screen resolution passed as a uniform

out vec4 finalColor;

//REVIEW: battle-tested

void main()
{
    // Calculate screen-space coordinates using vertexPosition
    vec2 screenCoord = gl_FragCoord.xy;

    vec4 texelColor = texture(texture0, fragTexCoord);
    float width = 0.001 * frequency * highlightWidth / 2.0;

    // Adjust the sheen effect calculation to use screen coordinates
    float value = floor(sin(frequency * ((screenCoord.x - screenCoord.y) / screenResolution.x + iTime * highlightSpeed)) + width);
    
    vec4 outputColorBeforeSheen = texelColor * colDiffuse * fragColor;
    float highlight = value > 0.5 ? 1.0 : 0.0;
    vec3 new_color = outputColorBeforeSheen.rgb * (1.0 - highlight) + highlightColor.rgb * highlight;
    finalColor = vec4(new_color.rgb, outputColorBeforeSheen.a);
}
