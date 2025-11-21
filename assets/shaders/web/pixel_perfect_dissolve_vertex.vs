#version 300 es
precision mediump float;

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform valueshttps://github.com/urgood2/TheGameJamTemplate/pull/37/conflict?name=assets%252Fshaders%252Fweb%252Fpixel_perfect_dissolve_vertex.vs&base_oid=7f0ee2cdcdf6e031d2841f2a86f08dbd8ed7cfa4&head_oid=92102ba98caf238525c9d3526f9da54d0c03ce66
uniform mat4 mvp;

// Output vertex attributes (to fragment shader)
out vec2 fragTexCoord;
out vec4 fragColor;

void main()
{
    // Send vertex attributes to fragment shader
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    // Calculate final vertex position
    gl_Position = mvp*vec4(vertexPosition, 1.0);
}
