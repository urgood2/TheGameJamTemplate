#version 300 es
precision mediump float;

precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 o;
in vec2 f;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform int intensity;
uniform float precision;
uniform bool flipColors;
uniform vec4 outline_color;
uniform vec4 outline_color_2;
uniform bool use_outline_uv;
uniform bool useTexture;
uniform sampler2D outlineTexture;

out vec4 finalColor;

void main() {
    ivec2 t = textureSize(texture0, 0);
    vec2 regular_uv;
    regular_uv.x = fragTexCoord.x + (f.x - o.x) / float(t.x);
    regular_uv.y = fragTexCoord.y + (f.y - o.y) / float(t.y);

    vec4 regular_color = texture(texture0, regular_uv);

    if ((regular_uv.x < 0.0 || regular_uv.x > 1.0) || (regular_uv.y < 0.0 || regular_uv.y > 1.0) || regular_color.a <= 0.25) {
        regular_color = vec4(0.0);
    }

    vec2 TEXTURE_PIXEL_SIZE = 1.0 / vec2(textureSize(texture0, 0));
    vec2 ps = TEXTURE_PIXEL_SIZE * float(intensity) * precision;

    vec4 final_color = regular_color;
    if (regular_color.a <= 0.0) {
        for (int x = -1; x <= 1; x += 1) {
            for (int y = -1; y <= 1; y += 1) {

                // Get the X and Y offset from this
                if (x == 0 && y == 0)
                    continue;

                vec2 outline_uv = regular_uv + vec2(float(x) * ps.x, float(y) * ps.y);

                // Sample here, if we are out of bounds then fail
                vec4 outline_sample = texture(texture0, outline_uv);
                if ((outline_uv.x < 0.0 || outline_uv.x > 1.0) || (outline_uv.y < 0.0 || outline_uv.y > 1.0)) {
                    // We aren't a real color
                    outline_sample = vec4(0.0);
                }

                vec2 final_uv = use_outline_uv ? outline_uv : fragTexCoord;

                // Is our sample empty? Is there something nearby?
                if (outline_sample.a > final_color.a) {
                    if (!useTexture) {
                        final_color = mix(outline_color, outline_color_2, flipColors ? final_uv.y : final_uv.x);
                    } else {
                        vec2 uv = flipColors ? vec2(final_uv.y, final_uv.x) : final_uv;
                        vec4 outline = texture(outlineTexture, uv);
                        final_color = outline;
                    }
                }
            }
        }
    }
    finalColor = final_color * colDiffuse * fragColor;
}
