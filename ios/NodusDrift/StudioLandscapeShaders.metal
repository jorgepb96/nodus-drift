// SPDX-License-Identifier: MIT
#include <metal_stdlib>
using namespace metal;

struct LandscapeUniforms {
    float4 viewport;
    float4 weather;
    float4 lighting;
    float4 scene;
    float4 composition;
    float4 aperture;
    float4 hearth;
};
struct LandscapeActor { float4 rect; float4 source; float4 behavior; };
struct LandscapeVertex { float4 position [[position]]; float2 uv; };
vertex LandscapeVertex driftLandscapeVertex(uint index [[vertex_id]]) {
    float2 p = float2((index << 1) & 2, index & 2);
    LandscapeVertex out;
    out.position = float4(p.x * 2.0 - 1.0, 1.0 - p.y * 2.0, 0, 1);
    out.uv = p;
    return out;
}

float hash21(float2 p) {
    float3 q = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float2 hash22(float2 p) { return float2(hash21(p), hash21(p + 71.31)); }
float noise2(float2 p) {
    float2 cell = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(cell), hash21(cell + float2(1, 0)), u.x),
               mix(hash21(cell + float2(0, 1)), hash21(cell + 1.0), u.x), u.y);
}
float mistNoise(float2 p) {
    float value = 0, amplitude = 0.55;
    for (int i = 0; i < 3; ++i) {
        value += noise2(p) * amplitude;
        p = float2(p.x * 1.71 - p.y * 1.27, p.x * 1.27 + p.y * 1.71) + 13.5;
        amplitude *= 0.48;
    }
    return value;
}
float luminance(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
float3 filmic(float3 c) { return clamp((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0.0, 1.0); }
float windowMask(float2 uv) {
    float top = 0.22 - (uv.x - 0.43) * 0.07;
    return smoothstep(0.423, 0.445, uv.x) * smoothstep(top + 0.008, top + 0.022, uv.y) *
           (1.0 - smoothstep(0.622, 0.637, uv.y));
}
float exteriorMask(float2 uv, int kind) {
    if (kind == 3) return windowMask(uv);
    if (kind == 7) return smoothstep(0.02, 0.06, uv.x) * (1.0 - smoothstep(0.96, 0.99, uv.x)) * smoothstep(0.17, 0.21, uv.y) * (1.0 - smoothstep(0.59, 0.62, uv.y));
    if (kind == 8) {
        float left = max(0.08, 0.62 - uv.y * 0.78), right = min(0.95, 0.65 + uv.y * 0.55);
        return smoothstep(left, left + 0.025, uv.x) * (1.0 - smoothstep(right - 0.025, right, uv.x)) * (1.0 - smoothstep(0.74, 0.79, uv.y));
    }
    if (kind == 9) return smoothstep(0.32, 0.36, uv.x) * (1.0 - smoothstep(0.61, 0.64, uv.y));
    if (kind == 11) {
        float t = clamp((uv.x - 0.23) / 0.77, 0.0, 1.0);
        return smoothstep(0.235, 0.265, uv.x) * smoothstep(0.21 - t * 0.18, 0.23 - t * 0.18, uv.y) * (1.0 - smoothstep(0.56 + t * 0.085, 0.58 + t * 0.085, uv.y));
    }
    if (kind == 13) return smoothstep(0.55, 0.58, uv.x) * smoothstep(0.06, 0.085, uv.y) * (1.0 - smoothstep(0.46, 0.48, uv.y));
    if (kind == 14) return (1.0 - smoothstep(0.04, 0.065, abs(uv.x - 0.5))) * smoothstep(0.24, 0.28, uv.y) * (1.0 - smoothstep(0.48, 0.5, uv.y));
    if (kind == 15) return smoothstep(0.05, 0.065, uv.y) * (1.0 - smoothstep(0.64, 0.67, uv.y));
    if (kind == 16) return smoothstep(0.59, 0.62, uv.x) * smoothstep(0.07, 0.10, uv.y) * (1.0 - smoothstep(0.43, 0.46, uv.y));
    if (kind == 17) return smoothstep(0.72, 0.76, uv.x) * (1.0 - smoothstep(0.35, 0.39, uv.y));
    if (kind == 20) return smoothstep(0.51, 0.55, uv.x) * (1.0 - smoothstep(0.35, 0.37, uv.y));
    if (kind == 21) return smoothstep(0.60, 0.64, uv.x) * smoothstep(0.14, 0.18, uv.y) * (1.0 - smoothstep(0.49, 0.51, uv.y));
    return 1;
}
float rectMask(float2 uv, float4 bounds) {
    return smoothstep(bounds.x, bounds.x + 0.008, uv.x) *
           (1.0 - smoothstep(bounds.z - 0.008, bounds.z, uv.x)) *
           smoothstep(bounds.y, bounds.y + 0.008, uv.y) *
           (1.0 - smoothstep(bounds.w - 0.008, bounds.w, uv.y));
}
float wideExteriorMask(float2 uv, int kind, float4 aperture) {
    if (kind == 8) {
        float halfWidth = max(0.0, uv.y * 0.49 - 0.012);
        return smoothstep(0.5 - halfWidth, 0.51 - halfWidth, uv.x) *
               (1.0 - smoothstep(0.49 + halfWidth, 0.5 + halfWidth, uv.x)) *
               (1.0 - smoothstep(0.88, 0.90, uv.y));
    }
    if (kind == 7) {
        float edge = 0.01 + max(0.0, uv.y - 0.17) * 0.21;
        float pillar = smoothstep(edge + 0.008, edge + 0.022, uv.x) *
                       (1.0 - smoothstep(0.978 - edge, 0.992 - edge, uv.x));
        return rectMask(uv, aperture) * pillar * (1.0 - rectMask(uv, float4(0.457, 0.173, 0.682, 0.288)));
    }
    if (kind == 3 || kind == 9 || kind == 11 || kind == 13 || kind == 14 || kind == 15 ||
        kind == 16 || kind == 17 || kind == 20 || kind == 21) return rectMask(uv, aperture);
    return 1.0;
}
bool effectEnabled(uint flags, uint mask) { return (flags & mask) != 0; }

float footprints(float2 uv, float time, float seed) {
    float result = 0;
    for (int i = 0; i < 12; ++i) {
        float depth = float(i) / 11.0;
        float y = 0.63 + depth * 0.34;
        float x = 0.49 + sin(depth * 2.8) * 0.04 + (i % 2 == 0 ? -1.0 : 1.0) * mix(0.011, 0.033, depth);
        float2 size = float2(mix(0.0035, 0.011, depth), mix(0.008, 0.023, depth));
        float2 p = (uv - float2(x, y)) / size;
        p.x += p.y * (i % 2 == 0 ? 0.16 : -0.16);
        float sole = exp(-dot(p, p) * 1.8);
        float tread = 0.76 + 0.24 * cos(p.y * 22.0);
        float age = fmod(time * 0.65 + float(11 - i) * 0.7 + seed, 16.0);
        float visible = smoothstep(0.0, 0.25, age) * (1.0 - smoothstep(13.0, 16.0, age));
        result = max(result, sole * tread * visible);
    }
    return result;
}

float3 compositeActors(float3 color, float2 uv, float time, texture2d<float> animals, texture2d<float> props,
                       constant LandscapeActor *actors, int count) {
    constexpr sampler sample(filter::linear, address::clamp_to_edge);
    for (int i = 0; i < min(count, 12); ++i) {
        LandscapeActor actor = actors[i];
        float2 origin = actor.rect.xy, size = actor.rect.zw;
        if (size.x <= 0 || size.y <= 0) continue;
        if (actor.behavior.z == 1) origin += float2(sin(time * 0.19 + actor.behavior.w) * 0.012, cos(time * 0.27) * 0.002);
        if (actor.behavior.z == 2) size.y *= 1.0 + sin(time * 1.2 + actor.behavior.w) * 0.005;
        float2 p = (uv - origin) / size;
        // A soft contact shadow anchors grounded subjects to the photographed surface.
        if (actor.behavior.z == 2) {
            float2 shadow = (uv - float2(origin.x + size.x * 0.5, origin.y + size.y * 0.98)) / (size * float2(0.47, 0.055));
            color *= 1.0 - exp(-dot(shadow, shadow) * 2.0) * 0.2;
        }
        if (any(p < 0.0) || any(p > 1.0)) continue;
        if (actor.behavior.z == 3) {
            float2 q = p - 0.5;
            float angle = time * 1.4;
            p = float2(q.x * cos(angle) - q.y * sin(angle), q.x * sin(angle) + q.y * cos(angle)) + 0.5;
            if (any(p < 0.0) || any(p > 1.0)) continue;
        }
        float2 sourceUV = actor.source.xy + p * actor.source.zw;
        float4 sprite = actor.behavior.x < 0.5 ? animals.sample(sample, sourceUV) : props.sample(sample, sourceUV);
        // Suppress near-transparent color fringe while retaining feather/fur edges.
        float alpha = smoothstep(0.08, 0.97, sprite.a) * actor.behavior.y;
        color = mix(color, sprite.rgb, alpha);
    }
    return color;
}

float waterMask(float2 uv, int kind, float3 original) {
    if (kind == 1) {
        // Ocean beyond the shoreline; rocks retain their original texture and shape.
        float extent = smoothstep(0.44, 0.51, uv.y);
        float coast = smoothstep(0.23 + (uv.y - 0.5) * 0.25, 0.36 + (uv.y - 0.5) * 0.25, uv.x);
        float chroma = smoothstep(-0.035, 0.035, max(original.b, original.g) - original.r);
        return extent * coast * chroma;
    }
    if (kind == 4) {
        float depth = clamp((uv.y - 0.39) / 0.61, 0.0, 1.0);
        float centre = 0.52 + sin(depth * 4.4) * 0.055;
        float width = mix(0.026, 0.31, pow(depth, 1.35));
        float river = (1.0 - smoothstep(width * 0.72, width, abs(uv.x - centre))) * smoothstep(0.39, 0.46, uv.y);
        float rockRejection = smoothstep(-0.05, 0.045, max(original.b, original.g) - original.r);
        return river * rockRejection;
    }
    if (kind == 6) { return smoothstep(0.59, 0.615, uv.y) * (1.0 - smoothstep(0.89, 1.0, uv.y)) * smoothstep(0.0, 0.025, original.b - original.g); }
    return 0;
}

float rainField(float2 screen, float aspect, float time, float wind, float seed, float depth) {
    float scale = mix(100.0, 32.0, depth);
    float2 p = float2(screen.x * aspect, screen.y);
    p.x += p.y * (0.045 + wind * 0.18);
    p *= float2(scale, scale * 0.23);
    float column = floor(p.x);
    float speed = mix(2.1, 4.6, depth) * (0.85 + hash21(float2(column, seed)) * 0.4);
    p.y -= time * speed;
    float2 cell = floor(p);
    float2 random = hash22(cell + float2(seed, depth * 71));
    float2 f = fract(p);
    float dx = abs(f.x - mix(0.14, 0.86, random.x));
    float dy = (f.y - 0.5) / mix(0.18, 0.36, depth);
    float thin = max(mix(0.024, 0.042, depth), fwidth(p.x) * 0.65);
    float line = exp(-dx * dx / (thin * thin)) * exp(-dy * dy * 2.6);
    // Different exposures and sparse cells prevent a regular repeated curtain.
    return line * step(0.35, random.y) * mix(0.4, 1.0, random.y);
}
float snowField(float2 screen, float aspect, float time, float wind, float seed, float depth) {
    float2 p = float2(screen.x * aspect, screen.y) * mix(42.0, 13.0, depth);
    p.y -= time * mix(0.18, 0.58, depth);
    p.x -= time * wind * 0.19;
    float2 cell = floor(p), random = hash22(cell + seed);
    float2 centre = 0.15 + random * 0.7;
    centre.x += sin(time * (0.35 + random.y * 0.3) + random.x * 26.0) * 0.1;
    float2 delta = fract(p) - centre;
    float radius = mix(0.028, 0.055, depth) * (0.6 + random.x);
    float flake = exp(-dot(delta, delta) / (radius * radius));
    return flake * step(0.48, random.y) * mix(0.25, 0.8, depth);
}

float starField(float2 uv, float aspect, float time, float seed) {
    float2 p = uv * float2(100.0 * aspect, 100.0);
    float2 cell = floor(p), random = hash22(cell + seed);
    float2 delta = fract(p) - (0.15 + random * 0.7);
    float radius = mix(0.018, 0.05, pow(random.y, 6.0));
    float star = exp(-dot(delta, delta) / (radius * radius));
    return star * step(0.89, hash21(cell + 19.0)) * (0.7 + 0.15 * sin(time * 0.7 + random.x * 30.0));
}

float3 fireRadiance(float2 imageUV, float time, float power, int kind, float4 hearth, thread float &heat) {
    heat = 0;
    if (kind != 3 || power <= 0.001) return float3(0);
    float2 centre = hearth.xy;
    float2 extent = max(hearth.zw, float2(0.001));
    float2 p = (imageUV - centre) / extent;
    float height = clamp(-p.y, 0.0, 1.3);
    float flameNoise = mistNoise(float2(p.x * 4.0, p.y * 3.0 + time * 1.8));
    float sway = sin(time * 1.6 + height * 4.0) * 0.07 + (flameNoise - 0.5) * 0.18;
    float width = max(0.02, 0.9 - height * 0.72);
    float envelope = (1.0 - smoothstep(width * 0.35, width, abs(p.x + sway))) *
                     smoothstep(-0.06, 0.06, -p.y) * (1.0 - smoothstep(0.62, 1.22, height));
    float filament = pow(max(0.0, flameNoise * 1.3 - height * 0.35), 1.9);
    float fire = envelope * filament * power;
    heat = envelope * power;
    float3 orange = float3(1.0, 0.20, 0.018);
    float3 core = float3(1.0, 0.72, 0.19);
    return mix(orange, core, smoothstep(0.12, 0.55, fire)) * fire * 4.5;
}

fragment float4 driftLandscapeFragment(LandscapeVertex in [[stage_in]],
                                       texture2d<float> photograph [[texture(0)]],
                                       texture2d<float> animals [[texture(1)]],
                                       texture2d<float> props [[texture(2)]],
                                       constant LandscapeUniforms &u [[buffer(0)]],
                                       constant LandscapeActor *actors [[buffer(1)]]) {
    constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
    float2 screen = in.uv;
    float aspect = u.viewport.x / max(1.0, u.viewport.y);
    float sourceAspect = u.viewport.z;
    float2 crop = aspect > sourceAspect ? float2(1.0, sourceAspect / aspect) : float2(aspect / sourceAspect, 1.0);
    float focalY = clamp(u.composition.x, crop.y * 0.5, 1.0 - crop.y * 0.5);
    float2 uv = (screen - 0.5) * crop + float2(0.5, focalY);
    float time = u.viewport.w;
    float rain = u.weather.x, wind = u.weather.y, fog = u.weather.z, fire = u.weather.w;
    float day = u.lighting.x;
    int kind = int(u.scene.x + 0.5);
    if (kind != 3) fire = 0;
    uint flags = uint(u.scene.z);
    bool wide = u.composition.y > 0.5;
    float exterior = wide ? wideExteriorMask(uv, kind, u.aperture) : exteriorMask(uv, kind);
    float seed = u.scene.y * 0.001;
    float3 original = photograph.sample(linearSampler, uv).rgb;
    float2 displaced = uv;

    // Fine foliage motion is gated by actual green material; trunks and buildings
    // stay anchored. There is deliberately no full-frame Ken Burns translation.
    if ((kind == 0 || kind == 4 || kind == 5 || kind == 3 || kind == 7 || kind == 8 || kind == 9 || kind == 11 || kind == 13) && wind > 0.001) {
        float foliage = smoothstep(-0.008, 0.055, original.g - max(original.r, original.b) * 0.88);
        foliage *= exterior;
        float depth = mix(0.2, 1.0, smoothstep(0.22, 1.0, uv.y));
        float gust = sin(time * 0.42 + uv.y * 6.3) * 0.65 + sin(time * 0.91 + uv.x * 31.0 + uv.y * 8.0) * 0.35;
        displaced.x += gust * wind * foliage * depth * 0.003;
        displaced.y += sin(time * 0.73 + uv.x * 23.0) * wind * foliage * depth * 0.0007;
    }
    float water = waterMask(uv, kind, original);
    float waterDepth = smoothstep(0.46, 1.0, uv.y);
    if (water > 0.001) {
        float flow = time * (kind == 4 ? 0.55 : 0.18);
        float rippleA = sin(uv.y * 195.0 + uv.x * 21.0 - flow * 3.0);
        float rippleB = sin(uv.y * 311.0 - uv.x * 38.0 + flow * 2.1);
        float detail = sin(uv.x * 187.0 + uv.y * 61.0 + flow);
        displaced.y += (rippleA + rippleB * 0.45) * 0.0015 * water * waterDepth;
        displaced.x += detail * (0.0007 + wind * 0.0005) * water * waterDepth;
    }
    float heat = 0;
    float3 flames = fireRadiance(uv, time, fire, kind, u.hearth, heat);
    if (heat > 0.001) {
        displaced.x += sin(uv.y * 150.0 + time * 7.0) * heat * 0.0009;
    }
    float3 color = photograph.sample(linearSampler, displaced).rgb;
    color = compositeActors(color, uv, time, animals, props, actors, int(u.scene.w));
    if (effectEnabled(flags, 1u)) color *= 1.0 - footprints(uv, time, seed) * 0.44;
    if (effectEnabled(flags, 16u) && exterior > 0.01) {
        float2 p = uv * float2(47.0, 65.0);
        p.y -= time * 0.65;
        float2 cell = floor(p), f = fract(p), r = hash22(cell + seed);
        float2 q = (f - (0.2 + r * 0.6)) / float2(0.08, 0.19);
        float drop = exp(-dot(q, q) * 1.5) * step(0.63, r.x) * exterior;
        color = mix(color, photograph.sample(linearSampler, displaced + float2(0.0015, -0.0025)).rgb * 0.8 + 0.07, drop * 0.5);
    }
    if (effectEnabled(flags, 8u) && kind == 7) {
        float phase = sin(time * 1.8) * 0.5 + 0.5;
        for (int blade = 0; blade < 2; ++blade) {
            float2 base = float2(blade == 0 ? (wide ? 0.36 : 0.32) : (wide ? 0.74 : 0.76), wide ? 0.65 : 0.62);
            float angle = mix(-2.7, -0.55, phase);
            float2 tip = base + float2(cos(angle) * (wide ? 0.30 : 0.39), sin(angle) * (wide ? 0.35 : 0.29));
            float2 v = tip - base;
            float t = clamp(dot(uv - base, v) / dot(v, v), 0.0, 1.0);
            float line = 1.0 - smoothstep(0.002, 0.004, length((uv - base - v * t) * float2(sourceAspect, 1)));
            color = mix(color, float3(0.012), line * exterior * 0.95);
        }
    }

    // Photographic exposure and white balance, in linear light.
    float exposure = exp2(mix(kind == 6 ? -0.6 : -1.05, 0.32, day));
    float3 balance = mix(float3(0.76, 0.89, 1.08), float3(1.04, 1.0, 0.94), day);
    balance *= mix(float3(0.99, 1.015, 1.02), float3(1.035, 1.0, 0.98), u.lighting.z);
    color *= exposure * balance;
    color += flames;
    if (fire > 0.001) {
        float2 origin = u.hearth.xy + float2(0.0, -0.035);
        float glow = exp(-length((uv - origin) * float2(2.0, 1.3)) * 6.0);
        float flicker = 0.83 + sin(time * 3.7) * 0.06 + sin(time * 6.1 + 2.0) * 0.04 + noise2(float2(time * 1.6, 0)) * 0.08;
        color += original * float3(0.72, 0.18, 0.015) * glow * fire * flicker;
        float2 emberUV = screen * float2(40.0 * aspect, 22.0);
        emberUV.y += time * 0.4;
        float2 cell = floor(emberUV), e = hash22(cell + seed);
        float2 delta = fract(emberUV) - e;
        float ember = exp(-dot(delta, delta) / 0.0012) * step(0.97, e.x);
        float region = exp(-pow((uv.x - origin.x) * 5.0, 2.0)) * smoothstep(0.2, 0.85, uv.y);
        color += float3(1.0, 0.25, 0.015) * ember * fire * region * 0.65;
    }
    if (water > 0.001) {
        float ripple = sin(uv.y * 261.0 + sin(uv.x * 43.0) - time * 0.9);
        float sparkle = pow(max(0.0, ripple), 24.0) * waterDepth * water;
        color += float3(0.03, 0.047, 0.055) * sparkle * (0.2 + day * 0.4);
    }

    float skyLine = kind == 0 ? 0.26 : (kind == 3 ? 0.1 : (kind == 2 ? 0.31 : 0.47));
    float sky = (1.0 - smoothstep(skyLine - 0.05, skyLine + 0.03, uv.y)) *
                smoothstep(-0.01, 0.04, original.b - original.g) * smoothstep(0.01, 0.10, luminance(original));
    if (u.lighting.y > 0 && day < 0.55 && kind != 3) {
        float stars = starField(uv, sourceAspect, time, seed);
        color += float3(0.52, 0.62, 0.78) * stars * sky * (1.0 - smoothstep(0.10, 0.55, day)) * u.lighting.y;
    }
    if (fog > 0.001) {
        float depth = exp(-pow((uv.y - 0.49) * 3.8, 2.0));
        float density = mistNoise(uv * float2(4.1, 5.7) + float2(time * (0.012 + wind * 0.018), -time * 0.004) + seed);
        float opacity = fog * (0.035 + depth * 0.24) * smoothstep(0.18, 0.8, density);
        opacity *= exterior;
        color = mix(color, mix(float3(0.085, 0.12, 0.15), float3(0.4, 0.45, 0.44), day), opacity);
    }
    if (kind == 5) {
        float snow = snowField(screen, aspect, time, wind, seed, 0.1) + snowField(screen, aspect, time, wind, seed + 11.0, 0.6) + snowField(screen, aspect, time, wind, seed + 29.0, 1.0);
        color = mix(color, float3(0.67, 0.76, 0.85), clamp(snow * max(0.35, rain), 0.0, 0.65));
    } else if (rain > 0.001) {
        float drops = rainField(screen, aspect, time, wind, seed, 0.0) * 0.38 + rainField(screen, aspect, time, wind, seed + 17.0, 0.55) * 0.65 + rainField(screen, aspect, time, wind, seed + 43.0, 1.0) * 0.5;
        float area = exterior;
        color = mix(color, float3(0.47, 0.56, 0.65), clamp(drops * rain * 0.62 * area, 0.0, 0.4));
        // Rain spray hangs close to the distant ground, rather than painting lines on it.
        color += float3(0.04, 0.052, 0.06) * rain * fog * area * exp(-pow((uv.y - 0.65) * 8.0, 2.0));
    }
    if (effectEnabled(flags, 32u) || kind == 12) {
        float2 p = uv * float2(23, 28); p.y += time * 0.9;
        float2 cell = floor(p), r = hash22(cell + seed), q = fract(p) - (0.15 + r * 0.7);
        float radius = mix(0.035, 0.11, r.x);
        float ring = exp(-pow((length(q) - radius) / 0.012, 2.0)) * step(0.84, r.y);
        color += float3(0.08, 0.12, 0.13) * ring;
    }
    if (effectEnabled(flags, 64u) || effectEnabled(flags, 8192u)) {
        float plume = mistNoise(uv * float2(18, 12) + float2(sin(time * 0.2) * 0.2, time * 0.18));
        float area = exp(-pow((uv.x - 0.62) * 7, 2.0)) * smoothstep(0.45, 0.65, uv.y) * (1.0 - smoothstep(0.86, 0.97, uv.y));
        color += float3(0.12) * smoothstep(0.48, 0.78, plume) * area * 0.3;
    }
    if (effectEnabled(flags, 2u)) {
        float leaf = snowField(screen, aspect, time * 0.65, wind + 0.2, seed, 0.7);
        color = mix(color, float3(0.22, 0.09, 0.025), clamp(leaf * 0.75, 0.0, 0.6));
    }
    if (effectEnabled(flags, 4u)) color *= 1.0 - footprints(uv, time, seed) * 0.2;
    if (effectEnabled(flags, 256u) || effectEnabled(flags, 512u)) {
        float travel = fract(time * 0.035 + seed);
        float2 light = float2(0.46 + travel * 0.38, 0.55 + travel * 0.19);
        float glow = exp(-length((uv - light) * float2(1.0, 2.0)) * 150.0);
        color += float3(0.23, 0.16, 0.08) * glow;
    }
    if (effectEnabled(flags, 128u)) {
        float cycle = floor(time / 7.0), life = fract(time / 7.0);
        float2 origin = float2(0.35 + hash21(float2(cycle, seed)) * 0.3, 0.3);
        float2 q = (uv - origin) * float2(sourceAspect, 1);
        float theta = atan2(q.y, q.x), radius = length(q);
        float sparks = pow(max(0.0, cos(theta * 19.0 + seed)), 22.0) * exp(-pow((radius - life * 0.15) / 0.004, 2.0));
        color += float3(0.55, 0.28, 0.1) * sparks * (1.0 - life) * smoothstep(0.03, 0.15, life) * exterior;
    }
    if (effectEnabled(flags, 2048u)) {
        float signal = 0.5 + sin(time * 0.6 + uv.y * 27) * 0.5;
        color += float3(0.007, 0.012, 0.018) * signal * (1.0 - smoothstep(0.12, 0.5, abs(uv.y - 0.65)));
    }
    color += float3(0.62, 0.70, 0.83) * u.lighting.w * (0.2 + original * 1.4);
    float vignette = 1.0 - dot((screen - 0.5) * float2(0.8, 0.55), (screen - 0.5) * float2(0.8, 0.55)) * 0.35;
    color = filmic(max(0.0, color) * vignette);
    return float4(color, 1.0);
}
