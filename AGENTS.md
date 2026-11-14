# AGENTS.md — CRT-Trinity

> **Purpose of this file:** Give future AI assistants and developers enough context to understand the shader's intent, architecture, mathematics, assumptions, limitations, safe modification points, and possible future directions. Read this before proposing or making substantial changes.
>
> **Authoritative source:** `CRT-Trinity.fx` (shader UI version `v1`). This document describes the complete implementation as one integrated system, not as a release history or a sequence of feature batches. The `.fx` source is authoritative whenever wording here and code disagree. Keep the shader as one file unless the user explicitly asks for a different architecture.

---

## 1. Project identity and current design

### 1.1 What this project is

`CRT-Trinity` is a **highly customizable Sony Trinitron-inspired CRT post-processing ReShade FX shader for DuckStation**, distributed as a single `.fx` file. It builds on Mattias Gustavsson's **NewPixie CRT**. The original NewPixie shader was adapted to Slang by **hunterk**. **Albatross** later published the `CRT-NewPixie_Albatross` ReShade modification and described converting the vanilla code from Slang to HLSL while adding configurable variants. DuckStation also distributes its own `CRT-NewPixie.fx`; the available source header and history reviewed for this project do not unambiguously identify the author of that file's original ReShade FX conversion. These attributions describe upstream lineage, not authorship of CRT-Trinity's own implementation.

The **Sony Trinitron aperture-grille CRT family** is the shader's foundational hardware and visual reference, with a Japanese P22-inspired character as the default. This influence applies to the complete rendering approach—not merely the name of its default colour profile. Source reconstruction, phosphor structure, beam and scanline behaviour, temporal effects, grain/noise, ghosting, halation, bloom, geometry and the other image-finishing stages are all selected and tuned as parts of one cohesive, mild Trinitron-oriented presentation.

**Project authorship and direction:** `CRT-Trinity` is created and directed by **bone-machine**. The project's visual goals, design choices, feature priorities, preferred defaults, testing feedback and final acceptance decisions belong to the project author. AI assistance has been used as a development tool for research, shader implementation, mathematical analysis, technical review and documentation. The `project_author` source field identifies the project author; it is not the sole acknowledgement of authorship.

The main visual references used by the author are:

- **Castlevania: Symphony of the Night (PS1)** — the primary reference for the default appearance and visual tuning.
- **Metal Gear Solid 1 (PS1)** — another game that has been observed to work well with the shader.
- Other games may look good, but no claim is made that every game or console has been calibrated or exhaustively tested.

The **current default preset** is deliberately mild and approachable rather than a complete electrical, optical, or analog-video CRT simulation. That describes the present configuration; it is not a restriction on what future users may ask the shader to become. The current look is primarily produced by combining:

- selectable display colour profiles;
- selectable phosphor-mask patterns;
- scanlines / beam-shaped vertical modulation;
- modest pixel and source-pixel smoothing;
- optional horizontal beam-spot filtering;
- subtle colour fringing;
- vignette;
- ghosting;
- post-phosphor optical halation;
- bloom;
- animated grain/noise;
- small frame-dependent flicker and optional signal wobble.

**Flat geometry is the default.** Curvature exists as an optional display/presentation effect, not as a requirement for the intended appearance and not as a correction to the game's geometry.

### 1.2 Sony Trinitron design reference and project-wide design philosophy

The design reference for the shader's overall rendering approach is the **Sony Trinitron aperture-grille CRT family**, particularly selected characteristics of its construction and operating behaviour, with a Japanese P22-inspired default. This is the foundation of the shader's visual design, not a claim that it reproduces a particular Trinitron television or physically simulates its complete operation. The intended reference is a family-level Trinitron presentation informed especially by the RGB-stripe aperture-grille structure and the preferred Japanese P22-inspired colour character, not one exact model, chassis, tube revision or factory calibration.

The project's research and design decisions consider the available technical and historical information about how Trinitron displays are constructed and behave, including:

- the aperture-grille tube structure, vertical RGB phosphor-stripe arrangement, grille pitch and support/damper wires;
- the electron-gun and cathode/channel-drive context that produces the separate red, green and blue beams;
- beam current, spot width and the way a beam profile can change with channel drive;
- raster-line formation, scanline spacing, beam overlap and the visible relationship between neighbouring lines;
- phosphor excitation, emitted-light distribution, persistence and the optical appearance of bright areas;
- the display's colour primaries, white-point character, contrast and overall image presentation.

These subjects form the **design reference and interpretation framework**. The shader only implements screen-space effects that can be represented in its post-processing pipeline. For example, it uses aperture-grille coverage, damping-wire attenuation, current-responsive spot/beam approximations, scanline phase behaviour, display-colour transforms and simplified temporal/optical effects. It does **not** physically simulate the cathodes, electron trajectories, electron-gun geometry, deflection yoke, high-voltage circuitry, vacuum-tube operation or phosphor chemistry. Those mechanisms inform the design but are not solved as physical/electrical simulations.

This Trinitron reference applies to the **whole rendering treatment**, not only to the mask or colour profile. Source reconstruction and filtering are tuned to prepare the image for the intended Trinitron-like raster; the horizontal spot and vertical beam models describe the chosen beam presentation; scanlines and field-phase behaviour provide the raster/temporal character; grain/noise, flicker, ghosting, halation, bloom, vignette and optional curvature are selected and balanced to support the same overall screen impression. Some of these finishing effects are deliberate aesthetic interpretations rather than literal artifacts that every Trinitron naturally exhibits. They should not be described as measured or inevitable properties of the hardware.

The other entries in **Display Color Profile** are optional user-customization choices. They provide alternative colour-primary/white-point interpretations and, where the profile mapping specifies it, a convenient automatic mask pairing. They do **not** switch the shader into a separate complete Toshiba, BVM or KX-14CP1 hardware simulation, and they do not replace the underlying Trinitron-oriented image-formation and effects model. The Japanese Cool Sony Trinitron profile remains the default and central reference; the additional profiles make the shader more flexible for users whose preferred colour appearance differs.

### 1.3 Authoring context and current default aesthetic

The shader was developed with **AI-assisted research, implementation, mathematical analysis and iterative technical review** under the project direction of `bone-machine`. The saved defaults are the author’s preferred visual settings, selected by eye rather than by instrumented calibration. They are not measurements or factory calibrations of a particular television.

The out-of-box configuration is a **mild, flat Sony Trinitron-inspired treatment**. Its default character is a **cool, blue-ish Japanese P22-inspired look**, with Flat geometry and the profile-selected aperture-grille mask. Other selectable profiles provide colour and mask-pairing alternatives, not independent complete CRT models. For ordinary use, the author recommends starting with the defaults and changing only familiar high-level settings such as the display profile, scanline visibility/strength, smoothing, grain, bloom or halation. Detailed beam, mask, reconstruction and geometry controls are intended for users who understand their interactions; advanced users may change them freely.

This describes the current design target and preset, not a requirement that future work must never change. The shader is editable, and a user may request a different visual target or a more detailed signal/display model. Follow the requested direction while clearly distinguishing a Trinitron-inspired post-process from a physically complete hardware simulation.

### 1.4 What the current implementation does not yet include

Do not describe the current shader as a complete or physically exact CRT emulator. The current source does not implement a complete chain for:

- analog RGB, composite, S-Video, component, RF, NTSC, or PAL encoding/decoding;
- chroma subcarrier, dot crawl, chroma crawl, composite cross-colour, or full analog bandwidth behaviour;
- full electron-gun and deflection-yoke simulation;
- true time-domain phosphor chemistry and independently measured phosphor decay curves;
- real CRT convergence, dynamic focus, astigmatism, purity errors, or measured spot shapes;
- a real 480i field pipeline or genuine deinterlacing;
- bezel, glass reflection, room lighting, or a complete monitor enclosure;
- calibrated, manufacturer-specific reproduction of every selected display profile.

Some subsystems are informed by physical principles or use real mathematical constructions, but the overall shader remains a hybrid post-process with aesthetic approximations.

---

## 2. Guidance for future AI agents

This section records the source's current behaviour and engineering considerations. It is not an aesthetic or product-direction lock. Follow the active user's actual request, even when it calls for a substantial redesign or a visual result very different from the current preset. Do not treat the original author's taste, the current defaults, or preferences expressed in earlier project discussions as binding instructions for a different user. This file explains the starting codebase; it does not define what future users are allowed to build from it.

1. **Inspect the current `.fx` before editing.** Do not rely on an older conversation, stale patch, prior README, or remembered line numbers. The current source is authoritative.
2. **Treat the current appearance as a baseline, not a requirement.** It is useful context when a request is ambiguous, but do not assume the user wants to preserve it.
3. **Follow the user's requested direction.** The shader may be made more subtle, more conspicuous, more physically detailed, more stylized, more analog, or fundamentally different. Do not steer the user back toward the existing mild look merely because that is the current default. Explain material trade-offs and implement the requested direction when feasible.
4. **Understand defaults as current values, not sacred values.** `screen_geometry = 0` currently selects Flat, and `display_profile = 0` currently selects Sony Trinitron — Japanese Cool. Preserve them when a task is unrelated to defaults; change them when requested or when a broader redesign explicitly calls for it.
5. **Understand the current mask pairing:** profile auto-selection chooses Aperture Grille for all Sony profiles and Neutral, and Slot Mask for the Toshiba profiles. Explicit mask selection currently overrides the mask only; it does not change the display colour profile. This mapping may be changed if the user requests a different model or workflow.
6. **Do not present profile matrices as factory calibrations.** The code comments distinguish reference estimates and aesthetic interpretations from measured model-specific data. New profiles should carry equally clear provenance and uncertainty.
7. **Do not claim true 480i support.** The current `interlace` option only shifts scanline phase on alternating rendered frames; no separate fields are received or reconstructed. A genuine field-aware implementation is possible as a future feature, subject to emulator data availability.
8. **Do not confuse tone mapping with output encoding.** `filmic()` is a luminance tone curve, not an sRGB OETF. The final output encoding remains a backend-dependent verification item.
9. **Track colour domains carefully.** The shader decodes the source in the accumulation pass and stores intermediate scene data in RGBA16F. Identify whether each value is encoded, linear-light, tone-mapped, or output-referred before adding transfer functions or other operations.
10. **Respect the current alpha-channel contract when modifying the existing pipeline.** `tCrtScene.a` stores the local scanline multiplier, not conventional opacity. Update every consumer if that contract changes.
11. **Respect the current sequential lifetime of the Gaussian scratch targets.** `GaussianBlurTemp` and `GaussianBlurTex` first hold the pre-CRT source blur for ghosting, then are overwritten after the CRT scene pass with the post-CRT halation blur. Any pass reordering must re-check all reads and writes.
12. **Understand the present halation/bloom relationship.** Halation is composited directly and also contributes to the wider bloom extraction. This currently creates a layered local-plus-wide glow. It can be retained, adjusted, separated, or replaced if the user's goal calls for it.
13. **Match the scope of the request.** Prefer localized fixes for localized bugs, but do not avoid a broad pipeline redesign when the user explicitly asks for one. Trace dependencies and explain consequences either way.
14. **Treat defaults as user-tunable aesthetic choices.** Physical plausibility, historical fidelity, performance, artistic preference, and ease of configuration may point to different settings. Explain the trade-offs rather than treating one criterion as universally dominant.
15. **Use accurate technical language.** Do not call a visual approximation a physical simulation. Terms such as “CRT-inspired”, “approximation”, “reference profile”, “stylized”, and “simulated” should describe the actual implementation.
16. **Verify every UI control.** A slider or checkbox should have an observable code path, and its tooltip should state mode restrictions. Avoid controls that silently do nothing in a selected mode.
17. **Document coupled effects.** When one control affects multiple systems (for example, `blur_x/y` affecting both ghosting and halation), make that relationship clear.
18. **Test beyond a single screenshot.** Static screenshots cannot establish temporal correctness, persistence, flicker, field behaviour, or motion artifacts.
19. **Do not claim successful compilation unless it was actually compiled** with a compatible ReShade FX toolchain or DuckStation. Static review is not compilation.
20. **Keep the README concise.** This file is the technical handoff. The README is the user-facing summary and installation guide.

---

## 3. Current defaults and out-of-box look

The following are the current saved shader defaults. They describe the author’s preferred appearance, not a calibrated monitor target. The complete UI reference, including every user-facing setting, is in §14.

| Setting | Current default | Meaning |
|---|---:|---|
| Display Color Profile | Sony Trinitron — Japanese Cool (`0`) | Cool Japanese P22-inspired default. |
| Phosphor Mask Type | Use Display Profile Default (`0`) | Sony profiles resolve to Aperture Grille. |
| CRT Surface Profile | Flat (`0`) | Bypasses faceplate projection. |
| Geometry Reconstruction | Bilinear (1 tap, `0`) | No adaptive multi-tap geometry filter by default. |
| Brightness | `1.1` | Post-scanline scene multiplier. |
| Contrast Curve | `1.0` | Full blend of the existing luminance curve. |
| Saturation | `0.94` | Slightly restrained saturation relative to the selected profile white. |
| Gamma | `2.2` | Input BT.1886-style EOTF parameter. |
| Black Level | `0.004` | Normalized input black reference. |
| Pixel Smoothing Mode | Subpixel Blend (`1`) | Subpixel Blend / Edge-Aware / Hybrid reconstruction mode. |
| Pixel Smoothing | `0.35` | Strength of the selected source-reconstruction blend. |
| Adjacent-Tap Edge Blending | Off | Optional cached edge-aware filtering for the two horizontal taps beside the centre tap. |
| Horizontal Source-Pixel Smoothing | `0.17` | Added horizontal Gaussian width in native-pixel units. |
| Vertical Source-Pixel Smoothing | `0.10` | Added vertical Gaussian width in native-line units. |
| Enable Scanlines | On | Enables the vertical beam/scanline stage. |
| Scanline Beam Profile | Gaussian Beam (`1`) | Pixel-footprint-integrated spot modulation. |
| Vertical Beam Model | Shared Beam (`0`) | Existing shared luminance-driven beam model. |
| Per-source-line RGB Attenuation | Source-Domain (`0`) | Preserves the original early RGB beam attenuation. Post-Display (Shared Beam-aligned) is an optional alternative; Field-Phase Flicker forces it while active. |
| Beam Spot Profile | Gaussian (`0`) | Shared profile family for horizontal and Gaussian vertical spots. |
| Horizontal Spot Structure | Single Lobe (`0`) | One normalized horizontal spot component. |
| Horizontal Spot Tail Energy / Width | `2%` / `2×` | Used only when Core + Tail is selected. |
| Horizontal Beam Spot Width | `0.15` | Output-pixel sigma at 1080p before internal-grid conversion. |
| Scanline Strength | `1.7` | Blend/strength of the vertical modulation. |
| Vertical Beam Sharpness | `1.0` | Controls the base Gaussian-family beam sigma. |
| Scanline Beam Widening | `0.75` | Maximum brightness-dependent widening scale. |
| Beam Current Response | `0.50` | Exponent mapping channel/luminance drive to beam widening. |
| Beam Average Drive | `0.15` | Mean output drive of normalized beam profiles. |
| Source-Line Frequency | `340` | Manual pitch; ignored when native matching is enabled. |
| Match Scanlines to Source Resolution | Off | Uses manual or retained stock pitch. |
| Alternating Field Phase | On | Adds a half-period phase shift on alternating rendered frames. |
| Rolling Scanlines | On | Animates scanline phase using elapsed time. |
| Vignette Strength | `0.8` | Edge-darkening blend. |
| Vignette Mapping | Symmetric Viewport (`1`) | Uses symmetric active-viewport coordinates; Legacy Fit remains available. |
| Flicker Amount | `0.003` | Small final frame/vertical-position modulation. |
| Color Fringing | `0.15` | Small channel-specific sample offsets. |
| Temporal Trail Persistence | `0.0` | No retained bright-trail contribution by default. |
| Interference Strength | `0.0` | Animated horizontal wobble disabled by default. |
| Interference Speed | `1.0` | 60 Hz reference-time multiplier for wobble. |
| Noise Amount | `0.06` | Subtle animated grain. |
| Luminance Adaptation | `0.15` | Slight reduction of grain in darker values. |
| Headroom-Aware Grain | Off | Optional symmetric per-channel attenuation against black/white output headroom. |
| Grain Chroma | `0.71` | Blend between shared and independent RGB noise. |
| Grain Animation Speed | `1.0` | Full nominal temporal evolution. |
| Grain Size | `1.0` | Fine cell-based grain. |
| Grain Alignment | Output Pixels (`0`) | Anchored to the final output grid. |
| Detail Protection | `0.50` | Reduces grain around source detail using filter metadata. |
| Image-Aware Chroma | `0.25` | Adapts the independent-RGB grain component to image saturation. |
| Horizontal / Vertical Blur | `0.5 / 0.5` | Shared blur-radius controls for ghosting and halation. |
| Ghost Strength | `0.6` | Subtle colour-separated source ghosting. |
| Halation Strength | `0.15` | Post-emission optical glow. |
| Halation Respects Scanlines | Off | Default glow spreads into scanline gaps. |
| Halation Threshold | `0.8` | Bright-pass threshold against completed CRT-scene luminance. |
| Halation Warmth | `0.3` | White-to-amber glow tint blend. |
| Bloom Intensity | `0.15` | Wider highlight contribution. |
| Bloom Threshold | `4.0` | Highlight peak threshold in linear scene values. |
| Bloom Soft Knee | `0.15` | Soft transition around the bloom threshold. |
| Bloom Radius | `8` | Approximate reach in pixels at 1080p. |
| Field-Phase Flicker | Off | Experimental full Scanlines & Beam override, described in §7.8. |

Built-in mask defaults are internal constants selected when `Use Display Profile Default` is active. They are not the same thing as the editable values in the three Custom mask categories. The custom values are documented in §14.10–§14.12.

## 4. Rendering architecture and pass graph

### 4.1 High-level flow

The technique is an ordered 13-pass pipeline. The order is intentional because several targets are reused after their earlier contents have been consumed.

1. `Pass_AccumulateFrame` — sample the incoming backbuffer, decode it with the adjustable BT.1886-style EOTF approximation, apply the retained `1.25` input gain and combine it with prior-frame history.
2. `Pass_SaveHistory` — copy the current accumulated linear-light frame into persistent temporal history.
3. `Pass_GaussianBlurHorizontal` — horizontal source-image blur for ghosting.
4. `Pass_GaussianBlurVertical` — vertical completion of the ghosting blur.
5. `Pass_SmoothH` — internal-grid source sampling, 3×3 edge analysis, adaptive Pixel Smoothing, horizontal source-cell integration and horizontal spot filtering.
6. `Pass_SmoothV` — area-integrated vertical source-pixel Gaussian smoothing.
7. `Pass_RenderCRTScene` — source mapping, channel offsets/fringing, optional per-source-line RGB beam reconstruction, ghosting, phosphor mask, damping wires, display colour matrix, contrast/saturation, vignette and shared/Sine scanline modulation. Store scanline metadata in alpha.
8. `Pass_HalationBlurHorizontal` — extract highlights from the completed phosphor/beam scene and blur horizontally.
9. `Pass_HalationBlurVertical` — complete the halation blur.
10. `Pass_ExtractBloom` — 4×4 downsample of separately thresholded post-phosphor highlights plus the direct halation contribution.
11. `Pass_BloomBlurHorizontal` — quarter-resolution horizontal bloom blur.
12. `Pass_BloomBlurVertical` — quarter-resolution vertical bloom blur.
13. `Pass_CompositeBloom` — optional faceplate projection, direct halation, bloom, tone mapping, selective warm-colour desaturation, animated grain/flicker, faceplate coverage and final SDR clamp.

The final composite pass has no explicit `RenderTarget`; it writes to the technique output. ReShade FX schedules all declared passes in the technique. A uniform such as `bloom_intensity` can bypass the shader work inside a pass, but it cannot remove a pass from the host schedule.

### 4.2 Render-target inventory

All nine named render textures are retained. Full-resolution targets use `RGBA16f`; bloom targets use one-quarter width and height.

| Target | Resolution | Primary contents / lifetime |
|---|---|---|
| `tAccTex` | Full | Prior-frame accumulated linear-light history. |
| `tAccumFrame` | Full | Current accumulated linear-light source frame. |
| `tSmoothH` | Full | Horizontally reconstructed source signal; alpha stores horizontal detail confidence. |
| `tSmoothV` | Full | Vertically reconstructed source signal; alpha stores filtered detail confidence. |
| `GaussianBlurTemp` | Full | First source-ghost horizontal blur; later reused for halation horizontal blur. |
| `GaussianBlurTex` | Full | Completed source-ghost blur; later reused for completed halation blur. |
| `tCrtScene` | Full | Completed linear CRT scene; alpha stores scanline multiplier. |
| `tBloomA` | Quarter | Bloom extraction, then vertical bloom blur output. |
| `tBloomB` | Quarter | Horizontal bloom blur intermediate. |

All samplers use clamp addressing and linear min/mag filtering. Since clamp can repeat edge texels, the source/ghost helpers use explicit edge validity where appropriate.

### 4.3 Sequential reuse of Gaussian scratch targets

The pre-CRT source blur is consumed by `PS_RenderCRTScene` for ghosting. After that pass completes, the same two full-resolution targets are no longer needed for ghosting and can be overwritten by the post-emission halation stage:

```text
Pass_GaussianBlurHorizontal -> GaussianBlurTemp (source RGB blur)
Pass_GaussianBlurVertical   -> GaussianBlurTex  (source RGB blur)
Pass_RenderCRTScene         reads GaussianBlurTex for ghosting
Pass_HalationBlurHorizontal -> GaussianBlurTemp (scalar halation bright-pass blur)
Pass_HalationBlurVertical   -> GaussianBlurTex  (completed scalar halation blur)
Pass_CompositeBloom         reads GaussianBlurTex for halation
```

A pass-order change must re-check this lifetime. A future consumer that needs source ghost blur after the scene pass cannot use these targets without changing the schedule or allocating a separate target.

### 4.4 Alpha-channel contracts

Alpha is metadata in the relevant intermediate targets, not ordinary transparency:

- `tSmoothH.a`: source-cell detail-confidence estimate from the adaptive 3×3 neighbourhood.
- `tSmoothV.a`: vertically filtered detail-confidence estimate passed to final grain protection.
- `tCrtScene.a`: local scanline multiplier `s`, where `s = pow(saturate(scans), 0.9)` or the corresponding luminance-weighted per-source-line RGB beam factor. When scanlines are disabled, this factor is `1.0`.

`sample_crt_surface()` reconstructs both `tCrtScene.rgb` and its scanline metadata. `halation_contribution()` uses the alpha value only when `Halation Respects Scanlines` is enabled. Do not treat these alpha channels as opacity or overwrite them without updating their consumers.

## 5. Input transfer function, linear-light path, persistence, and output

### 5.1 Input EOTF approximation

`decode_crt_eotf()` maps the normalized incoming signal to an approximate linear-light value using a BT.1886-style power-law model with adjustable gamma and black level. It assumes normalized white is 1 and does not detect the input transfer function automatically.

Let:

- `V` be the input channel clamped to [0,1];
- `γ` be `crt_gamma` (UI range 2.2–2.6, default 2.2);
- `Lb` be `black_level` (UI range 0–0.1, default 0.004);
- `lb = Lb^(1/γ)`.

The current implementation is written as:

\[
L(V)=\left[\operatorname{lerp}(L_b^{1/\gamma},1,V)\right]^\gamma
\]

This is algebraically equivalent to the conventional BT.1886-style `a(V+b)^γ` form where `b = lb/(1-lb)` and `a = (1-lb)^γ`. The interpolation form avoids a large intermediate offset as the black parameter approaches its upper supported range. It yields `L(0) ≈ Lb` and `L(1) = 1`.

The source is clamped to nonnegative normalized SDR values before this function. The shader is not an HDR EOTF decoder, and it does not determine whether the backbuffer is actually encoded with a matching power law. Treat this as the shader's selected working assumption.

### 5.2 Accumulation and temporal trail logic

`PS_AccumulateFrame()`:

1. Reads `tAccTex`, the previous-frame history.
2. Clears the history sample if it contains NaN/Inf, negative values, RGB above `1.5`, or alpha above `1.0`.
3. Clears on `history_reset` or `FCount <= 1`. DuckStation increments the frame counter before updating the source uniforms, so frame 1 is used as the new-target initialization point.
4. Multiplies history by `acc_modulate`.
5. Samples the current backbuffer, decodes it with `decode_crt_eotf()` and applies the retained `1.25` gain.
6. Returns the component-wise maximum of history and current input.

\[
C_t=\max(C_{current,t},\;mC_{history,t-1})
\]

where `m = acc_modulate` and the maximum is independently applied to R, G and B. This is not conventional exponential motion blur and not a measured phosphor-decay curve. It preserves older values only while they remain brighter than the current channel value, producing a bright-trail effect. The default `acc_modulate = 0` disables the retained contribution.

`Pass_SaveHistory` writes the newly accumulated `tAccumFrame` to `tAccTex`. This explicit target avoids depending on implicit backbuffer ping-pong. An FX shader cannot reliably identify every possible arbitrary, finite, uninitialized history value after target reallocation; the automatic first-frame clear and manual Reset History control cover the known reset paths.

### 5.3 Linear-light assumptions and scene domains

The intended path after accumulation is linear light. Source reconstruction, ghost blur, phosphor-mask multiplication, display matrices, scanline modulation, halation extraction/blur, bloom extraction/blur and tone mapping all operate on these linear values. The shader stores high-dynamic-range intermediate values in FP16 render targets even though the final output is SDR-clamped.

Grain and the final small flicker are added after the filmic tone curve. Their placement is a stylistic display-output choice; it does not turn the full shader into a complete colour-managed display simulation.

### 5.4 Filmic tone mapping and output encoding

`filmic_luminance()` uses the legacy NewPixie rational luminance roll-off. The toe tracks changes to `black_level` while retaining the original `0.004` toe when the control is left at its default:

\[
T=\max(0.004+1.25(L_b-0.004),0)
\]
\[
x=\max(Y-T,0)
\]
\[
Y'=\frac{x(6.2x+0.5)}{x(6.2x+1.7)+0.06}
\]

The output RGB vector is scaled uniformly by `Y'/Y` (with a near-black guard) and is capped if a channel still exceeds 1. This preserves the input colour ratios through the luminance curve rather than rolling off each RGB channel independently. `filmic()` is a tone-mapping curve, **not** an sRGB OETF.

No unconditional output sRGB/power-law encoding is applied. The final backbuffer interpretation is managed by DuckStation/ReShade and can depend on backend/output format. Adding an unconditional encode without verifying that contract risks double encoding. The shader finally uses `saturate()` and is therefore SDR-oriented, not HDR-safe.

## 6. Source-image reconstruction and pixel smoothing

Source reconstruction takes place before the phosphor mask, display-colour transform and CRT beam treatment. Its purpose is to provide a restrained reconstruction of the available rendered source image, not to blur the final CRT pattern.

### 6.1 Native raster, internal render grid and active viewport

DuckStation supplies separate source values for:

- `nativewidth` / `nativeheight`: the game's native raster dimensions;
- `internalwidth` / `internalheight`: the actual internal render dimensions, which can be larger when enhanced rendering is enabled;
- `viewportoffset` / `viewportsize`: the active image rectangle inside the post-process buffer.

`source_native_pixel_size_px()` calculates the displayed native-pixel size from the active viewport:

\[
P_{native}=\frac{ViewportSize}{(NativeWidth,NativeHeight)}
\]

`source_reconstruction_pixel_size_px()` instead uses the internal render dimensions when present:

\[
P_{internal}=\frac{ViewportSize}{(InternalWidth,InternalHeight)}
\]

At native/internal 1× these grids coincide. At enhanced internal resolution the reconstruction grid is finer, so the shader can retain extra spatial detail rendered for 3D geometry rather than selecting one sample per original game pixel. CRT raster pitch, native source-pixel units and native-aligned grain continue to use the native dimensions.

The reconstruction scale is `max(InternalDimensions / NativeDimensions, 1)` per axis. The source-smoothing controls are converted through this scale so their meaning remains in fractions of a native pixel/line even when the reconstruction lattice is finer. Viewport-relative cell centres retain fractional output-pixel positions; do not round them to integer output texel centres, because multiple internal samples can fall between output texel centres.

Sampling is anchored to `ViewportOffset`, not the whole window. The helper rounds the estimated sample count to a positive integer, maps the output pixel to a clamped source cell, and samples the cell centre. If host internal dimensions are missing or zero, the reconstruction falls back to the native-grid path. If native dimensions are also unavailable, the last-resort fallback assumes a 240-line raster with square displayed source pixels; this may be wrong for non-PS1 or unusual modes.

This behaviour was important in the *Symphony of the Night* Save Room comparison: at 6× internal resolution, the save crystal's extra 3D detail was being discarded by native-grid-only reconstruction. Using DuckStation's internal dimensions retained that additional 3D detail while keeping CRT beam/raster pitch tied to the game's native dimensions. This is still an image-sampling distinction, not semantic object detection; the shader does not know which pixels belong to sprites versus 3D geometry.

### 6.2 Edge-aware Pixel Smoothing and detail analysis

`Pixel Smoothing Mode` defaults to **Subpixel Blend (`1`)**. That mode applies symmetric half-offset sampling in the horizontal and vertical source-reconstruction passes, with the offset controlled by `Pixel Smoothing`. The Edge-Aware mode and the Edge-Aware component of Hybrid are optional alternatives. The following analysis describes that adaptive path; its detail-confidence output can also be used independently by grain protection.

`PS_SmoothH()` selects the current internal-grid source cell and, when `pixel_smoothing` or `noise_detail_protection` is active, samples a clamped 3×3 neighbourhood. This neighbourhood serves two related purposes: the adaptive reconstruction blend and the source-detail confidence later used by grain protection.

Each RGB sample is mapped into square-root comparison space:

\[
C_s=\sqrt{\max(C,0)}
\]

The original accumulated image remains linear; this square-root transform is used only for local comparisons. It increases sensitivity to relative differences in dark regions.

For a difference vector \(d=C_{s,a}-C_{s,b}\), the YCoCg-like comparison distance is:

\[
d_Y=|0.2126d_R+0.7152d_G+0.0722d_B|
\]
\[
d_{Co}=|d_R-d_B|,\qquad d_{Cg}=|d_G-0.5(d_R+d_B)|
\]
\[
D=d_Y+0.25(d_{Co}+d_{Cg})
\]

It combines luminance and chromatic differences, so equal-luminance colour boundaries can still receive a large range distance. This is a practical YCoCg-like metric, not CIE Lab, Delta-E or a standardized perceptual colour space.

The 3×3 neighbourhood is divided into four overlapping 2×2 quadrants. In each quadrant the code forms approximate horizontal and vertical colour gradients `(gx, gy)`. Their outer products are averaged into a 2×2 structure tensor:

\[
J=\begin{bmatrix}J_{xx}&J_{xy}\\J_{xy}&J_{yy}\end{bmatrix}
\]

The eigenvalue discriminant is:

\[
\Delta=\sqrt{(J_{xx}-J_{yy})^2+4J_{xy}^2}
\]

The dominant eigenvector estimates the edge normal. `coherence = saturate(Δ / trace(J))` distinguishes a strongly oriented edge from an isotropic/noisy region. Guards handle near-zero trace, near-equal eigenvalues and near-zero eigenvector length. Edge activity multiplies a contrast confidence (`smoothstep(0.025, 0.20, edge_magnitude)`) by an orientation confidence (`smoothstep(0.15, 0.60, coherence)`).

Each neighbour's weight combines:

- a spatial factor (`1` for the four cardinal offsets and `1/√2` for diagonals);
- a Gaussian-like range factor `exp(-0.5 * D² / 0.18²)`;
- an anisotropic Gaussian factor derived from distance along the estimated edge normal and tangent.

As coherent edge activity rises, the normal scale moves toward `0.62` while the tangent scale moves toward `1.18`. The filter therefore becomes narrower across the edge and modestly broader along it. The centre sample has a fixed weight of `1.5`; the weighted neighbour sum is normalized before blending with the centre.

The requested blend is `pixel_smoothing * lerp(0.30, 1.0, edge_activity)`. This retains a restrained 30% baseline in flat/uncertain regions while allowing the full configured blend near a coherent edge. The control's default is `0.35`; zero disables the adaptive blend.

Detail confidence is independent of whether the Pixel Smoothing blend is used. The shader finds the largest of the eight local comparison distances, maps it through `smoothstep(0.025, 0.16, local_detail)`, and combines it with `0.75 * edge_activity` using `max()`. This protects isolated dots and irregular texture as well as coherent edges. The same metadata is passed to the vertical filter for the final grain stage.

By default, only the centre contribution receives the adaptive 3×3 blend. Adjacent source cells used by the horizontal reconstruction remain raw source samples; the shader does not repeat the full tensor calculation for every horizontal tap. The left/right samples from the neighbourhood are cached and reused by adjacent convolution taps.

The optional `Adjacent-Tap Edge Blending` control extends this to the immediate horizontal taps (`-1` and `+1`). It builds a smaller structure tensor from the two cached columns and three cached rows available for each adjacent tap, then blends that tap using five cached neighbours plus its target sample. The left and right filters are oriented toward the central column. This is a six-sample/two-column approximation, not a full 3×3 filter centred on each adjacent tap. It adds no texture fetches, but it adds comparison, tensor and weighting arithmetic when enabled. It is active only in Edge-Aware and Hybrid Pixel Smoothing modes; it is off by default to preserve the existing reconstruction.

### 6.3 Horizontal source-cell reconstruction

Horizontal reconstruction treats each internal source sample as a constant-valued cell and integrates the selected spot profile over that cell's interval. It is a box-convolved reconstruction kernel, not a point sample at each destination pixel.

The base width combines `Horizontal Source-Pixel Smoothing` and `Horizontal Beam Spot Width` in quadrature:

\[
\sigma_{source}=source\_smooth_h\cdot reconstruction\_scale_x
\]
\[
\sigma_{spot}=\frac{beam\_horizontal\_spot\cdot(ScreenHeight/1080)}{internal\_cell\_width_{output\ px}}
\]
\[
\sigma_{base}=\sqrt{\sigma_{source}^2+\sigma_{spot}^2}
\]

Each source cell's raw linear R/G/B drives independently widen their channel's sigma by a small internal maximum of 3.5%:

\[
\sigma_c=\sigma_{base}(1+0.035\cdot saturate(C_c/1.25))
\]

The raw source colour sets current even when the centre pixel's adaptive blend changes the displayed reconstruction colour. This keeps the current-width response tied to the original source cell rather than the filter output. The 3.5% coefficient is an implementation constant, not a measured gun-current curve or a UI control.

The selected profile is integrated over the source-cell interval `[distance - 0.5, distance + 0.5]`:

- **Gaussian:** use a normal-CDF difference based on an error-function approximation.
- **Super-Gaussian:** integrate `exp(-0.5 * (x/σ)^4)` with bounded 16-point Gauss-Legendre quadrature. Negligible tails are clipped at ±4σ and the result is normalized by approximately `2.1556σ`.
- **Lorentzian:** use the arctangent primitive, clipped to finite ±5.5-native-cell support and normalized by its finite integral `2 atan(radius/σ)`.

Each source cell's own kernel is normalized. The output is not divided by the sum of heterogeneous cell weights: such a normalization would counteract the intentional fact that different source cells/channels have different widths and distribute energy differently. The finite support is a bounded-cost approximation, especially for the Lorentzian's long tails.

### 6.4 Horizontal Spot Structure: Single Lobe and Core + Tail

This selector changes the horizontal spot reconstruction, not the vertical beam model. Both structures use the selected Gaussian, Super-Gaussian or Lorentzian profile family.

**Single Lobe** uses the existing one-component kernel. It is the default.

**Core + Tail** mixes two separately normalized kernels:

\[
W_{mix}=(1-\eta)W(\sigma)+\eta W(k\sigma)
\]

where:

- `η` is `Horizontal Spot Tail Energy (%) / 100`;
- `k` is `Horizontal Spot Tail Width (x)`, clamped to at least 1;
- default `η = 0.02` and `k = 2.0`.

The tail redistributes energy; it does not add a second unnormalized brightness contribution. Both components use the same profile family and the same per-channel current-expanded core sigma. The tail controls do nothing in Single Lobe mode. A zero tail energy or a width of 1× reduces to the single-lobe kernel. The visible controls are 0–10% in 0.25% steps and 1×–4× in 0.05 steps.

The support calculation expands only when the tail mode requires it. Lorentzian support remains based on its finite native-cell extent; Gaussian-family support is widened enough to include the active tail while retaining a bounded loop.

### 6.5 Vertical source-pixel smoothing

`PS_SmoothV()` performs a separate vertical source reconstruction after horizontal filtering and before CRT scanline modulation. Its requested sigma is `source_smooth_v * reconstruction_scale_y`, so the visible control remains measured in fractions of a native raster line while the internal sample grid becomes finer.

Each vertical internal source-line cell contributes a Gaussian area weight formed from the normal-CDF difference at its upper and lower boundaries. The loop support is limited to at most two native lines, converted to internal-grid cells. RGB and the detail-confidence alpha are filtered with the same weights. If the requested sigma is effectively zero, the horizontal result passes through unchanged.

This stage is not the CRT beam. In particular, the Per-source-line RGB beam model reads the already vertically smoothed `tSmoothV` source and does not apply the vertical source-pixel filter a second time.

## 7. Scanlines and beam reconstruction

The vertical CRT raster treatment is controlled by the **Scanlines & Beam** category. The category contains a master enable, the legacy Sine waveform, two Gaussian-family vertical beam models, shared profile/drive controls, pitch controls and phase controls.

### 7.1 Enable Scanlines master switch

`scanlines_enabled` is the first control in the section and defaults to `true`. When unchecked, the scene scanline multiplier remains exactly `1.0`: the Sine path and both Gaussian-family beam models are bypassed. This is a true neutral modulation path, not a request to set strength to zero. Phosphor masks and damping wires are separate structures and remain active. Halation, ghosting, vignette, grain and other effects also remain active.

### 7.2 Beam profile functions

`beam_profile_value(x, profile)` supports three shapes:

1. **Gaussian:** `exp(-0.5*x*x)`.
2. **Super-Gaussian:** `exp(-0.5*x^4)`, flatter near the centre and steeper at the shoulders.
3. **Lorentzian:** `1/(1+x*x)`, with heavier tails.

`Beam Spot Profile` supplies the profile used by the horizontal spot-cell integrator and by the Gaussian Beam vertical path. The Sine profile is a separate waveform and does not use the vertical model selector.

### 7.3 Sine scanline profile

The Sine option keeps a shaped periodic waveform. For source luminance `lum`:

\[
amp=0.18\cdot strength\cdot(1-beam\cdot lum)
\]
\[
shaped=sign(sin(phase))\cdot|sin(phase)|^{sharpness}
\]
\[
floor=lerp(1.0,0.35,saturate(strength))
\]

The modulation is `clamp(floor + amp*shaped, 0, 1)`, then raised to `0.9` for the final scanline factor. Strength 0 is neutral; strength 1 has the previous waveform baseline; strengths above 1 retain the `0.35` floor while amplitude continues to grow. `Vertical Beam Model`, `Beam Current Response` and `Beam Average Drive` do not replace the Sine waveform.

### 7.4 Pixel-footprint-integrated shared beam

The default **Shared Beam** model uses one beam width for the pixel, derived from source luminance measured before ghosting, mask, display colour transform, halation and bloom. The base sigma is mapped from `Vertical Beam Sharpness`:

\[
t=saturate((sharpness-0.5)/2.5)
\]
\[
\sigma_0=lerp(0.14,0.055,t)
\]
\[
I=saturate(Y_{beam})^{BeamCurrentResponse}
\]
\[
\sigma=\max(\sigma_0(1+0.65\cdot ScanlineBeamWidening\cdot I),0.02)
\]

Higher sharpness therefore narrows the base spot. Brighter source luminance can widen it. `Beam Current Response` shapes the luminance-to-width mapping; 1 is a linear exponent.

The selected repeating spot is integrated over the complete vertical footprint of the current output pixel. `ddy(line_cycles)` estimates the line-coordinate change across one output pixel and therefore incorporates the actual viewport, image-fit transform, Edge Zoom and selected pitch. The periodic integrator splits any footprint crossing a source-line period boundary and wraps each segment into the central interval.

The profile integral is computed as follows:

- Gaussian uses an error-function primitive (with a bounded approximation).
- Lorentzian uses `σ * (atan(hi/σ) - atan(lo/σ))`.
- Super-Gaussian uses bounded 16-point Gauss-Legendre quadrature over the clipped interval.

The pixel-integrated value is normalized by the selected profile's own integral over one line period. This retains unit mean before `Beam Average Drive`, including beam widths where an infinite-domain Gaussian approximation would omit meaningful periodic tails. The resulting beam drive is blended with neutral using `saturate(ScanlineStrength/2)`, then raised to `0.9` for the stored scanline factor.

### 7.5 Per-source-line RGB beam model

**Per-source-line RGB** is an alternative vertical reconstruction algorithm; it does not replace the Shared Beam implementation. It is available when Gaussian Beam is selected. It samples nearby native source lines independently rather than deriving one shared current from the current pixel's luminance.

For each output pixel the model:

1. Computes the beam coordinate using the selected native/manual/stock pitch and the current field/rolling phase.
2. Finds the central source-line index and determines a bounded support radius. Gaussian-family support is ±4σ; Lorentzian support uses a fixed ±5.5-line radius.
3. Iterates nearby source-line centres, up to the shader's fixed ±8-line loop bound, and includes a line only when its beam support overlaps the output pixel's vertical footprint.
4. Maps each source-line centre back through the selected pitch transform and samples `tSmoothV`. Red, green and blue are read from their corresponding source channel.
5. Derives three separate current responses:

\[
I_R=\operatorname{sat}(R_{line}/1.25)^{response},\quad
I_G=\operatorname{sat}(G_{line}/1.25)^{response},\quad
I_B=\operatorname{sat}(B_{line}/1.25)^{response}
\]

and three corresponding sigmas using the same `σ0 * (1 + 0.65 * widening * I_c)` relationship as the shared model.
6. Integrates each channel's selected profile over the output-pixel footprint, normalizes it by that truncated source-line profile's area, and includes the channel's edge-validity mask.
7. Accumulates source colour and beam weights independently for R/G/B. The source colour is divided by its accumulated channel weight, while the beam factor is formed from the channel weight sum multiplied by `Beam Average Drive` and raised to `0.9`. The result is blended with the original source using `saturate(ScanlineStrength/2)`.

This separates the chromatic source reconstruction from its spatial beam factor: the sampled source colour is not simply multiplied by a shared luminance mask. Each line's individual channel drive can widen that channel's corresponding beam contribution. The source signal remains in the linear domain and proceeds through the same phosphor mask, profile, contrast, saturation and vignette stages afterward.

`Per-source-line RGB Attenuation` controls where the resulting channel-specific beam factor is applied:

- **Source-Domain (`0`, default):** preserves the original implementation. The reconstructed source colour and its RGB beam attenuation are blended into the source before ghosting, phosphor masking, display colour conversion, contrast, saturation and vignette.
- **Post-Display (`1`):** blends the reconstructed source colour into the source at the same early point, but defers the RGB beam attenuation. The channel-specific factor is applied after display-colour conversion, contrast, saturation and vignette, alongside the late Shared Beam modulation. This makes the attenuation stage more comparable between the two beam models, but changes how ghosting and the display transforms interact with scanline depth. The RGB factor is applied in the current BT.709 working/output channel coordinates; this is an intentional screen-space approximation, not a physical gun-domain operation.

The scalar luminance-weighted summary of the effective RGB factor remains in `tCrtScene.a` for `Halation Respects Scanlines`. The Post-Display option is only meaningful for Per-source-line RGB with Gaussian Beam selected. The ordinary selector defaults to Source-Domain. `Field-Phase Flicker` explicitly overrides that setting to Post-Display (Shared Beam-aligned) while active, regardless of the user's normal selector choice; the user's selected attenuation stage resumes unchanged when the toggle is disabled.

The source has already passed through `PS_SmoothV`; the beam model does not repeat vertical source-pixel smoothing. It is still an approximation: it does not simulate an actual deflection yoke, gun circuitry, measured electron-beam trajectory or time-domain per-channel gun physics.

### 7.6 Pitch selection

The scanline coordinate has three routes:

1. **Stock pitch:** if native matching is off and `Source-Line Frequency` is `0` (or ≤0.5), use the retained NewPixie-derived stock phase based on `screen_uv.y * screen_size.y * 1.5`.
2. **Manual pitch:** if native matching is off and the frequency is above 0.5, use the transformed source coordinate multiplied by that frequency.
3. **Native pitch:** if `Match Scanlines to Source Resolution` is on and DuckStation supplies valid native dimensions, use the active viewport divided by `NativeWidth/NativeHeight`.

Native mode takes precedence over the manual frequency. If the semantic is missing or zero, the code falls back to manual/stock logic. The CRT scanline pitch deliberately stays tied to native source dimensions even though source reconstruction can use the finer internal render dimensions.

### 7.7 Rolling phase and alternating field phase

`Rolling Scanlines` adds a continuously changing phase derived from the elapsed-time clock:

\[
\phi_{roll}=mod(6\cdot frameClock,2\pi)
\]

`Alternating Field Phase` uses `FCount` parity. On alternating rendered frames it changes the procedural scanline/beam phase between `0` and `π` radians. Since the phase is converted from radians to line cycles by division by `2π`, the odd/even states are displaced by exactly `0.5` of a scanline period. In other words, the whole procedural beam pattern alternates between two vertical phase positions separated by half a period; it does not model a single physical beam travelling from the top to the bottom. It is not real field input and does not reconstruct interlaced fields.

The shader uses two timing sources deliberately:

- `timer` is milliseconds since game start. `animation_frame_clock() = max(timer,0) * 0.06` converts it to a 60 Hz-equivalent frame clock. Continuous animation rates therefore retain their old nominal speed at 60 FPS while being based on elapsed time rather than actual rendered frame count.
- `FCount` remains for discrete frame behaviour: first-frame history clearing, odd/even alternating phase and an existing frame-parity branch. Do not replace these discrete uses blindly with timer values.

### 7.8 Experimental: Field-Phase Flicker

The **Experimental** category contains `Field-Phase Flicker`, off by default, followed immediately by a persistent explanatory text entry (`field_phase_flicker_help`). The same description appears in the toggle's tooltip and in the visible legend below it.

When enabled, the mode overrides **all 18 user-adjustable settings in Scanlines & Beam**. It pins them to their current saved defaults, except for these forced values:

- `Enable Scanlines`: On.
- `Vertical Beam Model`: Per-source-line RGB.
- `Rolling Scanlines`: Off.
- `Alternating Field Phase`: On.
- `Per-source-line RGB Attenuation`: Post-Display (Shared Beam-aligned, `1`).

All remaining Scanlines & Beam settings are forced to the current UI defaults: Gaussian Beam; strength `1.7`; sharpness `1.0`; widening `0.75`; Gaussian spot profile; Single Lobe; tail energy `2%`; tail width `2×`; horizontal spot width `0.15`; current response `0.50`; average drive `0.15`; source-line frequency `340`; native-pitch matching off. The UI uniforms are not overwritten. The shader reads effective `PX_...` override values, so user changes made while the mode is active are ignored by rendering and take effect again when the mode is turned off.

The mode also defers the per-channel RGB beam attenuation until after the display-colour, contrast, saturation and vignette stages, alongside the Shared Beam modulation. This Post-Display placement changes how the beam factor interacts with the colour pipeline, but it does **not** set the flicker's timing.

The rapid CRT-like flicker follows directly from the interaction of the forced settings and the phase calculation:

1. `PX_SCANLINE_PROFILE` is forced to Gaussian Beam, and `PX_VERTICAL_BEAM_MODEL` is forced to Per-source-line RGB. The shader therefore reconstructs the vertical image from nearby native source-line contributions, evaluating separate red, green and blue channel weights using the selected Gaussian beam profile.
2. `PX_INTERLACE` is forced on. The code takes `FCount % 2` and selects a phase of `0` for one parity and `π` for the other.
3. In the Per-source-line RGB path, `beam_line_shift = (beam_rolling_phase - beam_field_phase) / (2π)`. With Rolling Scanlines forced off, `beam_rolling_phase` is zero, so the `π` phase difference becomes a `0.5`-cycle displacement in `beam_coordinate` on alternating frames.
4. The native source-line sampling grid remains anchored to the raster, but the shifted beam coordinate changes each output pixel's selected neighbouring lines and their signed distances. The Gaussian integration therefore redistributes the weights assigned to those source-line contributions on each successive frame. The visible result is the entire vertical beam pattern rapidly alternating between two half-period-separated positions.

This is why the effect can look like an extremely fast top-to-bottom CRT flicker. Strictly, the shader is **not** sweeping one beam sequentially down the screen: it changes the phase of the complete screen-space pattern globally between rendered frames. The forced `Source-Line Frequency = 340` determines the pattern's spatial density, not its temporal speed. Because Rolling Scanlines is off, the rapid motion is driven by discrete `FCount` parity rather than the elapsed-time animation clock. At 60 rendered FPS, the phase state changes on every frame and the two-state pattern completes 30 cycles per second; at a rendered rate of `F` FPS, the parity state changes at `F` changes per second and the two-frame cycle repeats at `F/2` Hz. Actual presentation depends on frame pacing and display refresh.

Other shader settings—such as the display profile, phosphor mask, brightness, contrast, ghosting, halation, bloom and grain—can change how prominent or soft the flicker appears, but they do not cause its phase timing. The Post-Display attenuation stage also affects the visual placement of per-channel dimming, not the alternating-frame clock. The UI's ordinary Scanlines & Beam selections are preserved while the toggle is active and resume unchanged when it is disabled.

This can be a visually intense effect and may cause eye strain or dizziness for some viewers. It is worth experimenting with in motion to judge its interaction with different content, while considering viewing comfort. The mode is therefore intentionally **off by default**. It is an experimental global phase-driven effect, not a physical top-to-bottom beam sweep, actual 480i, or independent odd/even field reconstruction.

## 8. Phosphor masks and damping wires

The phosphor mask modulates the individual RGB channel drives in `PS_RenderCRTScene` before the display-colour matrix is applied. It is stored in the CRT scene and therefore follows the completed image when curved geometry is used. Available types are Aperture Grille, Slot Mask, Shadow Mask (Staggered Dots), and None.

### 8.1 Automatic mask pairing and selection

`active_phosphor_mask_type()` resolves `Phosphor Mask Type`:

| Display Color Profile | Automatic mask |
|---|---|
| Sony Trinitron — Japanese Cool | Aperture Grille |
| Sony Trinitron — Balanced Color | Aperture Grille |
| Sony BVM-D24 — EBU Cool | Aperture Grille |
| Sony KX-14CP1 — Monitor Reference | Aperture Grille |
| Toshiba AF — Balanced Color | Slot Mask |
| Toshiba AF — Warm Cinema | Slot Mask |
| Standard — Reference Color | Aperture Grille |

Selector `Use Display Profile Default` uses the pairing above and built-in mask constants. Explicit selections map to Aperture Grille, Slot Mask, Shadow Mask or None and use the matching Custom controls. An explicit mask changes only the mask; it does not change the display-colour profile. `None` returns a neutral `(1,1,1)` mask.

### 8.2 Aperture Grille

Aperture Grille is a repeating vertical RGB stripe/triad pattern. It is integrated analytically over the horizontal footprint of each output pixel rather than sampled with a fixed 16-point box loop.

The stripe transition is a smoothstep-like profile. Its integral uses the polynomial primitive:

\[
F(z)=z-z^3+\frac12z^4
\]

The implementation computes the area of one stripe, extends it periodically, builds the integral for each channel over a three-cell RGB triad, evaluates that integral at the left and right edges of an output-pixel footprint and divides by the footprint width. This gives continuous fractional coverage for non-integer triad pitches without a per-output-pixel 16-sample loop. The integral is exact for the defined one-dimensional smoothed stripe shape, not an exact measured CRT grille profile.

The profile pitch is scaled using active viewport height relative to 1080p. It also enforces a **minimum three-output-pixel RGB triad period**:

\[
pitch=\max(\max(maskPitch,1.5)\cdot ViewportHeight/1080,3.0)
\]

The X coordinate is offset by `ViewportOffset.x`, so grille phase is anchored to the active image viewport rather than unrelated window borders or letterbox areas. The minimum triad period is a perceptual anti-aliasing safeguard for low output resolutions; it is not a physical pitch calibration. At sufficiently high output resolutions it does not affect the requested pitch.

The channel coverage is blended from neutral transmission by mask strength. A mean-transmission compensation factor attempts to keep average RGB output stable as strength changes. Aperture Grille uses its analytic stripe area for the mean duty estimate.

### 8.3 Slot Mask

Slot Mask uses vertical RGB slots interrupted by horizontal opaque gaps. Alternate rows are staggered by half a triad. Row pitch is `max(0.8 * triadPitch, 1.5)` output pixels. The horizontal stripe coverage is smoothed, while vertical slot coverage is controlled by `Slot Height`.

The 2D slot shape is integrated using an 8×8 subpixel sample grid. The slot-height transition preserves the requested midpoint at half-height and narrows its transition near full height. At exactly `Slot Height = 1`, vertical coverage is explicitly full. The mean-transmission duty estimate uses the slot-height multiplier, but remains an approximation.

### 8.4 Staggered Shadow Mask

Shadow Mask uses staggered elliptical RGB emitting regions, with alternate rows displaced by half a triad. It is a generic RGB-dot pattern, not a measured delta-triad geometry from a particular CRT. It uses the same 8×8 subpixel coverage grid and an approximate mean-duty compensation.

Slot and Shadow masks keep their pre-existing output-height pitch scaling and minimum pitch behaviour; the three-output-pixel triad floor is specific to Aperture Grille.

### 8.5 Strength, width, gap and built-in defaults

Built-in mask values are constants in the shader, separate from user-editable Custom values:

| Mask | Strength | Pitch at 1080p | Width | Gap | Other |
|---|---:|---:|---:|---:|---|
| Aperture Grille | `0.24` | `3.0 px` | `0.95` | `0.10` | Built-in damping wires off; wire strength constant `0.05`. |
| Slot Mask | `0.40` | `4.0 px` | `0.60` | `0.50` | Slot height `1.0`. |
| Shadow Mask | `0.24` | `3.0 px` | `0.95` | `0.10` | Elliptical dots. |

For all patterns, mask strength blends from neutral white transmission to the computed pattern. The approximate compensation is:

\[
mask=\frac{lerp(1,pattern,strength)}{lerp(1,meanDuty,strength)}
\]

For Aperture Grille the mean duty follows the analytic stripe area. Slot and Shadow use approximations based on requested stripe width, slot height and an elliptical-area factor.

### 8.6 Damping wires

Optional Aperture Grille damping wires are two horizontal attenuation bands centered at one-third and two-thirds of the active viewport height. Built-in profile wires and the custom checkbox are both off by default. They only apply while Aperture Grille is the active mask.

The wire retains its original smoothstep-like shape: full attenuation weight within `±0.25` output pixels of the centre, a transition shoulder to zero at `±1.0` pixel, and the selected wire-strength multiplier (built-in/custom default `0.05`). The shape is integrated analytically over each output pixel's one-pixel vertical footprint using a signed primitive. This removes subpixel flicker/shimmer without changing the intended width or profile shape. Wire centres are calculated relative to the active `ViewportOffset` and `ViewportSize`.

Do not enable damping wires as a universal Trinitron property; tube construction varies.

## 9. Display colour profiles

The display profiles transform linear RGB channel drives into an approximate display phosphor gamut/white and express emitted values in the shader's linear BT.709 working/output coordinates. They are reference interpretations, not factory calibration files. The profile selector order is intentional: Sony Trinitron is the central hardware/design reference and the first two choices; Standard is last as the neutral/bypass option. These profiles only provide colour/white-point customization and the documented automatic mask pairing. They do not select a different complete CRT hardware model: all other shader subsystems remain part of the same Trinitron-oriented presentation.

| Index | UI name | Reference interpretation | Automatic mask |
|---:|---|---|---|
| 0 | Sony Trinitron — Japanese Cool | P22 primaries with the preferred Japanese/NTSC-J cooler white blend; default. | Aperture Grille |
| 1 | Sony Trinitron — Balanced Color | P22 primaries at the D65 endpoint. | Aperture Grille |
| 2 | Sony BVM-D24 — EBU Cool | Nominal EBU primaries with the existing Japanese Cool neutral-white character. | Aperture Grille |
| 3 | Sony KX-14CP1 — Monitor Reference | Separate Sony monitor-oriented measured/model reference assumptions. | Aperture Grille |
| 4 | Toshiba AF — Balanced Color | SMPTE-C primary approximation with D65 reference white. | Slot Mask |
| 5 | Toshiba AF — Warm Cinema | SMPTE-C primary approximation with D55-style warm white. | Slot Mask |
| 6 | Standard — Reference Color | Bypasses the display-profile matrix; retains later shader processing. | Aperture Grille |

### 9.1 Sony Trinitron — Japanese Cool (default)

The Japanese P22 path uses two estimated matrices:

- `p22_d65`: estimated P22 primaries expressed relative to D65;
- `p22_ntscj`: the same broad P22 primary model with the estimated Japanese/NTSC-J white reference.

The default computes `lerp(p22_d65, p22_ntscj, 0.71)` using the locked `japanese_whitepoint = 71.0` constant. The result is deliberately not chromatically adapted back to D65; doing so would remove the cooler/blue-ish neutral character the profile is intended to retain. These are aggregate/reference estimates, not a Sony-specific factory calibration.

### 9.2 Sony Trinitron — Balanced Color

Uses the P22 D65 matrix endpoint directly. It retains the broad P22 primary interpretation but does not apply the Japanese Cool white-point interpolation.

### 9.3 Sony BVM-D24 — EBU Cool

Uses nominal EBU phosphor primaries documented for the BVM-D24E1WE/E1WA reference family. Its matrix is calculated to produce the same cool neutral-white RGB vector as the existing Japanese Cool default. This makes it a hybrid colour-reference option: EBU primaries plus the project's preferred Japanese Cool white character. It is not a factory BVM-D24 D56/D65/D93 preset or a measurement of an individual monitor. The E1WU SMPTE-C phosphor standard is represented by the Toshiba SMPTE-C/D65 reference transform rather than a duplicate profile. This profile changes the colour reference only; it does not change the shader's Trinitron-oriented hardware/effects design target.

### 9.4 Sony KX-14CP1 — Monitor Reference

Uses the separate model profile recorded in the source comments: R `(0.647, 0.335)`, G `(0.279, 0.635)`, B `(0.152, 0.060)`, and white XYZ `(0.903, 1.000, 1.185)`. This matrix is based on a manually calibrated model reference and its associated output-gamma context. It should not be treated as a universal response for every Sony Trinitron set or as a complete measured device characterisation.

### 9.5 Toshiba AF — Balanced Color

Uses standard SMPTE-C primary coordinates as a reference proxy, expressed with a D65 white-point interpretation. The transform is an approximation, not measured Toshiba AF hardware data.

### 9.6 Toshiba AF — Warm Cinema

Uses the same SMPTE-C primary approximation with a CIE D55 white-point interpretation (`x=0.33242, y=0.34743`). It is an explicitly aesthetic warm cinema take, not a measured AF/Cinema factory preset.

### 9.7 Standard — Reference Color

Returns the incoming working RGB unchanged from `apply_display_color_profile()`. The mask, contrast, saturation, vignette, scanlines, halation, bloom, filmic curve and final output processing still apply; this is not a bypass of the whole shader.

### 9.8 Gamut compression and saturation neutral

Some profile matrices create negative RGB components for colours outside the target gamut. The shader calculates Rec.709 luminance `Y`; when the minimum transformed component is negative and `Y > 0`, it scales chroma toward the equal-luminance neutral axis:

\[
s=\operatorname{sat}\left(\frac{Y}{Y-C_{min}}\right),\qquad
C'=Y+(C-Y)s
\]

This preserves approximate hue and luminance better than clipping each negative channel independently. Positive values above 1 are left to the existing highlight roll-off.

The Saturation control interpolates between the transformed colour and the selected profile's own neutral-white vector normalized to unit Rec.709 luminance. For Japanese Cool this neutral is not `(1,1,1)` in BT.709 coordinates; mixing toward equal RGB would pull its white back toward D65. This profile-relative neutral axis is deliberate.

### 9.9 Locked selective warm-colour desaturation

A compile-time feature in the final composite evaluates hue in an approximate display-referred view (`pow(saturate(linearRGB), 1/2.2)`) and applies a limited saturation reduction to a warm hue interval. It avoids near-neutral pixels where hue is unstable. The reduction is applied to the original linear RGB toward equal-luminance neutral, preserving Rec.709 luminance. Its hue centre/range/feather/reduction are locked internal constants, not user sliders. This is a subtle colour trim, not a scene/object detector.

## 10. Ghosting, halation, bloom, vignette, fringing and flicker

### 10.1 Source-image ghosting

The first horizontal/vertical blur pair operates on the decoded, accumulated source image before CRT scene rendering. It uses a symmetric nine-tap Gaussian approximation:

```text
centre  0.2270270270
±1      0.1945945946
±2      0.1216216216
±3      0.0540540541
±4      0.0162162162
```

`Horizontal Blur` and `Vertical Blur` set tap spacing in output pixels. Axis-specific edge validity prevents clamp-addressed edge texels from bleeding inward. For supported half- and one-pixel spacing cases, and only when the entire kernel is safely inside the image, the linear Gaussian taps can be combined into five exact bilinear paired fetches. Otherwise the original nine evaluations are retained. A zero Ghost Strength early-outs the source-blur passes; a zero axis radius returns the unblurred sample in that axis.

`PS_RenderCRTScene()` samples the blurred source at several slightly displaced, time-varying positions with channel-separated weightings. The contribution is small and shaped by a source beam-luminance term. It is a stylized coloured ghosting approximation, not a reflection model or a full multi-path analog signal simulation.

### 10.2 Optical halation

Halation is extracted from the **completed CRT emission**, after source reconstruction, beam, phosphor mask, damping wires, display colour transform, contrast/saturation, vignette, scanline modulation and brightness. This is important: the blur source represents the light emitted by the simulated CRT scene rather than the untouched game image.

`halation_brightpass()` calculates Rec.709 luminance `Y` from `tCrtScene.rgb` and maps the selected threshold `T` into a normalized scalar bright-pass:

\[
H=\operatorname{sat}\left(\frac{Y-T}{\max(1-T,0.001)}\right)
\]

The scalar field receives horizontal and vertical nine-tap Gaussian blur using the shared `Horizontal Blur` / `Vertical Blur` controls. The horizontal stage retains nine evaluations because thresholding is nonlinear; pairing raw source samples before the threshold would not be equivalent to filtering the thresholded result. The vertical pass can use the exact five-fetch paired bilinear optimization for supported spacing cases because its bright-pass scalar has already been extracted.

The final glow tint interpolates from white to warm amber `(1.0, 0.72, 0.48)` according to `Halation Warmth`.

`Halation Respects Scanlines` chooses between two compositing treatments:

- **Off (default):** add the blurred glow without multiplying by scanline metadata again. This allows optical glow to spread into dark scanline gaps.
- **On:** multiply the blurred glow by the reconstructed local scanline factor stored in `tCrtScene.a`, retaining scanline modulation in the glow.

When `Halation Strength <= 0.00001`, both halation blur passes return zero before normal sampling, and `halation_contribution()` returns zero. Halation is independent of Bloom and can remain active when Bloom is disabled.

### 10.3 Bloom extraction, blur and composition

Bloom is extracted from the 4×4 samples of the full-resolution post-mask/post-scanline scene plus the direct halation contribution. Each of the 16 samples is thresholded before averaging, so a small bright highlight is not diluted below threshold by the downsample. The maximum RGB component is used as the sample peak instead of luminance alone, allowing saturated highlights to contribute. The RGB vector is scaled by one common factor to preserve hue.

For peak `P`, threshold `T`, and knee `K=T*saturate(softKnee)`, the soft contribution is formed by:

\[
soft=\frac{clamp(P-T+K,0,2K)^2}{4K}
\]

when `K > 0`; the final contribution is `max(P-T, soft)`. With a zero knee, the hard positive part `max(P-T,0)` is used. The bright RGB vector is multiplied by `contribution / max(P,epsilon)`.

The result is written to quarter-resolution `tBloomA`. A separable nine-tap Gaussian blur runs at quarter resolution with the radius still expressed relative to the 1080p full-output scale. Supported half- and whole-quarter-texel tap spacing can use five paired bilinear samples in safe interior regions; other cases use the nine-tap kernel.

At final composite, the blurred bloom is added to the linear CRT scene using `Bloom Intensity` before the filmic tone curve. Halation is also fed into extraction, so local halation and broad bloom intentionally stack.

**Zero-intensity behaviour:** when `Bloom Intensity` is exactly `0`, `PS_ExtractBloom`, `PS_BloomBlurHorizontal` and `PS_BloomBlurVertical` return zero before their normal texture sampling, 4×4 extraction or blur taps; the final composite skips the bloom texture sample. The three quarter-resolution passes are nevertheless still scheduled by the host and write zero. ReShade FX does not provide a uniform-driven technique-pass dispatch switch. Diagnostics `Bloom Blur` and `Bloom Extract` intentionally override the zero-intensity bypass so the intermediate buffers can still be inspected. This means the shader removes most bloom calculations at zero but does not remove pass scheduling/target writes.

### 10.4 Vignette

The vignette is evaluated in CRT scene/faceplate texture space. A symmetric product of distances to four image boundaries is shaped with a square root and a `0.1` floor, then blended by `Vignette Strength`. `Vignette Mapping = Symmetric Viewport` (default) normalizes `SV_Position` against DuckStation's active viewport offset and size, then evaluates the same curve in that rectangle. It gives matching mathematical falloff at the four active-image edges and does not assume the image fills the entire output buffer. `Legacy Fit` remains available and uses the retained NewPixie-derived `screen_uv` coordinates, including their existing unequal horizontal/vertical edge mapping. This is an aesthetic edge falloff, not a measured CRT luminance distribution. The selector changes only vignette coordinates; it does not alter source sampling, geometry projection or scanline pitch.

### 10.5 Colour fringing

The scene stage samples R, G and B at slightly different horizontal/vertical UV offsets, scaled by `Color Fringing`. This approximates a small channel misregistration/colour separation. It is not a complete convergence, beam landing or chromatic-aberration model. The per-source-line RGB beam path mirrors these channel offsets when reconstructing individual line samples.

### 10.6 Interference wobble

`Interference Strength` scales a product of animated sine functions of time and vertical position, producing small horizontal signal wobble. `Interference Speed` scales its time progression. A separate very small static coordinate term remains in the base mapping even when animated interference strength is zero; the UI control disables the animated component, not every static subpixel mapping offset.

### 10.7 Final flicker

The final composite applies a subtle multiplicative variation:

\[
C'=C\left[1-f\left(0.5\sin(50t+2y)+0.5\right)\right]
\]

where `f = flicker_amount`, `t` is the elapsed-time-derived clock wrapped for the composite, and `y` is screen-fit vertical position. This is a stylized frame/vertical modulation, not a measured mains ripple or power-supply model.

## 11. Grain and noise system

The grain is a deterministic hash-noise process with spatial scale, RGB correlation, temporal interpolation, grid alignment, luminance adaptation, image-aware chroma and source-detail protection. It is added after tone mapping and selective warm desaturation, before the final flicker and faceplate coverage.

### 11.1 Deterministic hash field

`hash_noise_u32()` applies xor-shifts and integer multiplications as an avalanche hash. `hash_noise_value()` combines integer cell X/Y, frame index and channel index. Unsigned overflow is intentional modulo-2³² arithmetic. The upper 24 bits are normalized into `[0,1)`, making the field deterministic for the same cell/frame/channel.

### 11.2 Grain size

At `Grain Size <= 1.0001`, `spatial_grain_value()` uses one hash per integer pixel cell, producing crisp grain. Above 1, it generates a coarser 2D lattice and bilinearly interpolates its four independently hashed corners using a smoothstep interpolation coordinate. It normalizes the local interpolation variance. Between size 1 and 1.5 it crossfades from fine cells to the coarse field and normalizes the blend so the size control primarily changes spatial correlation/scale, not nominal amplitude.

### 11.3 Temporal animation and frame-rate independence

`animated_grain_value()` samples deterministic noise at `floor(frameClock)` and the next frame index, then interpolates using a smoothstep of the fractional clock. The interpolation is variance-normalized. Frame indices wrap at 640. `Grain Animation Speed = 0` freezes the pattern; 1 advances one nominal noise index per 60 Hz-equivalent reference frame.

Continuous time derives from DuckStation's millisecond `timer` source via `animation_frame_clock() = max(timer,0) * 0.06`. This preserves the former nominal 60 FPS animation rate while making progression depend on elapsed time rather than render frame count. Discrete parity and history lifecycle still use `FCount`.

### 11.4 Alignment modes

- **Output Pixels:** grain uses `uv_tx * screen_size`, the final post-process output grid. It stays fixed to output pixels rather than bending with the projected faceplate.
- **Native Game Pixels:** `grain_source_uv()` reverses the scene's screen-fit/Edge Zoom/source mapping (including animated interference and the green-channel vertical convention), then divides by native source-pixel UV size. Native grain follows source-image structure.
- **Mixed:** generates independent output-grid and native-grid noise fields and combines their deviations from 0.5 with a `1/√2` factor, keeping combined variance near the individual field variance.

### 11.5 Detail protection

`PS_SmoothH()` stores source detail confidence in `tSmoothH.a`; `PS_SmoothV()` filters it into `tSmoothV.a`. `grain_detail_factor()` samples that metadata at the mapped source coordinate and blends the grain scale from 1 toward `1 - 0.85*detail` according to `Detail Protection`. This protects isolated dots, irregular textures, luminance edges and equal-luminance colour boundaries identified by the same 3×3 analysis used for adaptive Pixel Smoothing. It is not a semantic classifier and does not identify objects.

This reuse avoids another final-stage neighbourhood analysis. The alpha channel is metadata, not opacity.

### 11.6 Chroma and Image-Aware Chroma

`Grain Chroma = 0` uses a shared monochrome field for RGB. `1` uses independent channel fields. Intermediate values blend a shared field and independent RGB fields, then normalize the variance of that blend.

`Image-Aware Chroma` scales only the chromatic component. Near-neutral pixels receive mostly monochromatic grain; moderate saturation increases chroma activity; highly saturated details receive a softened independent-RGB component. It does not alter the image colour itself.

### 11.7 Amplitude and luminance adaptation

The centered grain field is scaled to an approximate per-channel standard deviation of `0.3` before clipping/adaptation, then multiplied by `Noise Amount` and detail protection. Luminance adaptation blends from uniform grain to a squared-luminance response:

\[
scale_Y=lerp(1, saturate(Y)^2, adaptation)
\]

At adaptation 1, grain is heavily reduced in shadows/midtones and retains more strength near white. This is independent from Detail Protection: one depends on final image luminance; the other depends on source-grid detail metadata.

`Headroom-Aware Grain` is an optional off-by-default output safeguard. When enabled, the shader computes the actual signed per-channel grain excursion after all spatial/temporal/chroma/alignment normalization and adaptation. It scales that excursion symmetrically to no more than the smaller of the current channel's distances to 0 and 1. Positive and negative excursions therefore receive the same attenuation at a given base pixel, avoiding one-sided clipping at the SDR rails and the resulting noise rectification. It needs no extra texture reads. Grain naturally weakens near black and white, and becomes zero exactly at either rail. When off, the existing grain addition and final `saturate()` remain unchanged; the final clamp can still rectify noise near the boundaries.

## 12. Optional screen geometry / curvature

### 12.1 Role in the shader

Curvature is optional. The default `CRT Surface Profile` is Flat, so the source image, phosphor mask, beam and glow can be judged without geometric projection. Curved modes project the completed CRT image onto a virtual faceplate; they do not repair game-world geometry or restore information missing from the rendered image.

### 12.2 Surface profiles and equations

Coordinates use screen half-width units. Vertical coordinates are corrected by output aspect ratio so spherical profiles behave as circular caps in screen space.

**Flat (`0`)** returns the original UV, full faceplate coverage and a single sample. The geometry reconstruction selector does not affect the Flat path.

**Cylindrical (`1`)** curves horizontally:

\[
sag(x)=R-\sqrt{R^2-x^2},\qquad \frac{dsag}{dx}=\frac{x}{\sqrt{R^2-x^2}}
\]

**Spherical (`2`)** curves in both axes:

\[
sag(x,y)=R-\sqrt{R^2-x^2-y^2},\qquad
\nabla sag=\frac{(x,y)}{\sqrt{R^2-x^2-y^2}}
\]

**Aspherical (`3`)** uses independent toric radii plus a normalized fourth-order departure:

\[
sag_{base}=R_x-\sqrt{R_x^2-x^2}+R_y-\sqrt{R_y^2-y^2}
\]
\[
r_n^2=x^2+(y\cdot aspect)^2,\qquad
sag_{departure}=\frac{departure}{4}(r_n^2)^2
\]

The analytic gradient includes the derivative of the departure term. The radii are clamped internally to avoid a zero square-root denominator. Smaller radii produce stronger curvature; positive/negative departure alters edge depth relative to the toric base.

### 12.3 Virtual camera and ray/height-field intersection

`project_crt_surface()` converts output UV to a plane point in aspect-corrected screen coordinates. It creates a virtual camera using `Virtual Camera Distance`, horizontal offset and vertical offset, then forms a ray from the camera to the plane point. The surface is represented as `z = sag(x,y)`.

For ray parameter `t`:

\[
P(t)=C+tD
\]
\[
f(t)=P_z(t)-sag(P_x(t),P_y(t))
\]
\[
f'(t)=D_z-\nabla sag\cdot D_{xy}
\]

Six Newton iterations update `t = clamp(t - f/f', 0.25, 3.0)` when the derivative is safe. The resulting hit point is converted back to faceplate UV. This is a ray/height-field projection, not a full glass-refraction, raymarching, lensing or physically based optics model.

### 12.4 Faceplate coverage and corner rounding

`crt_surface_coverage()` uses a signed-distance rounded rectangle. Coordinates are expressed in units based on the shorter output dimension so `Screen Corner Radius` means a fraction of that dimension. The signed distance is antialiased using a width based on the shorter output dimension. Flat mode returns full coverage. Coverage is multiplied into the final composite after grain/flicker.

### 12.5 Derivative-driven geometry reconstruction

For curved modes with adaptive reconstruction selected, `sample_crt_surface()` estimates the projected source-pixel footprint from `ddx(centre_uv)` and `ddy(centre_uv)`, scaled by texture size. It forms a 2×2 Jacobian metric `JᵀJ`, finds the major eigenvalue/eigenvector and samples along the principal/minification direction.

- **Bilinear (1 tap)** is the saved default and takes one ordinary linear texture sample.
- **Adaptive up to 4 taps** increases the line sample count according to the major footprint length and caps it at 4.
- **Adaptive up to 8 taps** uses the same method with an 8-tap cap.

The selected samples are weighted by rounded-faceplate coverage. RGB and `tCrtScene.a` scanline metadata use the same coverage weights. This is bounded one-dimensional anisotropic line reconstruction, not full two-dimensional EWA. The minor axis relies on the sampler's linear filtering and is not fully integrated; strong curvature or extreme minification can still show aliasing/blur trade-offs.

### 12.6 Pipeline integration

The mask, scanlines, display profile and vignette are rendered into `tCrtScene` before projection. Final composite projects and samples this completed scene; halation and bloom use the same faceplate UV. The phosphor structure therefore curves together with the image. Output-grid grain is an intentional exception and remains anchored to final output pixels; native/mixed grain follows mapped source coordinates.

## 13. Coordinate-space map

The shader uses several UV and pixel domains. Changing one transform without checking its paired consumers is a common source of alignment errors.

| Name/value | Meaning | Typical use |
|---|---|---|
| `uv_tx` | Current post-process/output pixel UV for the current pass. | Output-grid grain; render-target raster coordinates; mask base coordinate. |
| `uv` | Y-inverted coordinate derived from `uv_tx` in scene/composite code. | Retained NewPixie mapping. |
| `screen_uv` | Fitted image coordinate blended with the direct output coordinate. | Scene positioning, vignette and animation phase. |
| `scuv` | Compensated source coordinate after fit and `Edge Zoom`. | Main source-image mapping. |
| `geometry_uv` | Faceplate projection of final output UV; equals output UV in Flat mode. | Sampling CRT scene, halation and bloom. |
| `source_uv` | Back-mapped source coordinate associated with the projected scene sample. | Native/mixed grain and source-detail metadata. |
| `pixel` | UV multiplied by output-buffer dimensions. | Phosphor mask and footprint calculations. |
| `native_position` | Source UV divided by native source-pixel UV dimensions. | Native-aligned grain. |
| `ViewportOffset` | Active image rectangle's offset in output pixels. | Source-cell and aperture-grille anchoring. |
| `ViewportSize` | Active image rectangle size in output pixels. | Native/internal cell dimensions, source-line pitch and grille pitch. |
| `NativeWidth/Height` | Nominal game raster dimensions. | CRT raster pitch, native pixel units and native grain. |
| `InternalWidth/Height` | DuckStation's internal render dimensions. | Source reconstruction grid when enhanced internal rendering is active. |

`screen_fit_uv()` retains the fitted image inset and aspect/framing compensation. `PS_RenderCRTScene()` then applies the compensated `Edge Zoom` mapping. `grain_source_uv()` deliberately mirrors the scene's fit, zoom, interference and green-channel coordinate convention so native grain and detail protection stay aligned.

When changing screen-fit constants, Edge Zoom, channel offsets, interference or vertical inversion, inspect both `PS_RenderCRTScene()` and `grain_source_uv()`. When changing viewport semantics, inspect `source_native_pixel_size_px()`, `source_reconstruction_pixel_size_px()`, `source_viewport_offset_px()`, `source_viewport_size_px()`, mask anchoring and beam pitch together.

## 14. UI reference: all controls and current defaults

The `.fx` declarations contain the authoritative labels, categories, ranges, steps, combo items, tooltips and defaults. The tables below record all user-facing controls and key host uniforms as a developer reference. If a UI change is made, update this section and the user-facing README together.

### 14.1 CRT-Trinity identity

| Variable | Default | Purpose |
|---|---:|---|
| `project_version` | `v1` | Informational version selector shown in the shader UI. |
| `project_author` | `bone-machine` | Informational author field. |
| `project_credits` | Credits entry | Informational upstream/adaptation/host credits. |

The top-level version text is `v1`. Do not reintroduce historic version-series language into the project documentation or UI; describe the shader as one unified implementation.

### 14.2 Display Setup

| Variable | Default | Range / items | Purpose |
|---|---:|---|---|
| `display_profile` | `0` | Seven profile items, see §9 | Selects display colour transform. Japanese Cool is first/default; Standard is last. |
| `phosphor_mask_selection` | `0` | Profile Default / Aperture / Slot / Shadow / None | Automatic profile pairing or explicit mask selection. |
| `phosphor_mask_help` | `0` | Persistent text | Explains default mask pairing and custom submenus. |
| `edge_zoom` | `1.0` | `1.0–1.4`, step `0.001` | Crops/zooms the fitted source image; mirrored by native grain mapping. |

### 14.3 Image & Color

| Variable | Default | Range / step | Purpose |
|---|---:|---|---|
| `brightness` | `1.1` | `0.5–2.0`, `0.01` | Multiplies the rendered CRT scene after scanline modulation. |
| `contrast_curve` | `1.0` | `0–2`, `0.01` | Blends identity with the legacy luminance curve. |
| `saturation` | `0.94` | `0–2`, `0.01` | Mixes transformed RGB toward selected-profile neutral at equal luminance. |
| `crt_gamma` | `2.2` | `2.2–2.6`, `0.01` | Gamma parameter for the input EOTF approximation. |
| `black_level` | `0.004` | `0–0.1`, `0.001` | Normalized input display-black reference and coordinated filmic toe. |

### 14.4 Source Image Filtering

| Variable | Default | Range / step | Purpose |
|---|---:|---|---|
| `pixel_smoothing_mode` | Subpixel Blend (`1`) | Edge-Aware / Subpixel Blend / Hybrid | Chooses the reconstruction mode. |
| `pixel_smoothing` | `0.35` | `0–1`, `0.01` | Blend strength for the selected source-reconstruction mode. Zero disables the selected Pixel Smoothing operation. |
| `adjacent_tap_edge_blending` | `false` | Boolean | Optional six-sample cached edge-aware blend for the adjacent horizontal taps; Edge-Aware/Hybrid only. |
| `source_smooth_h` | `0.17` | `0–0.5`, `0.01` | Additional horizontal Gaussian kernel width in fractions of a native pixel. Combines in quadrature with horizontal beam spot width. |
| `source_smooth_v` | `0.10` | `0–0.5`, `0.01` | Separate vertical Gaussian source reconstruction width in fractions of a native raster line. |

### 14.5 Screen Geometry

This category appears immediately below Source Image Filtering in the UI.

| Variable | Default | Range / items | Purpose |
|---|---:|---|---|
| `screen_geometry` | Flat (`0`) | Flat / Cylindrical / Spherical / Aspherical | Selects virtual faceplate shape. |
| `surface_radius` | `8.0` | `2–40`, `0.1` | Horizontal/overall radius for Cylindrical and Spherical profiles. |
| `surface_radius_horizontal` | `6.0` | `2–40`, `0.1` | Aspherical horizontal base radius. |
| `surface_radius_vertical` | `12.0` | `2–40`, `0.1` | Aspherical vertical base radius. |
| `surface_aspheric_departure` | `0.015` | `-0.12–0.12`, `0.001` | Fourth-order edge-depth departure. |
| `camera_distance` | `4.0` | `2–20`, `0.1` | Virtual camera distance. |
| `camera_horizontal_offset` | `0.0` | `-0.5–0.5`, `0.005` | Virtual camera horizontal offset. |
| `camera_vertical_offset` | `0.0` | `-0.5–0.5`, `0.005` | Virtual camera vertical offset. |
| `screen_corner_radius` | `0.02` | `0–0.08`, `0.001` | Rounded faceplate corner fraction of the shorter image dimension. |
| `geometry_antialiasing` | Bilinear (1 tap, `0`) | Bilinear / Adaptive up to 4 / Adaptive up to 8 | Geometry-only reconstruction mode; Flat uses one sample regardless. |

### 14.6 Scanlines & Beam

This category has 18 user-adjustable settings. `Field-Phase Flicker` overrides all of them while enabled; see §7.8.

| Variable | Default | Range / items | Purpose |
|---|---:|---|---|
| `scanlines_enabled` | `true` | Boolean | Master switch. Off returns a neutral vertical scanline factor; masks remain. |
| `scanline_profile` | Gaussian Beam (`1`) | Sine / Gaussian Beam | Sine waveform or integrated beam profile. |
| `scanline_strength` | `1.7` | `0–2`, `0.05` | Blends/sets strength of beam modulation. |
| `scanline_sharpness` | `1.0` | `0.5–3`, `0.05` | Sine shape exponent or Gaussian-family base sigma. |
| `scanline_beam` | `0.75` | `0–1`, `0.05` | Brightness-dependent vertical widening. |
| `beam_spot_profile` | Gaussian (`0`) | Gaussian / Super-Gaussian / Lorentzian | Shape for horizontal and Gaussian vertical beam kernels. |
| `horizontal_spot_structure` | Single Lobe (`0`) | Single Lobe / Core + Tail | Selects one or two-component horizontal kernel. |
| `horizontal_spot_tail_energy` | `2.0` | `0–10%`, `0.25` | Fraction of horizontal spot energy redistributed to tail; Core + Tail only. |
| `horizontal_spot_tail_width` | `2.0` | `1–4×`, `0.05` | Tail sigma relative to core; Core + Tail only. |
| `vertical_beam_model` | Shared Beam (`0`) | Shared Beam / Per-source-line RGB | Existing shared current model or per-line/per-channel reconstruction. |
| `per_source_line_attenuation_stage` | Source-Domain (`0`) | Source-Domain / Post-Display | Selects early current attenuation or later attenuation after colour/contrast/vignette; Per-source-line RGB only. Field-Phase Flicker forces Post-Display while active. |
| `beam_horizontal_spot` | `0.15` | `0–1`, `0.05` | Horizontal spot sigma in output pixels at 1080p; combines with horizontal source smoothing. |
| `beam_current_response` | `0.50` | `0.5–2`, `0.05` | Exponent mapping luminance or per-channel line drive to width response. |
| `beam_average_drive` | `0.15` | `0.1–1`, `0.01` | Average output drive for normalized vertical profiles. |
| `scanline_lines` | `340` | `0–625`, `1` | Manual line frequency; zero selects stock pitch. Ignored in native-pitch mode. |
| `native_scanline_pitch` | `false` | Boolean | Uses DuckStation native raster dimensions for beam pitch, overriding manual frequency. |
| `interlace` | `true` | Boolean | Alternates procedural beam phase on odd/even rendered frames; not true 480i. |
| `scanroll` | `true` | Boolean | Continuous rolling phase using elapsed-time clock. |

Host source uniforms are not user settings: `NativeWidth`, `NativeHeight`, `InternalWidth`, `InternalHeight`, `ViewportOffset`, `ViewportSize`, `FCount` and `timer` are provided by DuckStation/ReShade integration.

### 14.7 CRT Artifacts & Persistence

| Variable | Default | Range / step | Purpose |
|---|---:|---|---|
| `vignette_strength` | `0.8` | `0–1.5`, `0.05` | Edge darkening in CRT scene space. |
| `vignette_mapping` | Symmetric Viewport (`1`) | Legacy Fit / Symmetric Viewport | Selects active-viewport-normalized coordinates or fitted legacy coordinates. |
| `flicker_amount` | `0.003` | `0–0.03`, `0.001` | Final small time/vertical-position modulation. |
| `fringe_amount` | `0.15` | `0–3`, `0.05` | Per-channel sampling offset magnitude. |
| `acc_modulate` | `0.0` | `0–0.99`, `0.01` | Retained fraction of prior frame's brighter channel values. |
| `history_reset` | `false` | Boolean | Clears temporal history while enabled; first frame is also cleared automatically. |
| `interference_strength` | `0.0` | `0–2`, `0.01` | Animated horizontal wobble amplitude. |
| `interference_speed` | `1.0` | `0–3`, `0.05` | Wobble rate multiplier. |

### 14.8 Noise & Grain

| Variable | Default | Range / items | Purpose |
|---|---:|---|---|
| `noise_amount` | `0.06` | `0–0.10`, `0.001` | Overall animated grain amplitude. |
| `noise_luminance_adaptation` | `0.15` | `0–1`, `0.05` | Blends uniform grain with squared-luminance amplitude. |
| `headroom_aware_grain` | `false` | Boolean | Symmetrically bounds the actual per-channel grain excursion by available black/white headroom. |
| `noise_chroma` | `0.71` | `0–1`, `0.01` | Shared monochrome to independent-RGB noise blend. |
| `noise_animation_speed` | `1.0` | `0–1`, `0.05` | Temporal grain evolution rate. |
| `noise_grain_size` | `1.0` | `1–4`, `0.05` | Fine cell size to coarser interpolated grain. |
| `noise_alignment` | Output Pixels (`0`) | Output / Native / Mixed | Grain coordinate grid. |
| `noise_detail_protection` | `0.50` | `0–1`, `0.05` | Grain reduction using source-filter detail confidence. |
| `noise_color_awareness` | `0.25` | `0–1`, `0.05` | Image-saturation adaptation of chromatic grain. |

### 14.9 Glow & Ghosting

| Variable | Default | Range / step | Purpose |
|---|---:|---|---|
| `blur_x` | `0.5` | `0–5`, `0.25` | Horizontal source ghost and post-CRT halation blur radius. |
| `blur_y` | `0.5` | `0–5`, `0.25` | Vertical source ghost and post-CRT halation blur radius. |
| `ghost_strength` | `0.6` | `0–3`, `0.05` | Colour-separated source-blur contribution. |
| `halation_strength` | `0.15` | `0–2`, `0.05` | Post-emission optical glow; near zero skips halation sampling. |
| `halation_respects_scanlines` | `false` | Boolean | Off allows glow into gaps; on reapplies local scanline factor. |
| `halation_threshold` | `0.8` | `0–0.99`, `0.01` | Completed CRT-scene linear luminance bright-pass threshold. |
| `halation_warmth` | `0.3` | `0–1`, `0.05` | White-to-warm-amber glow tint. |

### 14.10 Bloom

| Variable | Default | Range / step | Purpose |
|---|---:|---|---|
| `bloom_intensity` | `0.15` | `0–2`, `0.05` | Final wide bloom contribution; exactly zero bypasses extraction/blur work and final sampling. |
| `bloom_threshold` | `4.0` | `0.25–8`, `0.05` | Peak RGB threshold in linear scene values. |
| `bloom_soft_knee` | `0.15` | `0–1`, `0.05` | Quadratic soft transition around the threshold. |
| `bloom_radius` | `8.0` | `4–64`, `1` | Approximate blur reach in full-output pixels at 1080p. |

### 14.11 Custom phosphor masks

These values are used when the corresponding explicit mask is selected. With `Use Display Profile Default`, built-in mask constants are used instead.

**Aperture Grille (Custom)**

| Variable | Default | Range / step | Purpose |
|---|---:|---|---|
| `aperture_custom_strength` | `0.24` | `0–0.5`, `0.001` | Mask transmission blend. |
| `aperture_custom_pitch` | `3.0` | `1.5–12`, `0.25` | RGB triad pitch at 1080p reference. Aperture has a separate 3-pixel minimum at output resolution. |
| `aperture_custom_stripe_width` | `0.95` | `0.5–1`, `0.01` | Smoothed emitting stripe width. |
| `aperture_custom_gap` | `0.10` | `0–0.5`, `0.01` | Minimum inter-stripe gap. |
| `aperture_custom_damper_wires` | `false` | Boolean | Enables two viewport-relative, pixel-integrated wires. |
| `aperture_custom_wire_strength` | `0.05` | `0–0.2`, `0.001` | Wire attenuation. |

**Slot Mask (Custom)**

| Variable | Default | Range / step | Purpose |
|---|---:|---|---|
| `slot_custom_strength` | `0.4` | `0–0.5`, `0.001` | Mask transmission blend. |
| `slot_custom_pitch` | `4.0` | `1.5–12`, `0.25` | RGB triad pitch at 1080p reference. |
| `slot_custom_stripe_width` | `0.6` | `0.5–1`, `0.01` | Horizontal slot width. |
| `slot_custom_gap` | `0.5` | `0–0.5`, `0.01` | Inter-slot gap. |
| `slot_custom_height` | `1.0` | `0.25–1`, `0.01` | Vertical slot height relative to row pitch. |

**Shadow Mask (Custom)**

| Variable | Default | Range / step | Purpose |
|---|---:|---|---|
| `shadow_custom_strength` | `0.24` | `0–0.5`, `0.001` | Mask transmission blend. |
| `shadow_custom_pitch` | `3.0` | `1.5–12`, `0.25` | RGB triad pitch at 1080p reference. |
| `shadow_custom_dot_width` | `0.95` | `0.5–1`, `0.01` | Horizontal dot width. |
| `shadow_custom_gap` | `0.10` | `0–0.5`, `0.01` | Dot gap. |

### 14.12 Experimental

| Variable | Default | Purpose |
|---|---:|---|
| `field_phase_flicker` | `false` | Enables the full Scanlines & Beam override described in §7.8. |
| `field_phase_flicker_help` | `0` | Persistent explanatory legend directly below the toggle. Its `ui_text` repeats the toggle tooltip. |

### 14.13 Diagnostics

`debug_view` options:

0. Off.
1. Accumulated frame (linear).
2. Current input (encoded).
3. Trail only (linear ×4).
4. Counter and toggle test.
5. Mask only.
6. CRT scene (before bloom).
7. Bloom blur (×4).
8. Bloom extract (×4).

Debug paths intentionally bypass parts of normal final projection/processing. They inspect intermediate buffers, not the normal final image. Bloom debug views 7/8 intentionally keep the bloom extraction/blur paths available when Bloom Intensity is zero.

## 15. Limitations and known caveats

These are accurate boundaries of the current shader, not automatic defects that must all be fixed.

### 15.1 SDR-oriented colour path

- Input is clamped to normalized SDR values before the EOTF approximation.
- The accumulation stage applies a retained `1.25` gain.
- Final output is clamped with `saturate()`.
- The shader is not HDR-safe.
- Output transfer/backbuffer sRGB interpretation depends on DuckStation/ReShade/backend behaviour and requires runtime verification; no unconditional output OETF is applied.

### 15.2 No complete analog video model

The shader processes DuckStation's post-render image. It does not encode/decode composite, S-Video, component, RGB, RF, NTSC or PAL, and does not implement their full bandwidth limits, chroma/luma crosstalk, subcarrier phase, dot crawl, cross-colour, colour bleed or time-base errors.

### 15.3 No true 480i field reconstruction

`Alternating Field Phase` adds a π phase shift to the procedural scanline/beam pattern on alternating rendered frames. It receives no separate odd/even field buffers, field timestamps or missing-line data. `Field-Phase Flicker` makes this pattern alternate between two phases separated by half a scanline period on successive rendered frames. It forces Gaussian Per-source-line RGB and disables Rolling Scanlines, so the neighbouring source-line beam weights are redistributed at the rendered-frame rate. This produces an intentionally strong CRT-like flicker that can look like a very fast top-to-bottom movement, but the complete pattern changes phase globally rather than simulating a physical beam sweep. It is not true 480i or deinterlacing. The rapid flashing may cause eye strain or dizziness for some viewers, which is why the toggle remains off by default. See §7.8 for the calculation and timing details.

### 15.4 Simplified temporal behaviour

- Persistence is `max(current, history * factor)` per channel, not exponential phosphor decay.
- Alternating phase uses rendered-frame parity, while continuous animation uses elapsed time.
- Flicker is a small mathematical modulation.
- Grain is a deterministic hash-noise process with temporal interpolation.
- There are no independently measured RGB phosphor decay constants or true field-rate motion differences.

### 15.5 Approximate beam reconstruction

- Gaussian, Super-Gaussian and Lorentzian are selected mathematical spot profiles, not measured tube spot functions.
- Shared Beam derives one width from source luminance.
- Per-source-line RGB independently samples source lines and channel drives, but it is still a bounded post-process approximation, not an electron-gun/deflection-yoke simulation.
- Super-Gaussian integration uses bounded 16-point quadrature.
- Lorentzian tails are truncated to finite support for bounded execution.
- Horizontal Core + Tail is a normalized two-component kernel with aesthetic energy/width controls, not measured scatter/spot-energy data.

### 15.6 Approximate phosphor masks

- Aperture Grille integration is exact for its defined one-dimensional smoothed stripe function; pitch and stripe geometry are aesthetic parameters.
- The minimum three-output-pixel Aperture Grille triad period is an anti-aliasing guard, not a physical pitch.
- Slot and Shadow Mask use 8×8 subpixel sampling and generic geometry.
- Slot/Shadow mean-transmission compensation is approximate.
- Damping wires are optional and not universal to every grille tube.

### 15.7 Colour profiles are reference interpretations

- Japanese P22 is an aggregate estimate and not a factory Sony calibration.
- KX-14CP1 uses a separate manually calibrated model reference, not a full device characterisation.
- Toshiba SMPTE-C/D65 and SMPTE-C/D55 are reference/aesthetic interpretations, not measured Toshiba AF/Cinema factory settings.
- BVM-D24 EBU Cool combines nominal EBU primaries with the default cool white character; it is not a factory colour-temperature preset.
- The shader uses BT.709-like working/output coordinates and is not a complete ICC display-management pipeline.

### 15.8 Curvature filtering is not full EWA

Adaptive geometry reconstruction integrates only along the major projected footprint axis and caps sampling at 4 or 8 taps. The minor axis relies on ordinary linear sampling. Strong curvature or two-axis minification can still expose aliasing or blur trade-offs. Bilinear one-tap is the default.

### 15.9 Curvature is a visual projection, not an optical CRT model

There is no glass refraction, lensing, specular reflection, true physical camera calibration, beam deflection correction, bezel or room lighting. The surface is a mathematical depth field projected through a virtual camera.

### 15.10 Halation and Bloom stack

Halation is composited directly and included as a source for Bloom extraction. This intentionally creates local glow plus wider secondary spill. Bloom Intensity zero bypasses its texture sampling and normal extraction/blur work, but quarter-resolution passes are still scheduled and write zero. Halation remains active independently.

### 15.11 Native/internal dimension fallback

When `InternalWidth/Height` is unavailable, source reconstruction falls back to the native grid. When native dimensions are unavailable, the code assumes a 240-line source and square displayed pixels. These fallbacks may not be correct for unusual native modes, high-resolution game output, non-PS1 content or nonstandard aspect arrangements.

### 15.12 Sampling and high-frequency interaction

The source image, mask, scanlines and display reconstruction all contain spatial frequencies. Their combination can produce moiré, aliasing, false colour, uneven mask pitch or busy texture depending on output resolution, internal resolution, viewport, content and geometry. The aperture-grille pitch floor reduces one class of low-resolution aliasing but does not make every mask/scanline combination alias-free.

### 15.13 Runtime and backend verification

Static source review does not prove FX compilation or runtime behaviour. Validate the actual DuckStation build/backend, especially native/internal viewport uniforms, output encoding, geometry derivatives, target initialization, temporal animation, exact zero-intensity branches and GPU cost. Do not claim compilation unless a compatible compiler/loader has actually accepted the file.

## 16. Where the shader excels

The shader is particularly suited to:

- PS1 and similar retro games whose art benefits from gentle phosphor/scanline texture;
- pixel-art scenes with large colour blocks, gradients, lighting and textured backgrounds;
- users who want CRT character without a large bezel, strong curvature or an elaborate analog signal chain;
- users who like selecting a display colour character (cool, balanced, warm, neutral) without replacing the whole effect;
- mild smoothing that softens harsh pixel scaling while retaining the recognisable pixel-art structure;
- optional masks/beam controls for enthusiasts who want to experiment.

It is less suited, without further work, to:

- exact reproduction of a particular physical monitor;
- full composite-video nostalgia or analog capture artifacts;
- strict 480i/480p/240p signal emulation and field timing;
- HDR output;
- extreme curved-screen projection with guaranteed alias-free mask rendering;
- measured phosphor decay, focus, convergence, purity, or beam-current accuracy.

---

## 17. Modification routes — select according to the user's requested outcome

The routes below describe different valid directions the shader can take. They are not ranked, and Route A is not the mandatory or preferred destination for every user. Identify the requested result first. If the request is underspecified, clarify the desired visual target or present the important trade-offs instead of assuming that the current preset must be preserved.

### Route A — Retain or refine the current mild default preset

This route is appropriate when the user specifically wants the existing restrained style or asks for small tuning changes.

- The current baseline is Flat geometry and Sony Trinitron Japanese Cool as the default display profile.
- Possible adjustments include mask strength, scanline strength, Pixel Smoothing, horizontal/vertical source smoothing, vignette, bloom, ghosting, noise and halation.
- Changing one subsystem at a time makes visual comparisons easier, but multiple coordinated changes are valid when requested.
- Avoid changing unrelated controls when performing a narrowly scoped fix.

### Route B — More subtle / cleaner image

Possible adjustments:

- reduce mask strength or enlarge mask pitch;
- reduce scanline strength or soften beam sharpness;
- reduce or disable Pixel Smoothing and source Gaussian smoothing if the image is too soft;
- reduce vignette, bloom, halation and noise;
- choose Balanced Color or Standard/Reference Color if the default cool bias is too strong.

Do not blindly brighten the image before examining whether masks/scanlines are responsible for average-light loss.

### Route C — Stronger or more conspicuous CRT presentation

Possible directions include stronger mask/scanline modulation, more visible halation or bloom, increased ghosting/colour fringing, or more pronounced curvature. These can be separate controls, presets, or integrated into a new baseline depending on the user's request. Stronger is not automatically more historically or physically accurate; describe the intended aesthetic honestly.

### Route D — Display/profile exploration

The current profile system can be extended with named reference profiles. A new profile should document:

- source primaries/white-point assumptions;
- the matrix or chromatic adaptation used;
- target RGB colour space;
- whether the data are measured, literature-derived, or aesthetic;
- mask pairing defaults, if any;
- uncertainty and provenance.

Do not name a profile after a specific product if its transform is only a generic aesthetic interpretation without saying so.

### Route E — Phosphor-mask research

Possible additions include other aperture-grille/slot/shadow layouts, calibrated pitches, different beam/mask interactions, higher-quality 2D coverage integration, and resolution-aware filtering. The current model treats the mask as a physical structure attached to the simulated faceplate, so it is projected with the CRT image. A different requested model may attach the pattern to output pixels, use a hybrid coordinate system, or replace the mask model entirely; explain how that changes its appearance and sampling behaviour.

### Route F — Better beam/scanline model

Possible future upgrades include:

- more accurate pixel-area integration of the vertical spot;
- continuous integration instead of three vertical samples;
- independent horizontal/vertical beam profiles;
- more explicit beam-current response models;
- phase and pitch alignment tests across native resolutions and scaling factors;
- optional static scanline mode that avoids temporal phase animation.

Any improvement must preserve a neutral result when scanline strength is zero and must ensure controls have visible, documented behaviour.

### Route G — Real analog video signal effects

If the user asks for composite/S-Video/NTSC/PAL aesthetics, this is a distinct signal-processing path, not merely stronger mask/noise values. Potential components include:

- RGB-to-YIQ/YUV-like encoding;
- chroma subcarrier modulation and phase;
- luma/chroma bandwidth filtering;
- chroma demodulation and reconstruction;
- dot crawl / cross-colour / chroma bleed;
- signal noise and timebase errors.

These can be optional layers, a new signal-processing path, or the core of a redesigned preset depending on the user's goal. Distinguish a standard-inspired encoder/decoder from an artistic approximation, and explain any changes to colour, bandwidth, latency, performance, and compatibility.

### Route H — Genuine interlaced / 480i processing

Do not try to manufacture field-aware reconstruction solely inside the current shader if DuckStation provides only a progressive post-deinterlaced backbuffer. Investigate emulator output semantics and whether separate fields/parity/timing can be exposed. The current `Alternating Field Phase` checkbox and Experimental `Field-Phase Flicker` mode are procedural phase effects, not substitutes for separate field input or true deinterlacing.

### Route I — Better curvature

Potential options:

- full 2D ellipse-aware/EWA-like reconstruction;
- generated mip chains with deliberate prefiltering;
- adaptive 2D stratified taps;
- more robust Newton convergence/bounds;
- explicit mapping tests for portrait/wide aspect and off-axis cameras;
- more realistic profile shapes if supported by references.

The current default is Flat, but curvature may remain optional or become central to a different requested look. Do not call the current major-axis line filter full EWA.

### Route J — Temporal/physical CRT research

Possible directions include separate RGB phosphor decay, more realistic persistence, time-dependent beam scanning, field-rate output, measured tube response and electrical/optical stages. This is a major increase in complexity. It may be implemented as optional modes or as a substantially redesigned pipeline/branch; choose based on the requested scope and compatibility needs.

---

## 18. Areas worth reconsidering, testing, or improving

These are audit/test targets, not automatically confirmed bugs.

1. **Output transfer/backbuffer encoding:** Verify actual DuckStation backend output interpretation before changing the tone curve or adding an OETF.
2. **Host source dimensions and viewport:** Confirm native/internal dimensions, viewport offset and viewport size on Vulkan and other relevant backends, including letterboxing and high-resolution modes.
3. **Enhanced-resolution reconstruction:** Compare PS1 sprites and 3D geometry at 1×, 2×, 4× and 6× internal resolution. The filter sees only image samples and cannot semantically separate sprites from 3D objects.
4. **Source-cell sampling phase:** Test fractional internal-cell centres, viewport edges, non-integer output scaling and active-viewport boundaries. Do not round internal sample centres to output texel centres.
5. **Adaptive filter:** Compare flat areas, isolated pixels, equal-luminance chromatic boundaries, coherent diagonals, irregular texture and high-contrast edges. Verify detail confidence remains useful with Pixel Smoothing set to zero. Compare Adjacent-Tap Edge Blending on/off in Edge-Aware and Hybrid modes, including source-cell boundaries and enhanced internal resolutions; verify Subpixel Blend mode ignores it.
6. **Horizontal kernel:** Test Gaussian, Super-Gaussian and Lorentzian at the full `Horizontal Source-Pixel Smoothing` and `Horizontal Beam Spot Width` ranges. Compare cell-integrated weights against a high-precision reference, particularly fractional phases and finite Lorentzian support.
7. **Core + Tail:** Check continuity around zero tail energy, 1× tail width and mode toggles; verify the mixture remains energy-normalized and that support bounds include the selected tail across all allowed values.
8. **Vertical source smoothing:** Verify the internal/native scale conversion and the maximum two-native-line support at enhanced resolutions. Confirm Per-source-line RGB does not filter vertically a second time.
9. **Shared Beam integration:** Compare analytic Gaussian/Lorentzian primitives and the Super-Gaussian quadrature against higher-precision integration for all supported sigma/pixel-footprint combinations.
10. **Per-source-line RGB:** Record moving content and stationary images over multiple rendered frames. Inspect channel separation, line support at the ±8 loop bound, edge masks, overlap and normalization. It is particularly important to test both stock/manual/native pitch. Compare the default Source-Domain and optional Post-Display attenuation; inspect how ghosting, mask/profile transforms and scanline depth interact, and confirm Shared Beam/Sine ignore the selector.
11. **Field phase and timer:** Verify 60 FPS-equivalent timing at 30/60/120/240 FPS, rolling phase continuity, odd/even parity and the interaction with the Sine and both Gaussian beam models.
12. **Field-Phase Flicker override:** Change all 18 UI settings before enabling it, while it is active and after disabling it. Confirm effective values are pinned while active, including Gaussian Per-source-line RGB with Post-Display (Shared Beam-aligned) attenuation, manual frequency 340, Rolling Scanlines off and Alternating Field Phase on, even when the normal attenuation selector is Source-Domain. Verify the beam phase alternates by half a line cycle on successive `FCount` parity states, that the global pattern alternates at the rendered-frame rate, and that it is not mistaken for a physical line sweep or true 480i. The prior UI selections—including the user's attenuation-stage selection—must resume unchanged afterward. Verify legend and tooltip remain identical. Compare at multiple capped/uncapped frame rates and inspect frame pacing/refresh interaction.
13. **Scanline master switch:** Confirm all vertical beam/Sine modulation becomes neutral when disabled while the phosphor masks and damping wires remain active.
14. **Aperture grille:** Compare the analytic smooth-stripe integral to high-sample numeric integration across fractional triad pitch, width, gap, viewport offset, edge pixels and the 3-output-pixel period floor.
15. **Low output resolutions:** Test grille and scanline interaction at 480p/720p/1080p/1440p/4K. The triad floor is a perceptual safeguard, not universal alias elimination.
16. **Slot/Shadow coverage:** Compare the 8×8 integrated shape against 16×16/32×32 references at representative widths, gaps, row phases and heights.
17. **Damping wires:** Test subpixel wire positions and viewport offsets against numerical integration. Confirm only Aperture Grille uses them and both built-in/custom defaults remain off.
18. **Colour profiles:** Verify index-to-transform mapping and automatic mask mapping after any UI reorder. Test neutral-axis and negative-gamut compression behaviour, not only primary colours.
19. **Halation A/B:** Compare bright highlights crossing scanline gaps. Check `Halation Strength = 0`, zero blur axes and the post-emission bright-pass source.
20. **Vignette mapping:** Compare Symmetric Viewport (default) and Legacy Fit at different viewport offsets/sizes, letterboxed output and all four corners. Confirm the default follows the active image rectangle and Legacy Fit preserves its original mapping.
21. **Headroom-aware grain:** Test near-black, near-white and midtone patches with fixed grain fields in Output, Native and Mixed alignment, mono/RGB chroma, different Grain Sizes and temporal blending. Confirm symmetric excursions stay within `[0,1]` and that Off preserves the prior path.
22. **Bloom zero path:** Check Bloom Intensity exactly 0 and >0, including debug views 7/8. The three quarter-resolution passes remain scheduled at zero even though their normal sampling and blur paths early-out.
23. **Ghosting/blur:** Test Ghost Strength 0, each blur axis 0, paired bilinear cases and edge fallback. Keep source ghost buffers and halation reuse order intact.
24. **Temporal state:** Test resize, shader reload, reset, pause/resume, changing resolution, history reset and re-entry after UI changes. The shader cannot identify every arbitrary finite uninitialized history value.
25. **Geometry:** Test all curved profiles, camera offsets, corner radius and adaptive reconstruction at strong settings. The current filter is major-axis-only; do not claim full EWA.
26. **GPU cost:** Measure frame time on the target GPU. Texture-fetch counts alone are not a reliable performance estimate. The internal-grid adaptive analysis and per-source-line beam can be more expensive at high internal/output resolutions.
27. **Documentation/UI parity:** Verify every visible label, default, range, tooltip, info legend and effective code path against the current `.fx` declarations.

## 19. Recommended validation workflow

For every meaningful shader change:

1. **Diff review:** Compare the patch against the exact prior baseline. Verify no unrelated defaults or systems changed.
2. **Static inspection:** Check declarations, types, shader function dependencies, coordinate conventions, pass ordering, target reads/writes, alpha semantics and UI wiring.
3. **Mathematical checks:** For new filters or geometry, compare to a CPU/high-precision reference where practical. Test endpoints and transition regions, not just default values.
4. **Compile:** Compile with the actual ReShade FX compiler/toolchain used by DuckStation. Record backend, shader model and compiler output. Do not rely only on general HLSL validity.
5. **Runtime test:** Run in DuckStation. At minimum test Flat/default, each display profile, each mask, scanline strength 0 and default, halation A/B, bloom on/off, and a curved profile if geometry changed.
6. **Resolution test:** Compare at least 1080p and 4K if the user uses both. Also test one lower resolution if mask pitch or sampling changed.
7. **Temporal test:** Record multiple frames for scanroll, alternating phase, flicker, grain animation, persistence and scene motion.
8. **Screenshot test:** Use identical game state, frame, scaling, display profile and output resolution for before/after comparisons.
9. **Performance test:** Measure actual frame time/GPU usage; count texture fetches only as an estimate.
10. **Documentation:** Update README for user-facing behaviour and this AGENTS file for architecture/implementation changes.

### Suggested focused test matrix

| Test | What it verifies |
|---|---|
| Flat, default Sony profile, SotN gameplay | Intended default visual character. |
| Same scene, shader disabled | Establishes what the shader actually changes. |
| Standard/Reference Color | Profile bypass and colour differences. |
| Sony Balanced vs Japanese Cool | P22 white-point effect. |
| Toshiba AF Warm Cinema vs Toshiba AF Balanced Color | D55-style warm vs D65 balanced reference interpretation. |
| Aperture / Slot / Shadow / None | Mask pattern, mean transmission and colour response. |
| Scanline strength = 0 | Neutral/off behaviour for both scanline profiles. |
| Scanline strength = 1 in Sine mode | Legacy waveform compatibility point. |
| Native scanline pitch with a known game resolution | Semantic pitch mapping. |
| Halation A vs B | Glow spill into gaps vs scanline-modulated glow. |
| Halation plus bloom at strong settings | Layered local and wide glow balance. |
| Ghost strength 0 / blur_x/y 0 | Early-outs and shared blur-radius edge cases. |
| Grain Output / Native / Mixed under curvature | Correct grid anchoring and mapping. |
| Screen corner radius on 16:9, 4:3, portrait | SDF aspect/units and edge AA. |
| Curvature at strong settings with mask | Major/minor axis minification and aliasing. |
| Resize/reload/history reset | Persistent target lifecycle. |

---

## 20. Code navigation map

Line numbers move. Use function names and the following map; verify the current source before editing.

| Region / function | Responsibility |
|---|---|
| Header and uniform declarations | UI, defaults, DuckStation source bindings and experimental override macros. |
| `animation_frame_clock()` | Convert DuckStation timer milliseconds into a 60 Hz-equivalent continuous clock. |
| `decode_crt_eotf()` | Input BT.1886-style EOTF approximation. |
| `PrevColor()`, `PS_AccumulateFrame()` | Current-frame accumulation, history validation, first-frame/manual reset and bright-trail retention. |
| `SampleAccumFrameLinear()` | Linear-light source sampling and horizontal-edge validity. |
| `PS_GaussianBlurHorizontal/Vertical()` | Pre-CRT separable Gaussian source blur used for ghosting. |
| `edge_mask()` | Scene-sample validity/edge feather. |
| `beam_profile_value()` and `beam_profile_integral()` | Gaussian, Super-Gaussian and Lorentzian spot shapes and integrals. |
| `beam_profile_pixel_average()` | Periodic beam integration over an output-pixel footprint. |
| `beam_profile_source_line_*()` | Bounded per-source-line beam support, integration and area normalization. |
| `source_native_pixel_size_px()` | Native raster cell dimensions in output pixels. |
| `source_reconstruction_pixel_size_px()` | Internal render-grid cell dimensions when available. |
| `source_reconstruction_scale_from_native()` | Convert native pixel/line controls into internal-grid units. |
| `source_viewport_offset_px()`, `source_viewport_size_px()` | Active source viewport bounds. |
| `sample_accum_source_cell()` | Sample an internal/native source-cell centre without integer-output rounding. |
| `source_sqrt_rgb()`, `source_colour_distance_sqrt()` | Comparison-space transform and YCoCg-like local difference. |
| `source_edge_frame()` | Four-quadrant structure tensor, edge normal and coherence/activity. |
| `source_edge_neighbour_weight()`, `source_edge_aware_pixel_blend()` | Full 3×3 anisotropic bilateral Pixel Smoothing blend. |
| `source_edge_frame_two_columns()`, `source_edge_aware_adjacent_pixel_blend()` | Cached two-column tensor and optional adjacent horizontal-tap blend. |
| `source_normal_cdf()`, `source_super_gaussian_integral()` | Area integrals for source-cell horizontal reconstruction. |
| `source_profile_cell_weight*()` | Per-cell profile integration, per-channel weights and Core + Tail mixture. |
| `PS_SmoothH()`, `PS_SmoothV()` | Horizontal internal-grid reconstruction and vertical source smoothing; alpha carries detail confidence. |
| `active_phosphor_mask_type()` | Automatic/explicit mask selection. |
| `evaluate_phosphor_mask_sample()` | Slot/Shadow 2D shape evaluation. |
| `aperture_grille_*()` | Analytic smoothed stripe/triad integrals. |
| `build_phosphor_mask()` | Select built-in/custom mask values, pitch safeguards, integration and mean compensation. |
| `damper_wire_*()` | Pixel-integrated viewport-relative aperture-grille damping wires. |
| `apply_display_color_profile()` | Seven display-profile transforms and gamut handling. |
| `filmic_luminance()`, `filmic()` | Black-coordinated luminance tone curve. |
| `screen_fit_uv()` | Retained aspect/framing transform. |
| `hash_noise_*()`, `spatial_grain_value()` | Deterministic spatial grain field, scale and variance normalization. |
| `animated_grain_value()` | Elapsed-time grain interpolation. |
| `grain_native_pixel_uv_size()`, `grain_source_uv()` | Native grain scale and inverse scene mapping. |
| `grain_detail_factor()`, `aligned_grain_value()` | Detail protection and output/native/mixed grain alignment. |
| `PS_RenderCRTScene()` | Main CRT scene generation, per-source-line beam reconstruction, shared/Sine beam, ghosting, mask/profile and scanline alpha. |
| `halation_brightpass()`, `PS_HalationBlurHorizontal/Vertical()` | Post-emission halation extraction and blur. |
| `halation_contribution()` | Halation strength, tint and optional scanline reapplication. |
| `extract_bloom_highlights()`, `PS_ExtractBloom()` | Hue-preserving soft-knee bloom extraction and 4×4 downsample. |
| `PS_BloomBlurHorizontal/Vertical()` | Quarter-resolution bloom Gaussian blur and zero-intensity early-outs. |
| `crt_surface_sag_gradient()` | Geometry-profile surface sag and analytic gradient. |
| `project_crt_surface()` | Virtual-camera ray/height-field intersection. |
| `crt_surface_coverage()` | Rounded faceplate boundary and anti-aliasing. |
| `sample_crt_surface()` | Bilinear or bounded major-axis reconstruction with coverage/scanline metadata. |
| `apply_selective_warm_desaturation()` | Locked warm-hue trim after tone mapping. |
| `PS_CompositeBloom()` | Projection, halation, bloom, tone mapping, grain, flicker and SDR output. |
| `technique CRT_Trinity` | Authoritative 13-pass ordering. |

## 21. Credits, game references and provenance

The shader is based on or informed by the following work and projects. These links are included for attribution and for future technical review of the upstream implementations:

- **Mattias Gustavsson** — creator of the original NewPixie CRT. [GitHub profile](https://github.com/mattiasgustavsson) · [DuckStation upstream `CRT-NewPixie.fx`](https://github.com/stenzek/duckstation/blob/master/data/resources/shaders/reshade/Shaders/CRT-NewPixie.fx)
- **hunterk** — adapted NewPixie CRT to the Slang shader format. [libretro/slang-shaders — NewPixie](https://github.com/libretro/slang-shaders/tree/master/crt/shaders/newpixie)
- **Albatross (`Far_Albatross_8821`)** — author of the `CRT-NewPixie_Albatross` ReShade modification. Their Reddit post describes converting the vanilla code from Slang to HLSL and adding customization/variants. This credits their published modification and stated conversion work; it does **not** claim that they authored the first DuckStation `CRT-NewPixie.fx` conversion. The DuckStation ReShade FX file was already present by 16 June 2024: a commit by Hyllian modified its frame/aspect-ratio handling. That commit confirms the file predates Albatross's 2025 post, but it does not identify the author of the original FX conversion. [Reddit post](https://www.reddit.com/r/duckstation/comments/1kx2ikc/crtnewpixie_albatross_what_a_lame_name_but/) · [Shared shader files](https://drive.google.com/drive/folders/1DgvTyrDYCCzCMyUFI46krn34d7IePbd2) · [Hyllian's 16 June 2024 DuckStation change](https://github.com/stenzek/duckstation/commit/2a90a8805509a77e1e19bd0b6a0dc4e4e3c380fe)
- **DuckStation** (`stenzek/duckstation`) — ReShade FX support, the upstream `CRT-NewPixie.fx` distribution and host integration. [GitHub repository](https://github.com/stenzek/duckstation)

The primary game reference is **Castlevania: Symphony of the Night (PlayStation)**. **Metal Gear Solid 1 (PlayStation)** is another visual reference. Two community development projects provide relevant technical and variant context:

- **Castlevania: Symphony of the Night Decompilation** — <https://github.com/Xeeynamo/sotn-decomp>. Xeeynamo's decompilation project for the PlayStation game and related game variants.
- **Castlevania: Symphony of the Night Ultimate (SOTN Ultimate)** — <https://github.com/renanbianchi/sotn-ultimate>. A fork of the decompilation project that combines the PS1 release with selected content/features from Saturn and PSP releases.

These game projects are independent references and are not shader dependencies. CRT-Trinity does not include their game code or assets.

The display profiles, masks, beam reconstruction, source filtering, grain protection, geometry, optical effects, UI and saved defaults are project-specific work developed with AI-assisted research, implementation and iterative technical review. Keep original upstream attribution and applicable license notices intact when editing or redistributing the shader.

## 22. Final handoff summary

The simplest accurate description is:

> CRT-Trinity is a highly customizable Sony Trinitron-inspired CRT post-processing ReShade FX shader for DuckStation, built on Mattias Gustavsson's NewPixie CRT. Its overall design and rendering approach are based on selected characteristics of the Sony Trinitron aperture-grille CRT family, particularly its construction and operating behaviour, with a Japanese P22-inspired default. Its mild default presentation uses the Sony Trinitron — Japanese Cool profile, Flat geometry and an aperture-grille mask. Source reconstruction, beam/scanline models, phosphor structure, temporal behaviour, grain/noise, ghosting, halation, bloom, vignette and optional curvature are all tuned as parts of this single Trinitron-oriented presentation. Additional display profiles are colour/white-point and automatic-mask customization options, not separate complete television simulations. The shader uses screen-space approximations rather than physically simulating cathodes, electron trajectories, deflection hardware or phosphor chemistry. Its defaults are the author's preferred visual settings rather than measured calibration. Ordinary users are advised to begin with defaults and change a small number of high-level settings; more specialized beam, mask, reconstruction and geometry controls are for users who understand their interactions.

Treat this document as the technical handoff to future AI assistants and developers. It explains what the shader currently computes, what its approximations mean, which data contracts its passes rely on, where controls take effect, and what it does not attempt to simulate. The exact `CRT-Trinity.fx` source remains authoritative. The shader is one unified implementation and should not be documented as a changelog or a collection of version-specific feature batches.
