// GRID_OVERLAY.fs
#version 330

in vec2  fragTexCoord;
in vec4  fragColor;
in vec2  world_position;

uniform sampler2D texture0;
uniform sampler2D atlas;
uniform vec4   colDiffuse;


out vec4 finalColor;

void main()
{
    
    finalColor = texture(atlas,fragTexCoord) * fragColor;
 
}
