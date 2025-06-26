

swirling highlight
```

void main() {
    // 1) get sprite UV & original color
    vec2 spriteUV  = getSpriteUV(fragTexCoord);
    vec4 origColor = texture(texture0, spriteUV);

    // 2) center UV around (0,0) and account for aspect
    vec2 uvC = (spriteUV - 0.5) * vec2(uGridRect.z/uGridRect.w, 1.0);

    // 3) compute radius & base angle
    float r = length(uvC);
    float a = atan(uvC.y, uvC.x);

    // 4) add a time-varying swirl to the angle
    float swirlFreq = 6.0;    // number of lobes
    float swirlAmp  = 0.5;    // how tight the swirl
    float angle = a + swirlAmp * sin(swirlFreq * a + time * 1.5);

    // 5) rebuild a “swirled” UV and sample a simple radial gradient
    vec2 sw = vec2(cos(angle), sin(angle)) * r;
    float highlight = smoothstep(0.2, 0.0, r + 0.1 * sin(4.0 * angle + time));

    // 6) mask it so it only bleeds out around the perimeter
    float mask = smoothstep(0.3, 0.8, highlight);

    // 7) tint your sheen color however you like
    vec3 sheenColor = mix(vec3(1.0,0.9,0.6), vec3(0.6,0.8,1.0), 0.5 + 0.5*sin(time + r*10.0));

    // 8) composite over your sprite—soft blend so edges fade naturally
    vec3 outRgb = mix(origColor.rgb, sheenColor, mask * highlight);

    finalColor = vec4(outRgb, origColor.a);
}
```