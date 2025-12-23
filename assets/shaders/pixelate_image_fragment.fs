#version 330 core
in  vec2 fragTexCoord;
in  vec4 fragColor;
out vec4 finalColor;

uniform sampler2D texture0;     // your base image
uniform vec4     colDiffuse;
uniform vec2     texSize;       // full-res texture size, e.g. (800,600)
uniform float    pixelRatio;    // e.g. 0.5 for half-res, 0.25 for quarter-res, etc.

void main() {
    // 1) how many blocks across & down
    vec2 blockCount = texSize * pixelRatio;
    // 2) which block this fragment sits in
    vec2 blockIdx   = floor(fragTexCoord * blockCount);
    // 3) compute UV at the *center* of that block
    vec2 uv = (blockIdx + 0.5) / blockCount;
    // 4) sample and tint (straight alpha: multiply RGB and alpha separately)
    vec4 tex = texture(texture0, uv);
    vec3 rgb = tex.rgb * colDiffuse.rgb * fragColor.rgb;
    float alpha = tex.a * colDiffuse.a * fragColor.a;
    finalColor = vec4(rgb, alpha);
}