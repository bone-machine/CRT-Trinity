# CRT-Trinity

CRT-Trinity is a **highly user-configurable Sony Trinitron-inspired CRT post-processing ReShade FX shader for DuckStation**, distributed as a single `.fx` file. It builds on Mattias Gustavsson’s NewPixie CRT, with related adaptations credited below.

The shader's overall design draws on selected characteristics of the **Sony Trinitron aperture-grille CRT family**, particularly its phosphor structure and beam/scanline behaviour. The Japanese P22-inspired configuration is the primary reference, but the shader does not attempt to model any particular television in full.

The default preset represents the author's preferred presentation: a cool, slightly blue-toned CRT-inspired image treatment on a geometrically flat LCD presentation. Flat is the clean geometry reference; LCD Focus is an optional, subtle horizontal composition warp, while the original cylindrical and other virtual CRT faceplate profiles remain available. Grain, ghosting and bloom are optional aesthetic choices rather than universal properties of CRT displays. The settings remain adjustable; the defaults are a starting point, not a calibration target.

Visual tuning focused primarily on the PlayStation versions of *Castlevania: Symphony of the Night* and *Metal Gear Solid*. CRT-Trinity is also compatible with [Castlevania: Symphony of the Night Ultimate](https://github.com/renanbianchi/sotn-ultimate), while the related [SotN decompilation project](https://github.com/Xeeynamo/sotn-decomp) served as a development reference. Neither project is required, and CRT-Trinity includes no game files, code or assets.

## Key Rendering Features

- **Resolution-aware source reconstruction** — uses DuckStation's internal render grid, including enhanced resolutions, while retaining native game dimensions for optional native-resolution scanline alignment.
- **Selectable source-filtering methods** — Subpixel Blend (default), Edge-Aware and Hybrid reconstruction, with independent horizontal and vertical source-pixel smoothing.
- **Horizontal spot reconstruction** — integrates the spot kernel across each internal source-cell interval rather than point-sampling it. The default horizontal structure is Single Lobe; spot width combines with horizontal source-pixel smoothing.
- **Vertical beam and scanline reconstruction** — uses a Gaussian Beam scanline profile and Gaussian spot kernel by default. Shared Beam derives one luminance-driven beam response for each output pixel; Per-source-line RGB reconstructs nearby beam-line contributions separately for red, green and blue. Both integrate beam contributions over each output pixel's vertical footprint. Per-source-line RGB also supports Source-Domain and Post-Display attenuation placement.
- **Phosphor masks** — Aperture Grille, Slot Mask and Staggered Shadow Mask, with optional damping wires for the Aperture Grille.
- **Display color profiles** — Sony Trinitron/P22-inspired, Toshiba AF/SMPTE-C and Neutral reference choices, with automatic mask pairings when **Use Display Profile Default** is selected.
- **Screen geometry** — Flat (default), an optional LCD Focus horizontal composition warp, and Cylindrical, Spherical and Custom virtual faceplate profiles, with optional adaptive multi-tap reconstruction.
- **Optical and image-finishing effects** — source-image ghosting, halation, multi-pass bloom, vignette and color fringing.
- **Temporal processing** — optional bright-trail persistence, alternating field phase, rolling scanlines and horizontal signal interference; Field-Phase Flicker is available as a separate experimental mode.
- **Animated grain** — with luminance adaptation and Output Pixels, Native Game Pixels or Mixed alignment.

See `AGENTS.md` for the detailed mathematics, pass graph, resource handling, diagnostics and implementation notes.

## Display Color Profiles

The profile choices are grouped around a few different color characters rather than separate full television emulations:

- **Sony Trinitron** profiles use a P22-inspired color reference. **Japanese Cool** is the default, with the cooler, slightly blue-ish look; the other Sony options provide more balanced or monitor-oriented interpretations. Their automatic mask is **Aperture Grille**.
- **Toshiba AF** profiles use an SMPTE-C reference: one balanced around D65 and one warmer, D55-style option. Their automatic mask is **Slot Mask**.
- **Neutral — Standard** bypasses the display-profile color transform and uses the **Aperture Grille** automatic mask. It is neutral only with respect to that transform; the rest of CRT-Trinity still applies.

These are reference color/white-point interpretations, not measured factory calibrations. With **Use Display Profile Default**, the shader selects the mask pairing described above. Choosing an explicit mask changes only the mask, not the display color profile.

## UI Guide

The shader exposes the following controls in DuckStation.

### Display Setup

- **Display Color Profile** — selects the color/white-point interpretation described above.
- **Phosphor Mask Type** — chooses the profile's automatic mask, an explicit Aperture Grille, Slot Mask or Staggered Shadow Mask, or no mask. Selecting a mask here makes its matching group under **Phosphor Mask Settings** active for customization. The color profile is left unchanged.

### Image & Color

- **Brightness**, **Contrast Curve**, **Saturation**, **Gamma** and **Black Level** — adjust overall level, tonal response, color intensity, display-gamma approximation and input black reference.
- **Vignette Strength** — edge-darkening amount; default `0.5`.
- **Vignette Mapping** — Symmetric Viewport (default) evaluates the falloff against the active image rectangle; Legacy Fit preserves the previous framing.
- **Color Fringing** — adjusts the small offsets between red, green and blue source sampling positions.
- **Edge Zoom** — enlarges the image within the active viewport.

### Source Image Filtering

- **Pixel Smoothing Mode** — Subpixel Blend (default), Edge-Aware or Hybrid reconstruction.
- **Pixel Smoothing** — strength of the selected reconstruction; `0` disables it.
- **Horizontal Source-Pixel Smoothing** and **Vertical Source-Pixel Smoothing** — add horizontal and vertical Gaussian reconstruction width before CRT beam treatment.

Subpixel Blend averages source reconstruction at small, symmetric half-offset positions on both axes. Edge-Aware uses a 3×3 neighbourhood to adapt filtering around coherent edges. Hybrid combines the two approaches.

### Screen Geometry

- **Screen Geometry Profile** — Flat (default), LCD Focus, Cylindrical, Spherical or Custom. Flat preserves the original image geometry. LCD Focus is a separate LCD-oriented, non-physical remapping: it slightly expands the centre horizontally, compensates toward the outer-middle image and keeps the viewport edges and vertical coordinates fixed. Because it is applied to the completed image, it also remaps HUD/interface elements. It does not add perspective, rounded corners or change the game aspect ratio.
- **LCD Focus Strength** — controls that horizontal redistribution (`0–0.05`, default `0.02`). At `0.02`, the exact centre has 2% horizontal magnification; `0.05` is the 5% maximum. The mapping is viewport-local and does not stretch the image to another aspect ratio.
- **Surface Radius** — the shared, literal radius for Cylindrical and Spherical profiles (2–40 screen half-widths).
- **Custom Horizontal Curvature** and **Custom Vertical Curvature** — independently control the two axes of the Custom biconic surface. These use a nonlinear `0–100` scale rather than raw radius values. `0` is flat; equal values produce a spherical cap; setting Vertical to `0` gives a horizontally curved cylinder, while setting Horizontal to `0` gives a vertically curved cylinder. Approximate equivalent radii (in screen half-widths) are `8.97 → 248.5`, `20 → 50`, `50 → 8` and `100 → 2`. The quadratic mapping is monotonic but is not a calibrated perceptual scale. The default `8.97` / `8.97` approximates the very shallow, near-flat 50 m faceplate curvature reported for Sony's FD Trinitron GDM-F500, normalized from its 19.8-inch, 4:3 viewable area. This is a symmetric approximation, not a physical calibration of the full glass contour. Safety limits can reduce the strongest requested curvature at extreme camera/aspect settings.
- **Virtual Camera Distance**, **Virtual Camera Horizontal Offset** and **Virtual Camera Vertical Offset** — adjust perspective and viewing position on Cylindrical, Spherical and Custom faceplates. These controls do not affect Flat or LCD Focus. The curved profiles and LCD Focus follow DuckStation's active image viewport, including its offset and size, rather than assuming the image fills the entire output buffer.
- **Geometry Reconstruction** — Bilinear (1 tap), Adaptive up to 4 taps or Adaptive up to 8 taps. Adaptive reconstruction can also account for LCD Focus's small horizontal scale changes.

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
- **Alternating Field Phase** and **Rolling Scanlines** — control scanline phase behaviour over time. Alternating Field Phase is not true 480i field reconstruction.

### Noise & Grain

- **Noise Amount** — grain intensity.
- **Luminance Adaptation** — changes grain strength with image brightness.
- **Grain Animation Speed** — controls temporal evolution; `0` freezes it.
- **Grain Size** — controls grain's spatial scale.
- **Grain Alignment** — Output Pixels, Native Game Pixels or Mixed.

### Signal & Temporal Effects

- **Temporal Trail Persistence** — controls retention of previous-frame highlights; `0` disables trails.
- **Reset History** — clears accumulated temporal history; useful after a target resize.
- **Interference Strength** and **Interference Speed** — control animated horizontal signal wobble.

### Glow & Ghosting

- **Horizontal Blur** and **Vertical Blur** — set the source blur used by ghosting; the same radii are also used by halation.
- **Ghost Strength** — controls the ghost image contribution.
- **Halation Strength**, **Halation Threshold** and **Halation Warmth** — control highlight glow, its cutoff and tint.
- **Halation Respects Scanlines** — determines whether halation is attenuated by the scanline pattern or spreads into its gaps.

### Bloom

- **Bloom Intensity**, **Bloom Threshold**, **Bloom Soft Knee** and **Bloom Radius (pixels at 1080p)** — control wide highlight spill, its cutoff/transition and blur reach. Bloom stacks with Halation. Setting Bloom Intensity to `0` disables its normal sampling and blur work, though its three passes remain scheduled.

### Phosphor Mask Settings

To customize a phosphor mask, select Aperture Grille, Slot Mask or Staggered Shadow Mask under **Display Setup → Phosphor Mask Type**. Use **Use Display Profile Default** to retain the selected profile's predefined mask and settings. Only the group corresponding to an explicitly selected mask affects rendering.

All three custom mask groups share these controls:

- **Mask Strength (Custom)**
- **Triad Pitch (pixels at 1080p)**

The remaining controls depend on the selected pattern:

1. **Aperture Grille**
   - **Stripe / Aperture Width**
   - **Inter-Stripe Gap**
   - **Show Grille Damping Wires**
   - **Damping Wire Strength**
2. **Slot Mask**
   - **Slot Width**
   - **Inter-Slot Gap**
   - **Slot Height**
3. **Staggered Shadow Mask**
   - **Dot Width**
   - **Dot Gap**

### Experimental

- **Field-Phase Flicker (off by default)** — enables a very fast, pronounced CRT-like flicker. It may cause eye strain or dizziness; use it at your discretion.

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
