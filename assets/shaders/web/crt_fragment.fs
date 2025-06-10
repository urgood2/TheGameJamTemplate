#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec4 colDiffuse;
uniform sampler2D texture0;
uniform vec2 resolution;      // Screen resolution in pixels (e.g. 320x180)

uniform float scan_line_amount;
uniform float warp_amount;
uniform float noise_amount;
uniform float interference_amount;
uniform float grille_amount;
uniform float grille_size;
uniform float vignette_amount;
uniform float vignette_intensity;
uniform float aberation_amount;
uniform float roll_line_amount;
uniform float roll_speed;
uniform float scan_line_strength;
uniform float pixel_strength;
uniform float iTime;

out vec4 finalColor;

float random(vec2 uv){
    return fract(cos(uv.x * 83.4827 + uv.y * 92.2842) * 43758.5453123);
}

vec3 fetch_pixel(vec2 uv, vec2 off){
    vec2 pos = floor(uv * resolution + off) / resolution + vec2(0.5) / resolution;

    float noise = 0.0;
    if(noise_amount > 0.0){
        noise = random(pos + fract(iTime)) * noise_amount;
    }

    if(max(abs(pos.x - 0.5), abs(pos.y - 0.5)) > 0.5){
        return vec3(0.0);
    }

    vec3 clr = texture(texture0, pos).rgb + noise;
    return clr;
}

vec2 Dist(vec2 pos){
    pos *= resolution;
    return -((pos - floor(pos)) - vec2(0.5));
}

float Gaus(float pos, float scale){
    return exp2(scale * pos * pos);
}

vec3 Horz3(vec2 pos, float off){
    vec3 b = fetch_pixel(pos, vec2(-1.0, off));
    vec3 c = fetch_pixel(pos, vec2( 0.0, off));
    vec3 d = fetch_pixel(pos, vec2( 1.0, off));
    float dst = Dist(pos).x;

    float scale = pixel_strength;
    float wb = Gaus(dst - 1.0, scale);
    float wc = Gaus(dst + 0.0, scale);
    float wd = Gaus(dst + 1.0, scale);

    return (b * wb + c * wc + d * wd) / (wb + wc + wd);
}

float Scan(vec2 pos, float off){
    float dst = Dist(pos).y;
    return Gaus(dst + off, scan_line_strength);
}

vec3 Tri(vec2 pos){
    vec3 clr = fetch_pixel(pos, vec2(0.0));
    if(scan_line_amount > 0.0){
        vec3 a = Horz3(pos, -1.0);
        vec3 b = Horz3(pos,  0.0);
        vec3 c = Horz3(pos,  1.0);

        float wa = Scan(pos, -1.0);
        float wb = Scan(pos,  0.0);
        float wc = Scan(pos,  1.0);

        vec3 scanlines = a * wa + b * wb + c * wc;
        clr = mix(clr, scanlines, scan_line_amount);
    }
    return clr;
}

vec2 warp(vec2 uv){
    vec2 delta = uv - 0.5;
    float delta2 = dot(delta.xy, delta.xy);
    float delta4 = delta2 * delta2;
    float delta_offset = delta4 * warp_amount;

    vec2 warped = uv + delta * delta_offset;
    return (warped - 0.5) / mix(1.0, 1.2, warp_amount / 5.0) + 0.5;
}

float vignette(vec2 uv){
    uv *= 1.0 - uv;
    float v = uv.x * uv.y * 15.0;
    return pow(v, vignette_intensity * vignette_amount);
}

vec3 grille(vec2 uv){
    float unit = 3.14159 / 3.0;
    float scale = 2.0 * unit / grille_size;
    float r = smoothstep(0.5, 0.8, cos(uv.x * scale - unit));
    float g = smoothstep(0.5, 0.8, cos(uv.x * scale + unit));
    float b = smoothstep(0.5, 0.8, cos(uv.x * scale + 3.0 * unit));
    return mix(vec3(1.0), vec3(r, g, b), grille_amount);
}

float roll_line(vec2 uv){
    float x = uv.y * 3.0 - iTime * roll_speed;
    float f = cos(x) * cos(x * 2.35 + 1.1) * cos(x * 4.45 + 2.3);
    float roll_line = smoothstep(0.5, 0.9, f);
    return roll_line * roll_line_amount;
}

void main()
{
    vec2 uv = fragTexCoord;
    vec2 pos = warp(uv);

    float line = 0.0;
    if(roll_line_amount > 0.0){
        line = roll_line(pos);
    }

    vec2 sq_pix = floor(pos * resolution) / resolution + vec2(0.5) / resolution;
    if(interference_amount + roll_line_amount > 0.0){
        float interference = random(sq_pix.yy + fract(iTime));
        pos.x += (interference * (interference_amount + line * 6.0)) / resolution.x;
    }

    vec3 clr = Tri(pos);

    if(aberation_amount > 0.0){
        float chromatic = aberation_amount + line * 2.0;
        vec2 chromatic_x = vec2(chromatic, 0.0) / resolution.x;
        vec2 chromatic_y = vec2(0.0, chromatic / 2.0) / resolution.y;
        float r = Tri(pos - chromatic_x).r;
        float g = Tri(pos + chromatic_y).g;
        float b = Tri(pos + chromatic_x).b;
        clr = vec3(r, g, b);
    }

    if(grille_amount > 0.0) clr *= grille(uv);

    clr *= 1.0 + scan_line_amount * 0.6 + line * 3.0 + grille_amount * 2.0;

    if(vignette_amount > 0.0) clr *= vignette(pos);

    finalColor = vec4(clr, 1.0) * fragColor * colDiffuse;
}