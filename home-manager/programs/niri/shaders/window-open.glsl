// Window-open shader: "materialize".
//
// Mirror of window-close.glsl. The window expands vertically from its
// bottom edge while fading in. A brief tinted flash washes through it
// at the midpoint of the animation so opens and closes share a visual
// vocabulary.
//
// Niri shader API: see
//   /share/doc/niri/wiki/examples/open_custom_shader.frag

vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;

    // Inverse-squash from the bottom: at p=0 the window is fully squashed
    // (invisible), at p=1 it's full-size.
    float squash = max(0.05, p);
    float yShifted = (coords_geo.y - 1.0) / squash + 1.0;
    vec3 sample_geo = vec3(coords_geo.x, yShifted, 1.0);

    vec3 tex = niri_geo_to_tex * sample_geo;
    vec4 color = texture2D(niri_tex, tex.st);

    bool inside = sample_geo.x >= 0.0 && sample_geo.x <= 1.0
               && sample_geo.y >= 0.0 && sample_geo.y <= 1.0;
    if (!inside) {
        color = vec4(0.0);
    }

    // Same accent gradient as window-close — Stylix base16 substitution at
    // HM-eval time. Wash a brief tint through the middle of the open.
    vec3 tintFrom = vec3(@TINT_FROM@);
    vec3 tintTo   = vec3(@TINT_TO@);
    vec3 tint     = mix(tintFrom, tintTo, clamp(coords_geo.y, 0.0, 1.0));

    float flash = smoothstep(0.0, 0.5, p) * (1.0 - smoothstep(0.5, 1.0, p));
    color.rgb = mix(color.rgb, tint, 0.35 * flash);

    // Overall alpha ramp — fade in.
    color *= p;

    return color;
}
