#version 330 core
// palette_quantize.fs

in vec2  fragTexCoord;
in vec4  fragColor;

uniform sampler2D texture0;   // the main screen texture (bound to TEXTURE0)
uniform vec4      colDiffuse; // tint color

uniform sampler2D palette;    // your palette strip (bind to TEXTURE1)

out vec4 finalColor;

void main()
{
    vec4 src = texture(texture0, fragTexCoord);

    // get palette width at LOD 0 (assumes a horizontal 1×N strip)
    int   pSize  = textureSize(palette, 0).x;
    float invSz  = 1.0 / float(pSize);

    // sample first entry as baseline
    vec2  uv0     = vec2(invSz * 0.5, 0.5);
    vec4  best    = texture(palette, uv0);
    float bestD   = distance(best, src);

    // find the nearest palette color
    for (int i = 1; i < pSize; i++)
    {
        vec2 uv = vec2((float(i) + 0.5) * invSz, 0.5);
        vec4 c  = texture(palette, uv);
        float d = distance(c, src);
        if (d < bestD)
        {
            bestD = d;
            best  = c;
        }
    }

    // apply tint & vertex color, preserve source alpha
    finalColor = vec4(best.rgb * colDiffuse.rgb * fragColor.rgb,
                      src.a);
}
