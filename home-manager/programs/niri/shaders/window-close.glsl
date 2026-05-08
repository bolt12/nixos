// Window-close shader: "vanish".
//
// The window squashes vertically toward its bottom edge while fading out.
// A faint vertical chromatic-tinted streak trails behind it (Catppuccin
// mauve at top, Catppuccin sky at bottom) so the close has a colour wash
// even as the texture disappears.
//
// Niri shader API: see
//   /share/doc/niri/wiki/examples/close_custom_shader.frag

vec4 close_color(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;

    // Squash vertically toward the bottom (y = 1) while fading.
    float squash = max(0.05, 1.0 - p);
    float yShifted = (coords_geo.y - 1.0) / squash + 1.0;
    vec3 sample_geo = vec3(coords_geo.x, yShifted, 1.0);

    // Sample the window texture at the warped position.
    vec3 tex = niri_geo_to_tex * sample_geo;
    vec4 color = texture2D(niri_tex, tex.st);

    // Outside the window geometry: fade to transparent quickly.
    bool inside = sample_geo.x >= 0.0 && sample_geo.x <= 1.0
               && sample_geo.y >= 0.0 && sample_geo.y <= 1.0;
    if (!inside) {
        color = vec4(0.0);
    }

    // Tint trail: stylix-derived accent gradient, keyed off y.
    // Colours are substituted at HM-eval time from base16 (see niri/default.nix).
    vec3 tintFrom = vec3(@TINT_FROM@);
    vec3 tintTo   = vec3(@TINT_TO@);
    vec3 tint     = mix(tintFrom, tintTo, clamp(coords_geo.y, 0.0, 1.0));

    // Mix tint into the texture as it fades — at p=0 pure texture, at p=1
    // pure transparent (with a brief tinted flash around p=0.5).
    float flash = smoothstep(0.0, 0.5, p) * (1.0 - smoothstep(0.5, 1.0, p));
    color.rgb = mix(color.rgb, tint, 0.35 * flash);

    // Overall alpha falloff.
    color *= (1.0 - p);

    return color;
}
