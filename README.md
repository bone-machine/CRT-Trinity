# CRT-Trinity

**Shader version:** `v1`  
**Format:** DuckStation ReShade FX (`.fx`)  
**Author:** bone-machine  
**Development:** Created with AI-assisted research, shader implementation, technical analysis and iterative review.

## Overview

CRT-Trinity is a configurable CRT-inspired post-processing shader for DuckStation, based on Mattias Gustavsson's **NewPixie CRT**. The original NewPixie shader was adapted to Slang by **hunterk**. **Albatross** later published the `CRT-NewPixie_Albatross` ReShade modification and described converting the vanilla code from Slang to HLSL. DuckStation also distributes its own `CRT-NewPixie.fx`; the available source header and history reviewed for this project do not unambiguously identify the author of that file's original ReShade FX conversion. See **Credits and license** for the distinctions and source links.

**Sony Trinitron is the primary hardware and design reference for the entire shader.** CRT-Trinity is not a generic CRT effect with a Trinitron colour preset attached: its source reconstruction, phosphor structure, beam and scanline behaviour, temporal effects, grain/noise, ghosting, halation, bloom, geometry and other image-finishing choices are all developed and tuned as one cohesive, mild Trinitron-oriented presentation. The reference is the Sony Trinitron aperture-grille CRT family, with a Japanese P22-inspired character guiding the default look.

The design research considers Trinitron tube construction and visible operating principles—including the aperture grille and vertical RGB phosphor stripes, grille support/damper wires, electron-gun and cathode/channel-drive context, beam current and spot behaviour, raster/scanline formation, phosphor emission/persistence, and display colour/white-point characteristics. The shader translates selected screen-visible consequences into real-time image-processing approximations. It does not physically simulate cathodes, electron trajectories, electron-gun geometry, deflection hardware, high-voltage circuitry or phosphor chemistry. Effects such as grain/noise, ghosting, vignette, flicker, halation and bloom are tuned to support the overall Trinitron-inspired image; they are not claims that every Trinitron naturally exhibits those exact artifacts.

The additional display profiles are **user-customization options**, not separate complete simulations of the named televisions. They provide alternate colour-primary/white-point interpretations and the documented automatic mask pairings, while the underlying Trinitron-oriented reconstruction, beam, temporal and finishing model remains the same.

The saved defaults represent the author's preferred appearance, selected by visual judgment rather than instrumented calibration. They are not measurements or factory calibrations of a specific CRT model. The primary game reference is **Castlevania: Symphony of the Night (PlayStation)**; **Metal Gear Solid (PlayStation)** is a secondary reference. Other games may work well, but their rendering characteristics and native resolutions can produce different results.

The default look uses **Sony Trinitron — Japanese Cool**, **Flat** screen geometry and the profile's automatic **Aperture Grille** mask. The default settings are intended as a usable starting point. Most users should make only a small number of familiar, high-level adjustments; detailed beam, custom-mask and geometry parameters are best left alone unless their effects are understood.

## Display colour profiles

The profile selector keeps the two Sony Trinitron choices first and the Standard reference at the bottom:

1. **Sony Trinitron — Japanese Cool** — default; a cooler, blue-leaning interpretation of a Japanese P22 reference.
2. **Sony Trinitron — Balanced Color** — the D65 endpoint of the P22 reference transform.
3. **Sony BVM-D24 — EBU Cool** — uses nominal EBU phosphor primaries with the cool neutral-white character of the default profile.
4. **Sony KX-14CP1 — Monitor Reference** — a separate monitor-oriented Sony reference interpretation.
5. **Toshiba AF — Balanced Color** — an SMPTE-C/D65 reference interpretation.
6. **Toshiba AF — Warm Cinema** — an SMPTE-C interpretation with a warmer, D55-style white-point character.
7. **Standard — Reference Color** — a BT.709/D65-style path that bypasses the display-profile transform.

These are reference interpretations, not measured calibrations of individual displays. They are offered for colour/white-point preference and convenience, not to switch the shader into independent full simulations of the named televisions. The underlying design target remains the Sony Trinitron family for every profile. In particular, Sony BVM-D24 — EBU Cool is a hybrid colour reference: EBU primaries are paired with the default profile's cooler white character. It is not a factory BVM-D24 colour-temperature preset. The Sony P22, KX-14CP1 and Toshiba profiles also have assumptions and limitations; they should not be treated as guaranteed reproductions of a specific set.

With **Use Display Profile Default**, Sony profiles use Aperture Grille, Toshiba AF profiles use Slot Mask, and Standard uses Aperture Grille. The Display Setup legend states this pairing. An explicit **Phosphor Mask Type** selection changes the mask only; it does not change the active colour profile.

## Image processing

### Source reconstruction and enhanced-resolution rendering

The shader distinguishes DuckStation's **internal render dimensions** from the game's **native raster dimensions**. Source reconstruction uses the internal grid when DuckStation supplies it, while CRT raster pitch and native-pixel measurements remain tied to the native game dimensions. This preserves additional detail produced by enhanced internal rendering instead of reducing every sample to one pixel per native PS1 cell.

The distinction is important for scenes that combine native-resolution sprites with enhanced-resolution 3D geometry. At 6× internal resolution, for example, the extra detail in the *Symphony of the Night* Save Room crystal is retained rather than being collapsed to the native pixel grid. This behaviour has been visually confirmed in that scene.

**Pixel Smoothing** uses a 3×3 source-sample neighbourhood. A square-root RGB comparison makes relative differences in dark regions more influential. A YCoCg-like colour-distance measure combines luminance and chroma differences, while a four-quadrant structure-tensor estimate identifies a dominant edge direction and its coherence. The resulting bilateral, edge-aware blend favours smoothing along a coherent edge over smoothing across it. These are practical image-reconstruction heuristics, not a standardized perceptual colour metric.

The same local analysis produces detail-confidence metadata that is reused by **Detail Protection** in the grain stage. This avoids repeating the source-neighbourhood analysis during final composition. The metadata is carried in the alpha channels of the source-filter render targets; those alpha values are not opacity.

Horizontal and vertical reconstruction are separate:

- Horizontal reconstruction integrates internal source cells with the selected spot-kernel family. Horizontal Source-Pixel Smoothing and Horizontal Beam Spot Width contribute to the same effective kernel.
- Vertical Source-Pixel Smoothing performs a separate area-integrated Gaussian reconstruction across internal source-line cells before the CRT beam is applied.
- Native-pixel smoothing controls are converted to the finer internal grid where applicable, so their intended native-pixel scale is retained at enhanced resolutions.

### Scanlines and beam models

The **Scanlines & Beam** section begins with **Enable Scanlines**. Turning it off makes the vertical scanline factor neutral, bypassing both the sine modulation and both beam models. The phosphor mask and its optional damping wires remain active.

**Scanline Beam Profile** selects `Sine` or `Gaussian Beam`:

- `Sine` retains a shaped periodic waveform for users who prefer that appearance.
- `Gaussian Beam` evaluates a repeating vertical spot and integrates its selected profile over the complete output pixel's vertical footprint. Gaussian and Lorentzian profiles use analytic primitives; the Super-Gaussian uses bounded 16-point Gauss-Legendre quadrature. The integrated result is normalized over one raster-line period.

**Beam Spot Profile** selects Gaussian, Super-Gaussian or Lorentzian. It supplies the profile family used by the horizontal spot reconstruction and the Gaussian Beam scanline path.

**Vertical Beam Model** offers two implementations:

- **Shared Beam** — the default. It derives one beam width from source luminance and uses that shared current response to form the vertical scanline modulation.
- **Per-source-line RGB** — evaluates nearby native source lines independently. Each source line is sampled in the linear source domain, and its red, green and blue channel drives independently determine their corresponding beam widths. The selected beam profile is integrated over the output-pixel footprint for each channel, and the channel contributions are reconstructed separately before the normal phosphor and display-colour processing.

Per-source-line RGB uses the existing source-line pitch choices and phase controls. The separate vertical source-smoothing stage has already run before this calculation; it is not repeated inside the beam integrator. `Sine` remains its own waveform path and does not use the vertical beam-model selector.

### Horizontal spot: Single Lobe and Core + Tail

**Horizontal Spot Structure** is independent of the vertical beam model:

- **Single Lobe** is the default and uses one normalized spot profile.
- **Core + Tail** redistributes a chosen fraction of the spot energy into a wider component. Both components use the selected Gaussian, Super-Gaussian or Lorentzian family and are individually normalized before mixing.

The default tail settings are **2% energy** and **2× width**. **Horizontal Spot Tail Energy (%)** controls the amount moved into the tail; **Horizontal Spot Tail Width (x)** controls its sigma relative to the core. These controls affect only Core + Tail. A 0% tail or a 1× tail width is equivalent to the single-lobe result.

The horizontal spot's per-channel current-dependent expansion is also retained: each source cell's red, green and blue drive can widen its respective contribution slightly, up to a 3.5% internal maximum. This is an implementation constant, not another user-facing slider or a measured gun-current response.

### Phosphor masks and damping wires

Three mask families are available: **Aperture Grille**, **Slot Mask** and **Shadow Mask (Staggered Dots)**, plus **None**.

Aperture Grille uses an analytic integral of its smoothed stripe-coverage function over each output-pixel footprint. Its RGB triplet pitch is viewport-relative and includes a **minimum three-output-pixel triplet period** to reduce excessive high-frequency aliasing at low output resolutions. This is a perceptual sampling safeguard, not a measured physical pitch. The safeguard applies to Aperture Grille; Slot Mask and Staggered Shadow Mask retain their own pitch and 8×8 subpixel coverage methods.

Optional aperture-grille damping wires retain their smoothstep-shaped attenuation, but the profile is analytically integrated over each output pixel's vertical footprint. The wires follow the active viewport and are positioned at one-third and two-thirds of its height. Built-in and custom damping wires are off by default. They apply only to Aperture Grille.

### Screen geometry

The default **CRT Surface Profile** is `Flat`. Optional `Cylindrical`, `Spherical` and `Aspherical` profiles project the completed CRT image onto a virtual curved faceplate. Aspherical geometry has separate horizontal and vertical radii plus an edge-departure parameter. Virtual camera distance and offsets affect perspective on curved profiles. **Geometry Reconstruction** provides bilinear one-tap sampling or adaptive major-axis reconstruction capped at four or eight taps. The current method is a bounded one-dimensional anisotropic reconstruction, not full two-dimensional EWA filtering.

### Colour, temporal effects and glow

The input is decoded with a configurable BT.1886-style EOTF approximation and processed in linear light through the source reconstruction and display stages. The shader applies display-profile matrices, a legacy luminance contrast curve, saturation relative to the selected display white and a luminance-preserving highlight roll-off. The final path is SDR-oriented and clamps output to the SDR range; it is not HDR-safe. No unconditional output OETF is applied because final backbuffer encoding is handled by DuckStation/ReShade and can vary by backend.

The temporal history path uses a component-wise maximum between the current linear-light image and a modulated previous-frame history. This produces bright-trail persistence rather than conventional motion blur or a calibrated phosphor-decay model. **Temporal Trail Persistence** is zero by default.

Continuous animated effects use DuckStation's elapsed-time `timer` converted to a 60 Hz reference clock, keeping their rate consistent across different render frame rates when the host timer advances in real time. Discrete frame state, including first-frame history initialization and odd/even phase parity, continues to use the frame counter.

**Halation** is extracted from the completed phosphor-masked, display-processed CRT scene, blurred and tinted, then composited as a local glow. Its A/B option determines whether it spreads into scanline gaps or is modulated by the local scanline factor. Halation also contributes to the wider **Bloom** extraction, so the two effects intentionally stack.

When **Bloom Intensity** is zero, Bloom extraction and blur shaders return before doing their normal sampling and blur work, and the final composite skips sampling the Bloom texture. The three quarter-resolution Bloom passes are still scheduled and write zero; the shader cannot dynamically remove those passes through the slider. Diagnostic Bloom views can still inspect the intermediate buffers. Halation is independent and remains active when Bloom is zero.

### Grain, vignette, ghosting and interference

Animated grain supports Output Pixels, Native Game Pixels and Mixed alignment, adjustable size and chroma, temporal speed, luminance adaptation, image-aware chroma and detail protection. Detail Protection reuses the source-filter confidence metadata; Luminance Adaptation instead changes grain strength according to image brightness. These controls affect different aspects of the grain.

Other optional effects include vignette, colour fringing, source-image ghosting and a small animated horizontal interference wobble. They are post-processing approximations, not full physical models of CRT convergence, phosphor chemistry or analog video transmission.

## Saved starting defaults

The main visual defaults are:

| Setting | Default |
|---|---:|
| Display Color Profile | Sony Trinitron — Japanese Cool |
| CRT Surface Profile | Flat |
| Geometry Reconstruction | Bilinear (1 tap) |
| Pixel Smoothing | `0.35` |
| Horizontal Source-Pixel Smoothing | `0.17` |
| Vertical Source-Pixel Smoothing | `0.10` |
| Enable Scanlines | On |
| Scanline Beam Profile | Gaussian Beam |
| Vertical Beam Model | Shared Beam |
| Beam Spot Profile | Gaussian |
| Horizontal Spot Structure | Single Lobe |
| Horizontal Spot Tail Energy / Width | `2%` / `2×` |
| Scanline Strength | `1.7` |
| Alternating Field Phase | On |
| Rolling Scanlines | On |
| Noise Amount | `0.06` |
| Detail Protection | `0.50` |
| Image-Aware Chroma | `0.25` |
| Bloom Intensity | `0.15` |

The remaining saved defaults are listed in the shader UI and documented in `AGENTS.md`. Defaults are a preferred baseline, not a requirement to tune every control.

## Experimental: Field-Phase Flicker

The **Experimental** category, placed immediately above Diagnostics, contains **Field-Phase Flicker**. It is off by default. When enabled, it ignores all 17 settings in **Scanlines & Beam** and uses that section's normal defaults except for these forced values:

- **Enable Scanlines:** On
- **Vertical Beam Model:** Per-source-line RGB
- **Rolling Scanlines:** Off
- **Alternating Field Phase:** On

Every other Scanlines & Beam setting is pinned to its saved default while the experiment is active. The visible explanatory legend sits directly below the toggle and repeats the tooltip. The underlying UI selections are not overwritten: when the mode is disabled, all Scanlines & Beam controls resume using the values previously selected by the user.

This combination can produce a pronounced top-to-bottom alternating beam/flicker appearance. It shifts the procedural beam phase on alternating rendered frames; it does **not** receive or reconstruct separate 480i fields.

## Recommended use

For ordinary use, start with the defaults and make only a few familiar changes:

1. Choose the **Display Color Profile** that best suits the game's palette and your preference.
2. Keep **CRT Surface Profile** on Flat unless you specifically want curvature.
3. Adjust **Enable Scanlines** and **Scanline Strength** if the beam texture is too prominent or too subtle.
4. Make small changes to **Pixel Smoothing**, source-pixel smoothing, **Noise Amount**, **Bloom Intensity** or **Halation Strength** only when the image gives you a reason to.
5. Leave the more specialized beam, custom mask, camera and reconstruction controls at their defaults unless you understand their interactions.

**Field-Phase Flicker** is an experimental alternative, not a general-purpose default preset. It overrides the entire Scanlines & Beam section while enabled.

## Game reference projects

The shader's primary game reference is *Castlevania: Symphony of the Night* for PlayStation. Two community development projects provide useful technical and game-variant context:

- **[Castlevania: Symphony of the Night Decompilation](https://github.com/Xeeynamo/sotn-decomp)** — Xeeynamo's matching decompilation project for the PlayStation game and related PSP/Saturn releases. It is an independent game-development project, not a shader dependency.
- **[Castlevania: Symphony of the Night Ultimate (SOTN Ultimate)](https://github.com/renanbianchi/sotn-ultimate)** — a fork of the decompilation project that combines the PS1 release with selected content and features from the Saturn and PSP releases. It is also independent of this shader.

These projects are acknowledged as relevant game-reference resources; CRT-Trinity does not include their game code or assets.

## Installation

Copy `CRT-Trinity.fx` into DuckStation's `shaders/reshade/Shaders/` directory and select it in the ReShade FX post-processing options. Keep the shader as a single `.fx` file. The shader is intended for DuckStation's ReShade FX integration and uses DuckStation-specific source uniforms for native/internal dimensions and viewport mapping.

## Credits and license

- **Mattias Gustavsson** — creator of the original **NewPixie CRT**. [GitHub](https://github.com/mattiasgustavsson) · [DuckStation upstream FX](https://github.com/stenzek/duckstation/blob/master/data/resources/shaders/reshade/Shaders/CRT-NewPixie.fx)
- **hunterk** — adapted NewPixie CRT to the Slang shader format. [libretro/slang-shaders](https://github.com/libretro/slang-shaders/tree/master/crt/shaders/newpixie)
- **Albatross (`Far_Albatross_8821`)** — author of the `CRT-NewPixie_Albatross` ReShade modification. Their Reddit post describes converting the vanilla code from Slang to HLSL and adding customization/variants. This credits their published modification and stated conversion work; it does **not** claim that they authored the first DuckStation `CRT-NewPixie.fx` conversion. The DuckStation ReShade FX file was already present by 16 June 2024: a commit by Hyllian modified its frame/aspect-ratio handling. That commit confirms the file predates Albatross's 2025 post, but it does not identify the author of the original FX conversion. [Reddit post](https://www.reddit.com/r/duckstation/comments/1kx2ikc/crtnewpixie_albatross_what_a_lame_name_but/) · [Shared files](https://drive.google.com/drive/folders/1DgvTyrDYCCzCMyUFI46krn34d7IePbd2)
- **DuckStation** (`stenzek/duckstation`) — ReShade FX support, the upstream `CRT-NewPixie.fx` distribution and host integration. [GitHub repository](https://github.com/stenzek/duckstation)

The colour profiles, masks, beam reconstruction, smoothing, grain protection, geometry, optical effects, UI and saved defaults are project-specific AI-assisted development work. The shader is distributed under the MIT License; see `LICENSE`.
