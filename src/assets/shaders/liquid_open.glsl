#version 320 es

precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float progress;      // 0.0 -> 1.0
uniform float seed;          // Unique per-window random seed
uniform vec2 surface_size;

// Serpantinum organic liquid condensation (500ms)
// @duration 0.50

// Hash utilities for procedural droplet distribution
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

float hash1(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Polynomial smooth minimum (surface tension droplet fusion)
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

void main() {
    float p = clamp(progress, 0.0, 1.0);

    // Instant clean pass-through when animation finishes
    if (p >= 0.999) {
        fragColor = texture(tex, v_texcoord);
        return;
    }

    float aspect = surface_size.x / max(surface_size.y, 1.0);
    vec2 centeredUv = (v_texcoord - 0.5) * vec2(aspect, 1.0);

    // Subtle domain warping (organic liquid contours, non-rigid)
    float s = seed * 0.137;
    vec2 warp = vec2(
        sin(centeredUv.y * 7.0 + s * 3.1) * 0.018,
        cos(centeredUv.x * 7.0 + s * 4.7) * 0.018
    );
    vec2 uv = centeredUv + warp;

    // Smooth progression across 500ms
    float t = smoothstep(0.0, 1.0, p);

    // Expanding fluid wave
    float r = t * 1.55;

    // Primary center condensation pool with organic non-circular contours
    float angle = atan(uv.y, uv.x);
    float centerWave = r * (1.05 + 0.06 * sin(angle * 3.0 + s * 4.3));
    float d = length(uv) - centerWave;

    // Procedural randomized droplets seeded per window
    const float k = 0.26;
    for (int gx = -1; gx <= 1; gx++) {
        for (int gy = -1; gy <= 1; gy++) {
            if (gx == 0 && gy == 0) continue;
            vec2 cell = vec2(float(gx), float(gy));
            vec2 rnd = hash2(cell * 17.3 + vec2(s * 5.3, s * 8.9));
            
            // Jittered natural droplet location
            vec2 dropPos = vec2(float(gx) * 0.42 * aspect, float(gy) * 0.32)
                         + (rnd - 0.5) * vec2(0.24 * aspect, 0.16);

            float dropSize  = 0.60 + 0.35 * hash1(cell * 29.1 + vec2(s * 11.7));
            float dropDelay = 0.04 + 0.16 * hash1(cell * 43.7 + vec2(s * 3.1));

            float dropT = clamp((t - dropDelay) / max(0.01, 1.0 - dropDelay), 0.0, 1.0);
            float dropR = dropT * 1.45 * dropSize;

            float dropDist = length(uv - dropPos) - dropR;
            d = smin(d, dropDist, k);
        }
    }

    // Outside the liquid body
    if (d > 0.015) {
        fragColor = vec4(0.0);
        return;
    }

    // Serpantinum palette: Mauve (#cba6f7) -> Sapphire (#74c7ec) -> Blue (#89b4fa)
    // BEGIN_SERPANTINUM_THEME_COLORS
    vec3 colMauve    = vec3(0.816, 0.816, 0.816); // #d0d0d0
    vec3 colSapphire = vec3(0.878, 0.878, 0.878); // #e0e0e0
    vec3 colBlue     = vec3(1.000, 1.000, 1.000); // #ffffff
    // END_SERPANTINUM_THEME_COLORS
    float gradPos    = clamp(v_texcoord.x * 0.7 + v_texcoord.y * 0.3, 0.0, 1.0);
    vec3 serpantinumAccent = mix(colMauve, mix(colSapphire, colBlue, gradPos), gradPos);

    // Smooth effect decay toward the end (zero twitch at finish)
    float effectFade = 1.0 - smoothstep(0.68, 0.88, p);

    // Silky smooth meniscus rim
    float rim = (1.0 - smoothstep(-0.01, 0.015, d)) * smoothstep(-0.08, -0.01, d);

    // Liquid surface normal
    vec2 grad = normalize(centeredUv + vec2(0.0001));
    vec2 refractOffset = grad * (rim * 0.016 * effectFade);

    // Chromatic dispersion through curved liquid boundary
    vec2 sampleUv = v_texcoord - refractOffset;
    float colR = texture(tex, clamp(sampleUv - refractOffset * 0.6, 0.0, 1.0)).r;
    float colG = texture(tex, clamp(sampleUv, 0.0, 1.0)).g;
    float colB = texture(tex, clamp(sampleUv + refractOffset * 0.6, 0.0, 1.0)).b;
    float colA = texture(tex, clamp(sampleUv, 0.0, 1.0)).a;
    vec4 color = vec4(colR, colG, colB, colA);

    // Glowing caustic highlight on the liquid rim in Serpantinum colors
    color.rgb += serpantinumAccent * rim * 0.50 * effectFade;

    // Integrated border: as the liquid touches the edge, it forms the window border!
    vec2 edgePx = min(v_texcoord, 1.0 - v_texcoord) * surface_size;
    float borderDist = min(edgePx.x, edgePx.y);
    float borderGlow = (1.0 - smoothstep(0.5, 3.0, borderDist))
                     * (1.0 - smoothstep(-0.06, 0.0, d))
                     * (1.0 - smoothstep(0.85, 0.98, p));
    color.rgb = mix(color.rgb, serpantinumAccent * 1.3, borderGlow * 0.65);

    // Perfect antialiased alpha
    float alpha = (1.0 - smoothstep(-0.01, 0.015, d)) * smoothstep(0.0, 0.08, p);
    alpha = mix(alpha, 1.0, smoothstep(0.80, 0.95, p));

    fragColor = color * alpha;
}
