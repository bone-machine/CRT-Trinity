# CRT-Trinity

CRT-Trinity is a **highly user-configurable Sony Trinitron-inspired CRT post-processing ReShade FX shader for DuckStation**, distributed as a single `.fx` file. It builds on Mattias Gustavsson’s NewPixie CRT, with related adaptations credited below.

The shader's overall design is based on selected characteristics of the **Sony Trinitron aperture-grille CRT family**, particularly its construction and operating behaviour, with a Japanese P22-inspired default. These ideas guide the phosphor structure, beam and scanline behaviour, and the overall display treatment. The shader recreates them through real-time screen-space approximations, not a complete physical simulation. Finishing effects such as grain, ghosting and bloom are aesthetic additions, not measured traits of every Trinitron.

This development version keeps the cool, slightly blue-ish Japanese P22-inspired base, but deliberately enables several new experimental paths for visual comparison. Their values are provisional working defaults, not a settled release preset or measured calibration. Switch the legacy modes described below to compare against the earlier processing. Change anything you like; the picture should be yours.

I mainly tuned the look while playing *Castlevania: Symphony of the Night* and *Metal Gear Solid* on PlayStation. **It's ready to use with [Castlevania: Symphony of the Night Ultimate](https://github.com/renanbianchi/sotn-ultimate).** The related [SotN decompilation project](https://github.com/Xeeynamo/sotn-decomp) is also a useful reference. These are separate projects, not shader dependencies; CRT-Trinity does not include or distribute any game files, game code or game assets.

## Key Rendering Features

- **Internal-resolution-aware reconstruction** — uses DuckStation's enhanced internal grid while keeping CRT raster pitch tied to native game dimensions.
- **Subpixel Blend reconstruction (default)**, with optional **Edge-Aware** and **Hybrid** modes.
- **Gaussian Beam scanlines and Gaussian spot kernel by default**, integrated over output-pixel footprints.
- **Luminance-preserving highlight gamut compression** and a selectable legacy hue-preserving path.
- **Center-normalized symmetric vignette** by default, with the former centre-gain response retained as an alternative.
- **Shared Beam and Per-source-line RGB** vertical beam models, with selectable Per-source-line RGB attenuation placement.
- **Integrated horizontal spot reconstruction** — the default is a Gaussian Single Lobe spot.
- **Phosphor masks** — Aperture Grille, Slot Mask and Staggered Shadow Mask, with optional aperture-grille damping wires.
- **Temporal bright-trail persistence** — previous-frame highlights can be retained; this is not conventional motion blur or calibrated phosphor decay.
- **RGB-preserving extended halation** with its own spread control, plus multi-pass bloom.
- **Hybrid noise by default:** subtle native-cell signal noise is shaped by beam/scanline and mask processing, while the existing post-tone-map grain remains available as a separate finishing layer.
- **Rate-stable alternating field phase** and elapsed-time rolling scanlines, with a visible motion/comfort note.

See `AGENTS.md` for the detailed mathematics, pass graph, resource handling, diagnostics and implementation notes.

## Display Color Profiles

The profile choices are grouped around a few different color characters rather than separate full television emulations:

- **Sony Trinitron** profiles use a P22-inspired color reference. **Japanese Cool** is the default, with the cooler, slightly blue-ish look; the other Sony options provide more balanced or monitor-oriented interpretations. Their automatic mask is **Aperture Grille**.
- **Toshiba AF** profiles use an SMPTE-C reference: one balanced around D65 and one warmer, D55-style option. Their automatic mask is **Slot Mask**.
- **Neutral — Standard** bypasses the display-profile color transform and uses the **Aperture Grille** automatic mask. It is neutral only with respect to that transform; the rest of CRT-Trinity still applies.

These are reference color/white-point interpretations, not measured factory calibrations. With **Use Display Profile Default**, the shader selects the mask pairing described above. Choosing an explicit mask changes only the mask, not the display color profile.

## UI Guide

The shader exposes the following controls in DuckStation. The current defaults intentionally enable several experimental paths for comparison; use the legacy choices described below to restore their earlier behavior.

### Display Setup

- **Display Color Profile** — selects the color/white-point interpretation described above.
- **Phosphor Mask Type** — chooses the profile's automatic mask, an explicit Aperture Grille, Slot Mask or Staggered Shadow Mask, or no mask. Selecting a mask here makes its matching group under **Phosphor Mask Settings** active for customization. The color profile is left unchanged.

### Image & Color

- **Brightness**, **Contrast Curve**, **Saturation**, **Gamma** and **Black Level** — adjust overall level, tonal response, color intensity, display-gamma approximation and input black reference.
- **Highlight Gamut Handling** — Luminance-Preserving (default) compresses saturated highlights toward neutral when needed to fit SDR range while retaining mapped luminance; Hue-Preserving (Legacy) retains channel ratios but can reduce highlight luminance.
- **Warm Hue Desaturation** and **Warm Desaturation Amount** — toggle and tune the existing red-centred saturation trim; defaults On and `0.4`.
- **Vignette Strength** — edge-darkening amount; default `0.5`.
- **Vignette Mapping** — Symmetric Viewport (default) evaluates the falloff against the active image rectangle; Legacy Fit preserves the previous framing.
- **Vignette Normalization** — Center-Normalized (default) holds the image-centre multiplier at `1.0`; Legacy Center Gain restores the earlier centre-brightening response.
- **Color Fringing** — adjusts the small offsets between red, green and blue source sampling positions.
- **Edge Zoom** — enlarges the image within the active viewport.

### Source Image Filtering

- **Pixel Smoothing Mode** — Subpixel Blend (default), Edge-Aware or Hybrid reconstruction.
- **Pixel Smoothing** — strength of the selected reconstruction; `0` disables it.
- **Horizontal Source-Pixel Smoothing** and **Vertical Source-Pixel Smoothing** — add horizontal and vertical Gaussian reconstruction width before CRT beam treatment.

Subpixel Blend averages source reconstruction at small, symmetric half-offset positions on both axes. Edge-Aware uses a 3×3 neighbourhood to adapt filtering around coherent edges. Hybrid combines the two approaches.

### Screen Geometry

- **CRT Surface Profile** — Flat, Cylindrical, Spherical or Aspherical projection. Aspherical uses a predefined faceplate shape.
- **Surface Radius** — curvature for Cylindrical and Spherical profiles.
- **Virtual Camera Distance**, **Virtual Camera Horizontal Offset** and **Virtual Camera Vertical Offset** — adjust perspective and viewing position on curved profiles.
- **Geometry Reconstruction** — Bilinear (1 tap), Adaptive up to 4 taps or Adaptive up to 8 taps.

### Scanlines & Beam

The active beam defaults are **Gaussian Beam** scanlines, a **Gaussian** spot kernel and a **Single Lobe** horizontal spot.

- **Scanline Strength** — overall scanline modulation. Set it to `0` to disable vertical beam modulation; phosphor masks and damping wires remain active.
- **Vertical Beam Model** — Shared Beam or Per-source-line RGB.
- **Per-source-line RGB Attenuation** — Source-Domain (default) or Post-Display (Shared Beam-aligned). Only affects Per-source-line RGB; Field-Phase Flicker temporarily forces Post-Display.
- **Vertical Beam Sharpness** and **Scanline Beam Widening** — shape the Gaussian beam and its brightness-dependent widening.
- **Beam Current Response** and **Beam Average Drive** — control drive-to-width response and average beam output.
- **Horizontal Beam Spot Width** — adds Gaussian spot width to source reconstruction.
- **Manual Scanline Density** — sets the spatial density of the beam pattern; the default is `340`. `0` uses the original NewPixie pitch, which varies with output resolution. This is unrelated to your monitor's refresh rate.
- **Match Scanlines to Native Resolution** — derives spacing from DuckStation's native game raster, not enhanced internal resolution or monitor refresh rate. It overrides Manual Scanline Density when valid native dimensions are available.
- **Alternating Field Phase**, **Field Phase Timing**, **Field Phase Reference Rate** and **Rolling Scanlines** — control scanline phase behaviour over time. **Rate-Stable Elapsed Time** uses a selectable **60 Hz** reference (30 Hz two-state cycle, default) or **PAL 50 Hz** reference (25 Hz cycle); **Legacy Frame Counter** alternates on successive rendered frames. The reference-rate selector affects Alternating Field Phase only; Rolling Scanlines retains its own elapsed-time rate. This is not true 480i field reconstruction. Both effects are enabled by default, and their combined motion can produce visible flicker that may cause eye strain or dizziness in sensitive viewers; disable either or both if uncomfortable.

### Noise & Grain

- **Noise Placement** — Hybrid (Both, default), Post-Tone-Map Grain or Pre-Beam Signal Noise.
- **Post-Tone-Map Grain Amount** — intensity of the existing finishing grain, added after tone mapping.
- **Pre-Beam Signal Noise Amount** — intensity of the new linear-light noise added after source reconstruction and before beam, scanline and phosphor-mask processing; default `0.018`.
- **Signal Noise Chroma** — blends shared monochrome noise toward independent RGB noise; default `0.25`.
- **Signal Noise Line Correlation** — adds a component shared along native raster lines; default `0.25`.
- **Luminance Adaptation** — changes finishing-grain strength with image brightness.
- **Grain Animation Speed** — controls finishing-grain temporal evolution; `0` freezes it.
- **Grain Size** — controls finishing-grain spatial scale.
- **Grain Alignment** — Output Pixels, Native Game Pixels or Mixed for the finishing-grain layer.

### Signal & Temporal Effects

- **Temporal Trail Persistence** — controls retention of previous-frame highlights; `0` disables trails.
- **Reset History** — clears accumulated temporal history; useful after a target resize.
- **Interference Strength** and **Interference Speed** — control animated horizontal signal wobble.

### Glow & Ghosting

- **Horizontal Blur** and **Vertical Blur** — set the source blur used by ghosting. Halation uses these as base radii, scaled separately by Halation Spread.
- **Ghost Strength** — controls the ghost image contribution.
- **Halation Extraction** — RGB-Preserving + Extended (default) retains highlight color and lets highlights above linear 1.0 contribute; RGB-Preserving omits the extended response; Normalized Luminance (Legacy) restores the scalar white/amber extraction.
- **Extended Highlight Gain** — controls the additional logarithmic glow response above linear luminance 1.0; default `0.35`.
- **Halation Spread** — scales the glow blur independently of ghosting; default `1.25`.
- **Halation Strength**, **Halation Threshold** and **Halation Warmth** — control glow intensity, cutoff and tint.
- **Halation Respects Scanlines** — determines whether halation is attenuated by the scanline pattern or spreads into its gaps.

### Bloom

- **Bloom Intensity**, **Bloom Threshold**, **Bloom Soft Knee** and **Bloom Radius (pixels at 1080p)** — control wide highlight spill, its cutoff/transition and blur reach. Bloom stacks with Halation. Setting Bloom Intensity to `0` disables its normal sampling and blur work, though its three passes remain scheduled.

### Phosphor Mask Settings

To customize a phosphor mask, select Aperture Grille, Slot Mask or Staggered Shadow Mask under **Display Setup → Phosphor Mask Type**. Use **Use Display Profile Default** to retain the selected profile's predefined mask and settings. Only the group corresponding to an explicitly selected mask affects rendering.

**Aperture Grille** — **Mask Strength (Custom)**, **Triad Pitch (pixels at 1080p)**, **Stripe / Aperture Width**, **Inter-Stripe Gap**, **Show Grille Damping Wires** and **Damping Wire Strength**.

**Slot Mask** — **Mask Strength (Custom)**, **Triad Pitch (pixels at 1080p)**, **Slot Width**, **Inter-Slot Gap** and **Slot Height**.

**Staggered Shadow Mask** — **Mask Strength (Custom)**, **Triad Pitch (pixels at 1080p)**, **Dot Width** and **Dot Gap**.

### Experimental

- **Field-Phase Flicker (off by default)** — forces Per-source-line RGB and alternating half-period beam phases for a pronounced CRT-like flicker. It uses the selected Field Phase Timing and Field Phase Reference Rate settings. It may cause eye strain or dizziness; use it at your discretion.

### Diagnostics

**Debug View** provides 21 inspection modes for examining source inputs and reconstruction, temporal history, beam attenuation, phosphor-mask and damping-wire output, surface coverage, and intermediate halation/bloom stages. Some views force intermediate work even when the corresponding effect is disabled; set Debug View to **Off** to restore normal rendering.

## Installation

Copy `CRT-Trinity.fx` into DuckStation's `shaders/reshade/Shaders/` directory and select it in DuckStation's ReShade FX post-processing options. **This shader is written for DuckStation's host-provided source information**, including native/internal render dimensions and active-viewport mapping. Other ReShade hosts may not provide the same uniforms or semantics, so correct operation outside DuckStation is not guaranteed. The shader is distributed as one `.fx` file.

## Credits

- **Mattias Gustavsson** — original NewPixie CRT. [GitHub](https://github.com/mattiasgustavsson) · [DuckStation upstream FX](https://github.com/stenzek/duckstation/blob/master/data/resources/shaders/reshade/Shaders/CRT-NewPixie.fx)
- **hunterk** — NewPixie's Slang adaptation. [Source](https://github.com/libretro/slang-shaders/tree/master/crt/shaders/newpixie)
- **Albatross** — `CRT-NewPixie_Albatross` ReShade modification and its published HLSL-conversion work. [Reddit post](https://www.reddit.com/r/duckstation/comments/1kx2ikc/crtnewpixie_albatross_what_a_lame_name_but/) · [Shared files](https://drive.google.com/drive/folders/1DgvTyrDYCCzCMyUFI46krn34d7IePbd2)
- **DuckStation** — ReShade FX host support and upstream shader distribution. [Repository](https://github.com/stenzek/duckstation)

## License

CRT-Trinity's custom reconstruction, beam, mask, color-profile, geometry, grain, temporal and optical-effect implementations and saved defaults are project-specific work by bone-machine, developed with AI assistance. Distributed under the MIT License; see `LICENSE`.
