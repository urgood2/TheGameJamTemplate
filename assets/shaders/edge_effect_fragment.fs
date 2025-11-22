#version 330 core
in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4   colDiffuse;

// —————— edge effect parameters ——————
uniform int   edgeMode;               // 0 = None, 1 = Plain, 2 = Shiny
uniform float edgeWidth;              // width/intensity of edge
uniform int   edgeColorFilter;        // 0=None,1=Multiply,2=Additive,3=Subtractive,4=Replace,5=MultiplyLuminance,6=MultiplyAdditive,7=HsvModifier,8=Contrast
uniform vec4  edgeColor;              // the edge tint color
uniform float edgeColorGlow;          // glow factor for edge (0–1)
uniform float edgeShinyWidth;         // width of the shiny sweep
uniform float edgeShinyAutoPlaySpeed; // speed of shiny sweep
uniform float iTime;                  // time in seconds (scaled)

out vec4 finalColor;

// simple RGBA→HSV and back for HsvModifier (mode 7)
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1e-10;
    return vec3(abs(q.z + (q.w - q.y)/(6.0*d+e)), d/(q.x+e), q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz)*6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// apply one of the nine color‐filter modes
vec4 applyEdgeFilter(vec4 inCol) {
    vec4 o = inCol;
    int m = edgeColorFilter;
    if(m == 1) {
        o.rgb = inCol.rgb * edgeColor.rgb;
    } else if(m == 2) {
        o.rgb = inCol.rgb + edgeColor.rgb * inCol.a;
    } else if(m == 3) {
        o.rgb = inCol.rgb - edgeColor.rgb * inCol.a;
    } else if(m == 4) {
        o.rgb = edgeColor.rgb * inCol.a;
    } else if(m == 5) {
        float lum = dot(inCol.rgb, vec3(0.299,0.587,0.114));
        o.rgb = (1.0+lum)*edgeColor.rgb * 0.5 * inCol.a;
    } else if(m == 6) {
        o.rgb = inCol.rgb * (1.0 + edgeColor.rgb);
    } else if(m == 7) {
        vec3 hsv   = rgb2hsv(inCol.rgb);
        vec3 shift = edgeColor.rgb;
        o.rgb       = hsv2rgb(hsv + shift) * inCol.a * edgeColor.a;
        o.a         = inCol.a * edgeColor.a;
    } else if(m == 8) {
        o.rgb = ((inCol.rgb - 0.5) * (edgeColor.r + 1.0) + 0.5 + edgeColor.g * 1.5) * inCol.a * edgeColor.a;
        o.a   = inCol.a * edgeColor.a;
    }
    if(m > 0) {
        // lerp only if we actually changed something
        o = mix(inCol, o, 1.0);
        o.a *= 1.0 - edgeColorGlow;
    }
    return o;
}

// compute a simple “edge factor” via screen‐space derivative of alpha
float computeEdgeFactor(vec2 uv) {
    float a = texture(texture0, uv).a;
    vec2 d = vec2(dFdx(a), dFdy(a));
    float grad = length(d);
    // invert so edges (high grad) -> 1, flat -> 0
    return 1.0 - clamp(grad * edgeWidth, 0.0, 1.0);
}

// shiny mask
bool shinyMask(vec2 uv) {
    float ang = atan(uv.y-0.5, uv.x-0.5) / 3.141592653589793;
    float f   = fract(iTime * edgeShinyAutoPlaySpeed + ang);
    return (f < edgeShinyWidth);
}

void main() {
    vec4 src = texture(texture0, fragTexCoord);
    vec4 base = src * colDiffuse * fragColor;

    if(edgeMode == 0) {
        finalColor = base;
        return;
    }

    float e = computeEdgeFactor(fragTexCoord);
    bool sh = edgeMode == 2 ? shinyMask(fragTexCoord) : true;
    vec4  ef = applyEdgeFilter(base);

    // blend: when mode=1 (plain) sh==true always, so you get a plain rim;
    // when mode=2 (shiny) you get rim only where sh==true
    finalColor = mix(base, ef, e * float(sh));
}