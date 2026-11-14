# CRT-Trinity

CRT-Trinity is a **highly customizable Sony Trinitron-inspired CRT post-processing ReShade FX shader for DuckStation**, distributed as a single `.fx` file. It builds on Mattias Gustavsson’s NewPixie CRT, with related adaptations credited below.

The shader's overall design and rendering approach are based on selected characteristics of the **Sony Trinitron aperture-grille CRT family**, particularly its construction and operating behaviour, with a Japanese P22-inspired default. These characteristics guide the phosphor structure, beam and scanline behaviour, and overall display treatment. The shader recreates them selectively through real-time screen-space approximations rather than an exact physical simulation. Finishing effects such as grain, ghosting and bloom are aesthetic additions, not measured Trinitron traits.

Other display profiles change the colour/white point and the default mask pairing. They are not separate television emulations.

Defaults reflect the author's visual preference, not instrumented calibration. Start with the defaults; most users only need to adjust the display profile, scanline strength, source smoothing, grain and glow to taste.

The main game references are *Castlevania: Symphony of the Night* and *Metal Gear Solid* for PlayStation.

## Main techniques

- **Internal-resolution-aware source reconstruction** — uses DuckStation's enhanced internal grid while keeping CRT raster pitch tied to native game dimensions.
- **Edge-aware pixel smoothing** — combines square-root RGB distance, YCoCg-like colour distance and directional structure-tensor analysis to reduce smoothing across edges.
- **Pixel-integrated beam profiles** — supports Sine and Gaussian Beam scanlines, plus Gaussian, Super-Gaussian and Lorentzian spot profiles.
- **Shared and per-source-line RGB beam models** — offers a shared luminance-driven beam or independent source-line/channel response.
- **Single Lobe / Core + Tail spot reconstruction** — the optional wider tail redistributes part of the normalized spot energy.
- **Integrated phosphor-mask coverage** — includes Aperture Grille, Slot Mask and Staggered Shadow Mask, with optional aperture-grille damping wires.
- **Temporal bright-trail persistence** — blends current and previous linear-light frames; it is not conventional motion blur or a calibrated phosphor-decay model.
- **Linear-light halation and multi-pass bloom**, plus time-based grain, flicker and interference effects.

See `AGENTS.md` for the detailed mathematics, pass graph, resource handling, implementation constraints and audit guidance.

## Display colour profiles

1. **Sony Trinitron — Japanese Cool** — default; cooler Japanese P22-inspired interpretation.
2. **Sony Trinitron — Balanced Color** — D65 P22 interpretation.
3. **Sony BVM-D24 — EBU Cool** — EBU primaries with the default profile's cooler white character.
4. **Sony KX-14CP1 — Monitor Reference** — monitor-oriented Sony reference.
5. **Toshiba AF — Balanced Color** — SMPTE-C / D65 interpretation.
6. **Toshiba AF — Warm Cinema** — SMPTE-C with a warmer, D55-style white character.
7. **Standard — Reference Color** — BT.709 / D65-style path that bypasses the display-profile transform.

These are reference colour interpretations, not measured calibrations or complete display simulations. With **Use Display Profile Default**, Sony and Standard profiles use Aperture Grille, while Toshiba AF profiles use Slot Mask. An explicit mask selection overrides only the mask, not the colour profile.

## UI guide

The shader exposes the following controls in DuckStation. Items that are self-explanatory are listed without further explanation.

### Display Setup

- **Display Color Profile** — selects the colour/white-point interpretation above.
- **Phosphor Mask Type** — uses the profile default, Aperture Grille, Slot Mask, Staggered Shadow Mask or no mask.
- **Edge Zoom** — enlarges the image within the viewport.

### Image & Color

- **Brightness**, **Contrast Curve**, **Saturation**, **Gamma** and **Black Level** — adjust the image's overall level, tonal response, colour intensity, display gamma approximation and input black reference.

### Source Image Filtering

- **Pixel Smoothing** — edge-aware reconstruction of source samples; `0` disables it.
- **Horizontal Source-Pixel Smoothing** and **Vertical Source-Pixel Smoothing** — add horizontal and vertical Gaussian reconstruction width before the CRT beam treatment.

### Screen Geometry

- **CRT Surface Profile** — Flat, Cylindrical, Spherical or Aspherical projection.
- **Surface Radius** — curvature for Cylindrical and Spherical profiles.
- **Aspherical Horizontal Radius**, **Aspherical Vertical Radius** and **Aspheric Edge Departure** — shape the Aspherical faceplate.
- **Virtual Camera Distance**, **Virtual Camera Horizontal Offset** and **Virtual Camera Vertical Offset** — adjust perspective and viewing position on curved profiles.
- **Screen Corner Radius** — rounds the projected screen boundary.
- **Geometry Reconstruction** — Bilinear (1 tap), Adaptive up to 4 taps or Adaptive up to 8 taps.

### Scanlines & Beam

- **Enable Scanlines** — bypasses vertical beam/scanline modulation when off; phosphor masks remain active.
- **Scanline Beam Profile** — selects Sine or Gaussian Beam.
- **Scanline Strength** — overall scanline modulation.
- **Vertical Beam Sharpness** — shapes the vertical profile or beam width.
- **Scanline Beam Widening** — controls brightness-dependent vertical beam widening.
- **Beam Spot Profile** — Gaussian, Super-Gaussian or Lorentzian profile family.
- **Horizontal Spot Structure** — Single Lobe or Core + Tail.
- **Horizontal Spot Tail Energy (%)** and **Horizontal Spot Tail Width (x)** — set the energy and relative width of the optional tail; used only with Core + Tail.
- **Vertical Beam Model** — Shared Beam or Per-source-line RGB.
- **Horizontal Beam Spot Width** — adds horizontal beam width to source reconstruction.
- **Beam Current Response** — shapes the relationship between source drive and beam widening.
- **Beam Average Drive** — sets the mean output level of the normalized vertical beam.
- **Source-Line Frequency (0 = stock pitch)** — manually sets scanline frequency; `0` uses the stock pitch.
- **Match Scanlines to Source Resolution** — derives scanline spacing from DuckStation's native dimensions and overrides the manual frequency.
- **Alternating Field Phase** and **Rolling Scanlines** — control scanline phase behaviour over time. Alternating Field Phase is not true 480i field reconstruction.

### CRT Artifacts & Persistence

- **Vignette Strength**, **Flicker Amount** and **Color Fringing**.
- **Temporal Trail Persistence** — controls retention of previous-frame highlights; `0` disables trails.
- **Reset History** — clears accumulated temporal history; useful after a target resize.
- **Interference Strength** and **Interference Speed** — control the animated horizontal wobble.

### Noise & Grain

- **Noise Amount** — grain intensity.
- **Luminance Adaptation** — changes grain strength with image brightness.
- **Grain Chroma** — blends neutral and independently varying RGB grain.
- **Grain Animation Speed** — controls temporal evolution; `0` freezes it.
- **Grain Size** — controls the grain's spatial scale.
- **Grain Alignment** — Output Pixels, Native Game Pixels or Mixed.
- **Detail Protection** — reduces grain around fine, high-contrast details.
- **Image-Aware Chroma** — adapts grain colour variation to the underlying image colour.

### Glow & Ghosting

- **Horizontal Blur** and **Vertical Blur** — set the source blur used by ghosting.
- **Ghost Strength** — controls the ghost image contribution.
- **Halation Strength**, **Halation Threshold** and **Halation Warmth** — control highlight glow, its cutoff and tint.
- **Halation Respects Scanlines** — determines whether halation is attenuated by the scanline pattern or spreads into its gaps.

### Bloom

- **Bloom Intensity**, **Bloom Threshold**, **Bloom Soft Knee** and **Bloom Radius (pixels at 1080p)** — control wide highlight spill, its cutoff/transition and blur reach. Bloom stacks with Halation. Setting Bloom Intensity to `0` disables its normal sampling and blur work, though its three passes remain scheduled.

### Aperture Grille (Custom)

Used when Aperture Grille is selected:

- **Mask Strength (Custom)**, **Triad Pitch (pixels at 1080p)**, **Stripe / Aperture Width** and **Inter-Stripe Gap**.
- **Show Grille Damping Wires** and **Damping Wire Strength**.

### Slot Mask (Custom)

Used when Slot Mask is selected: **Mask Strength (Custom)**, **Triad Pitch (pixels at 1080p)**, **Slot Width**, **Inter-Slot Gap** and **Slot Height**.

### Shadow Mask (Custom)

Used when Shadow Mask (Staggered Dots) is selected: **Mask Strength (Custom)**, **Triad Pitch (pixels at 1080p)**, **Dot Width** and **Dot Gap**.

### Experimental

- **Field-Phase Flicker** — overrides all Scanlines & Beam settings while enabled, using that section's defaults except that it forces Per-source-line RGB, turns Rolling Scanlines off and turns Alternating Field Phase on. The UI selections are preserved and resume when the experiment is disabled. This is a procedural alternating-frame effect, not separate-field 480i reconstruction.

### Diagnostics

- **Debug View** — displays frame/history data, the mask, the pre-bloom CRT scene, or amplified Bloom extraction/blur buffers.

## Game reference projects

- [Castlevania: Symphony of the Night Decompilation](https://github.com/Xeeynamo/sotn-decomp) — PlayStation game decompilation and related release context.
- [Castlevania: Symphony of the Night Ultimate](https://github.com/renanbianchi/sotn-ultimate) — a decompilation fork combining the PS1 release with selected Saturn and PSP content/features.

These are independent reference projects, not shader dependencies; CRT-Trinity does not include their game code or assets.

## Installation

Copy `CRT-Trinity.fx` into DuckStation's `shaders/reshade/Shaders/` directory and select it in the ReShade FX post-processing options. Keep the shader as a single `.fx` file. It uses DuckStation-specific source uniforms for native/internal dimensions and viewport mapping.

## Credits and license

- **Mattias Gustavsson** — original NewPixie CRT. [GitHub](https://github.com/mattiasgustavsson) · [DuckStation upstream FX](https://github.com/stenzek/duckstation/blob/master/data/resources/shaders/reshade/Shaders/CRT-NewPixie.fx)
- **hunterk** — NewPixie's Slang adaptation. [Source](https://github.com/libretro/slang-shaders/tree/master/crt/shaders/newpixie)
- **Albatross** — `CRT-NewPixie_Albatross` ReShade modification and its published HLSL-conversion work. [Reddit post](https://www.reddit.com/r/duckstation/comments/1kx2ikc/crtnewpixie_albatross_what_a_lame_name_but/) · [Shared files](https://drive.google.com/drive/folders/1DgvTyrDYCCzCMyUFI46krn34d7IePbd2)
- **DuckStation** — ReShade FX host support and upstream shader distribution. [Repository](https://github.com/stenzek/duckstation)

CRT-Trinity's custom reconstruction, beam, mask, colour-profile, geometry, grain, temporal and optical-effect implementations and saved defaults are project-specific work by bone-machine, developed with AI assistance. Distributed under the MIT License; see `LICENSE`.
