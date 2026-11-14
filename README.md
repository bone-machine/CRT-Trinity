# CRT-Trinity

CRT-Trinity is a **highly user-configurable Sony Trinitron-inspired CRT post-processing ReShade FX shader for DuckStation**, distributed as a single `.fx` file. It builds on Mattias Gustavsson’s NewPixie CRT, with related adaptations credited below.

The shader's overall design is based on selected characteristics of the **Sony Trinitron aperture-grille CRT family**, particularly its construction and operating behaviour, with a Japanese P22-inspired default. These ideas guide the phosphor structure, beam and scanline behaviour, and the overall display treatment. The shader recreates them through real-time screen-space approximations, not a complete physical simulation. Finishing effects such as grain, ghosting, bloom and flicker are aesthetic additions, not measured traits of every Trinitron.

The defaults are simply what I liked best: a cool, slightly blue-ish picture with the CRT feel I wanted. This isn't a faithful electrical or optical emulation of a particular television. Some touches—grain, ghosting, bloom and flicker—are there because I think they look good, not because every CRT behaved that way. Change anything you like; the picture should be yours.

I mainly tuned the look while playing *Castlevania: Symphony of the Night* and *Metal Gear Solid* on PlayStation. **It's ready to use with [Castlevania: Symphony of the Night Ultimate](https://github.com/renanbianchi/sotn-ultimate).** The related [SotN decompilation project](https://github.com/Xeeynamo/sotn-decomp) is also a useful reference.

## Main Techniques

- **Internal-resolution-aware reconstruction** — uses DuckStation's enhanced internal grid while keeping CRT raster pitch tied to native game dimensions.
- **Subpixel Blend reconstruction (default)**, with optional **Edge-Aware** and **Hybrid** modes.
- **Fixed Gaussian Beam scanlines and Gaussian spot kernel**, integrated over output-pixel footprints.
- **Shared Beam and Per-source-line RGB** vertical beam models, with selectable Per-source-line RGB attenuation placement.
- **Single Lobe horizontal spot reconstruction** — the horizontal spot shape is fixed rather than exposed as a selector.
- **Phosphor masks** — Aperture Grille, Slot Mask and Staggered Shadow Mask, with optional aperture-grille damping wires.
- **Temporal bright-trail persistence** — previous-frame highlights can be retained; this is not conventional motion blur or calibrated phosphor decay.
- **Halation and multi-pass bloom**, plus time-based grain, flicker and interference effects.

See `AGENTS.md` for the detailed mathematics, pass graph, resource handling, diagnostics and implementation notes.

## Display Colour Profiles

The profile choices are grouped around a few different colour characters rather than separate full television emulations:

- **Sony Trinitron** profiles use a P22-inspired colour reference. **Japanese Cool** is the default, with the cooler, slightly blue-ish look; the other Sony options provide more balanced or monitor-oriented interpretations. Their automatic mask is **Aperture Grille**.
- **Toshiba AF** profiles use an SMPTE-C reference: one balanced around D65 and one warmer, D55-style option. Their automatic mask is **Slot Mask**.
- **Neutral — Standard** bypasses the display-profile colour transform and uses the **Aperture Grille** automatic mask. It is neutral only with respect to that transform; the rest of CRT-Trinity still applies.

These are reference colour/white-point interpretations, not measured factory calibrations. With **Use Display Profile Default**, the shader selects the mask pairing described above. Choosing an explicit mask changes only the mask, not the display colour profile.

## UI Guide

The shader exposes the following controls in DuckStation.

### Display Setup

- **Display Color Profile** — selects the colour/white-point interpretation described above.
- **Phosphor Mask Type** — chooses the profile's automatic mask, an explicit Aperture Grille, Slot Mask or Staggered Shadow Mask, or no mask. Selecting a mask here activates the matching **Custom** subsection below, where that mask's strength, pitch, shape and gap can be adjusted. The colour profile is left unchanged.

### Image & Color

- **Brightness**, **Contrast Curve**, **Saturation**, **Gamma** and **Black Level** — adjust overall level, tonal response, colour intensity, display-gamma approximation and input black reference.
- **Edge Zoom** — enlarges the image within the active viewport.

### Source Image Filtering

- **Pixel Smoothing Mode** — Subpixel Blend (default), Edge-Aware or Hybrid reconstruction.
- **Pixel Smoothing** — strength of the selected reconstruction; `0` disables it.
- **Adjacent-Tap Edge Blending** — optional cached edge-aware blending for the horizontal taps beside the centre tap. Only affects Edge-Aware and Hybrid; off by default.
- **Horizontal Source-Pixel Smoothing** and **Vertical Source-Pixel Smoothing** — add horizontal and vertical Gaussian reconstruction width before CRT beam treatment.

### Screen Geometry

- **CRT Surface Profile** — Flat, Cylindrical, Spherical or Aspherical projection.
- **Surface Radius** — curvature for Cylindrical and Spherical profiles.
- **Aspherical Horizontal Radius**, **Aspherical Vertical Radius** and **Aspheric Edge Departure** — shape the Aspherical faceplate.
- **Virtual Camera Distance**, **Virtual Camera Horizontal Offset** and **Virtual Camera Vertical Offset** — adjust perspective and viewing position on curved profiles.
- **Screen Corner Radius** — rounds the projected screen boundary.
- **Geometry Reconstruction** — Bilinear (1 tap), Adaptive up to 4 taps or Adaptive up to 8 taps.

### Scanlines & Beam

The beam shape is fixed: **Gaussian Beam** scanlines, a **Gaussian** spot kernel and a **Single Lobe** horizontal spot.

- **Enable Scanlines** — bypasses vertical beam modulation when off; phosphor masks remain active.
- **Scanline Strength** — overall scanline modulation.
- **Vertical Beam Model** — Shared Beam or Per-source-line RGB.
- **Per-source-line RGB Attenuation** — Source-Domain (default) or Post-Display (Shared Beam-aligned). Only affects Per-source-line RGB; Field-Phase Flicker temporarily forces Post-Display.
- **Vertical Beam Sharpness** and **Scanline Beam Widening** — shape the Gaussian beam and its brightness-dependent widening.
- **Beam Current Response** and **Beam Average Drive** — control drive-to-width response and average beam output.
- **Horizontal Beam Spot Width** — adds Gaussian spot width to source reconstruction.
- **Source-Line Frequency (0 = stock pitch)** — manually sets scanline frequency; `0` uses the stock pitch.
- **Match Scanlines to Source Resolution** — derives scanline spacing from DuckStation's native dimensions and overrides the manual frequency.
- **Alternating Field Phase** and **Rolling Scanlines** — control scanline phase behaviour over time. Alternating Field Phase is not true 480i field reconstruction.

### CRT Artifacts & Persistence

- **Vignette Strength** — edge-darkening amount; default `0.5`.
- **Vignette Mapping** — Symmetric Viewport (default) evaluates the falloff against the active image rectangle; Legacy Fit preserves the previous framing.
- **Flicker Amount** and **Color Fringing**.
- **Temporal Trail Persistence** — controls retention of previous-frame highlights; `0` disables trails.
- **Reset History** — clears accumulated temporal history; useful after a target resize.
- **Interference Strength** and **Interference Speed** — control animated horizontal wobble.

### Noise & Grain

- **Noise Amount** — grain intensity.
- **Luminance Adaptation** — changes grain strength with image brightness.
- **Headroom-Aware Grain** — on by default; symmetrically reduces grain excursions near black and white to avoid one-sided output clipping.
- **Grain Chroma** — blends neutral and independently varying RGB grain.
- **Grain Animation Speed** — controls temporal evolution; `0` freezes it.
- **Grain Size** — controls grain's spatial scale.
- **Grain Alignment** — Output Pixels, Native Game Pixels or Mixed.
- **Detail Protection** — reduces grain around fine, high-contrast details.
- **Image-Aware Chroma** — adapts grain colour variation to the underlying image colour.

### Glow & Ghosting

- **Horizontal Blur** and **Vertical Blur** — set the source blur used by ghosting; the same radii are also used by halation.
- **Ghost Strength** — controls the ghost image contribution.
- **Halation Strength**, **Halation Threshold** and **Halation Warmth** — control highlight glow, its cutoff and tint.
- **Halation Respects Scanlines** — determines whether halation is attenuated by the scanline pattern or spreads into its gaps.

### Bloom

- **Bloom Intensity**, **Bloom Threshold**, **Bloom Soft Knee** and **Bloom Radius (pixels at 1080p)** — control wide highlight spill, its cutoff/transition and blur reach. Bloom stacks with Halation. Setting Bloom Intensity to `0` disables its normal sampling and blur work, though its three passes remain scheduled.

### Aperture Grille (Custom)

Used when Aperture Grille is selected: **Mask Strength (Custom)**, **Triad Pitch (pixels at 1080p)**, **Stripe / Aperture Width**, **Inter-Stripe Gap**, **Show Grille Damping Wires** and **Damping Wire Strength**.

### Slot Mask (Custom)

Used when Slot Mask is selected: **Mask Strength (Custom)**, **Triad Pitch (pixels at 1080p)**, **Slot Width**, **Inter-Slot Gap** and **Slot Height**.

### Shadow Mask (Custom)

Used when Shadow Mask (Staggered Dots) is selected: **Mask Strength (Custom)**, **Triad Pitch (pixels at 1080p)**, **Dot Width** and **Dot Gap**.

### Experimental

- **Field-Phase Flicker (off by default)** — enables a very fast, pronounced CRT-like flicker. It may cause eye strain or dizziness; use it at your discretion.

### Diagnostics

**Debug View** provides 21 inspection modes. Set it back to **Off** to restore the normal image.

| Index | View | What it shows |
|---:|---|---|
| 0 | Off | Normal rendering. |
| 1 | Accumulated Frame (Linear) | Current accumulated source before CRT reconstruction. |
| 2 | Current Input (Encoded) | Incoming backbuffer signal before the accumulation EOTF. |
| 3 | Trail Only (Linear ×4) | Retained history contribution, amplified. |
| 4 | Counter and Toggle Test | Frame-parity colours and effective phase-toggle state. |
| 5 | Phosphor Mask Only | Selected RGB mask without the image. |
| 6 | CRT Scene (Display View, No Bloom) | Processed scene with halation/tone mapping, without wide bloom. |
| 7 | Bloom Blur (×4) | Final quarter-resolution bloom blur, amplified. |
| 8 | Bloom Extract (×4) | Bloom extraction before final blur, amplified. |
| 9 | Horizontal Source Reconstruction | Horizontally reconstructed source, tone-mapped for visibility. |
| 10 | Vertical Source Reconstruction | Vertically reconstructed source, tone-mapped for visibility. |
| 11 | Source Detail Confidence | Detail-protection metadata. |
| 12 | Source Ghost Blur (×4) | Source blur used for ghosting, before scratch-target reuse. |
| 13 | Scanline / Beam Factor | Local vertical beam attenuation factor. |
| 14 | Halation Bright Pass (×4) | Thresholded highlights before horizontal blur. |
| 15 | Halation Horizontal Blur (×4) | Horizontal halation intermediate. |
| 16 | Halation Blur (×4) | Completed halation blur. |
| 17 | Vignette Falloff | Selected Legacy Fit or Symmetric Viewport vignette. |
| 18 | CRT Surface Coverage | Projected faceplate coverage/edge mask. |
| 19 | Phosphor Mask + Damping Wires | Selected mask combined with effective damping-wire transmission. |
| 20 | CRT Scene (Linear, Pre-Glow) | Linear CRT scene before halation and bloom compositing. |

Some diagnostic views deliberately force intermediate work (for example, halation or bloom inspection) even when the corresponding effect is disabled in the normal image.

## Installation

Copy `CRT-Trinity.fx` into DuckStation's `shaders/reshade/Shaders/` directory and select it in DuckStation's ReShade FX post-processing options. **This shader is written for DuckStation's host-provided source information**, including native/internal render dimensions and active-viewport mapping. Other ReShade hosts may not provide the same uniforms or semantics, so correct operation outside DuckStation is not guaranteed. The shader is distributed as one `.fx` file.

## Credits

- **Mattias Gustavsson** — original NewPixie CRT. [GitHub](https://github.com/mattiasgustavsson) · [DuckStation upstream FX](https://github.com/stenzek/duckstation/blob/master/data/resources/shaders/reshade/Shaders/CRT-NewPixie.fx)
- **hunterk** — NewPixie's Slang adaptation. [Source](https://github.com/libretro/slang-shaders/tree/master/crt/shaders/newpixie)
- **Albatross** — `CRT-NewPixie_Albatross` ReShade modification and its published HLSL-conversion work. [Reddit post](https://www.reddit.com/r/duckstation/comments/1kx2ikc/crtnewpixie_albatross_what_a_lame_name_but/) · [Shared files](https://drive.google.com/drive/folders/1DgvTyrDYCCzCMyUFI46krn34d7IePbd2)
- **DuckStation** — ReShade FX host support and upstream shader distribution. [Repository](https://github.com/stenzek/duckstation)

## License

CRT-Trinity's custom reconstruction, beam, mask, colour-profile, geometry, grain, temporal and optical-effect implementations and saved defaults are project-specific work by bone-machine, developed with AI assistance. Distributed under the MIT License; see `LICENSE`.
