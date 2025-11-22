#version 300 es

precision mediump float;

// Input vertex attributes
in vec3 vertexPosition;   // Vertex position (x, y, z)
in vec2 vertexTexCoord;   // Vertex texture coordinates
in vec4 vertexColor;      // Vertex color
in vec3 vertexNormal;     // Vertex normal
in vec3 vertexTangent;    // Vertex tangent
in vec2 vertexTexCoord2;  // Additional texture coordinates

// Uniform values
uniform mat4 mvp;                  // Model-View-Projection matrix
uniform vec2 topLeftCorner;        // Top-left corner of the shape
uniform vec2 size;                 // Size of the shape (width, height)
uniform float scale ;         // Scaling factor for borders
uniform float shadow_scale; // shadow scale

// Outputs to fragment shader
out vec2 fragTexCoord;
out vec4 fragColor;

vec3 dummyNormal;
vec3 dummyTangent;
vec2 dummyTexCoord2;

void main() {
    // Use dummy variables
    dummyNormal = vertexNormal;
    dummyTangent = vertexTangent;
    dummyTexCoord2 = vertexTexCoord2;
    
    float final_scale = max(scale, scale * shadow_scale);

    
    // Calculate the center of the shape
    vec2 center = topLeftCorner + size * 0.5;

    // Adjust vertex position for scaling
    vec2 position2D = vertexPosition.xy;
    position2D -= center;          // Translate to origin (relative to center)
    position2D *= final_scale;           // Scale the position
    position2D += center;          // Translate back to center

    // Apply MVP matrix to the adjusted position
    gl_Position = mvp * vec4(position2D, vertexPosition.z, 1.0);

    //fragTexCoord = vertexTexCoord;
    fragTexCoord = vertexTexCoord ;


    // Pass through the vertex color
    fragColor = vertexColor;
    

}
