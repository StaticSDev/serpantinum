#version 320 es

precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float progress;      // 0.0 -> 1.0
uniform vec2 surface_size;

// @duration 0.24

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

void main() {
    float p = clamp(progress, 0.0, 1.0);

    float aspect = surface_size.x / max(surface_size.y, 1.0);
    vec2 centeredUv = (v_texcoord - 0.5) * vec2(aspect, 1.0);
    float dist = length(centeredUv);

    float noiseVal = gnoise(v_texcoord * vec2(6.0 * aspect, 6.0));
    float fluidSurface = dist * 0.70 + noiseVal * 0.20;

    float dissolve = (1.0 - p) * 1.25;
    if (fluidSurface > dissolve) {
        fragColor = vec4(0.0);
        return;
    }

    // Serpantinum rim glow on dissolving edge
    float edgeDist = dissolve - fluidSurface;
    float rim = (1.0 - smoothstep(0.0, 0.06, edgeDist));
    // BEGIN_SERPANTINUM_THEME_COLORS
    vec3 colMauve = vec3(0.816, 0.816, 0.816); // #d0d0d0
    vec3 colBlue  = vec3(1.000, 1.000, 1.000); // #ffffff
    // END_SERPANTINUM_THEME_COLORS
    vec3 accent = mix(colMauve, colBlue, v_texcoord.x);

    vec4 color = texture(tex, v_texcoord);
    color.rgb += accent * rim * 0.40 * (1.0 - p);
    fragColor = color * (1.0 - p);
}
