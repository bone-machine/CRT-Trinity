#include "ReShade.fxh"

// HLSL-compatible modulo helper; declare before the first use in grain_source_uv().
#define mod(x,y) (x-y*floor(x/y))

// -----------------------------------------------------------------------------
// CRT-Trinity — a mild Sony Trinitron-oriented DuckStation ReShade FX shader.
// Version: v1 | Author: bone-machine
//
// Primary hardware/design reference: the Sony Trinitron aperture-grille CRT family,
// especially the Japanese P22-inspired character used by the default profile. Every
// subsystem—source reconstruction, beam/scanline treatment, phosphor structure,
// temporal behaviour, grain/noise, ghosting, halation, bloom and optional geometry—
// is designed and tuned as part of one cohesive Trinitron-inspired presentation.
// Other display profiles are color/white-point and automatic-mask customizations,
// not independent full simulations of the named televisions.
//
// Research considers Trinitron tube construction and operating principles, including
// aperture grille/RGB phosphors, damping wires, cathode/electron-gun drive context,
// beam current/spot behaviour, raster formation and phosphor emission/persistence.
// The shader implements screen-space approximations; it does not physically simulate
// cathodes, electron trajectories, the deflection system or phosphor chemistry. Some
// finishing effects (grain/noise, ghosting, flicker, halation and bloom) are aesthetic
// interpretations tuned for the overall Trinitron presentation, not literal claims
// about artifacts inherent to every Trinitron set.
//
// Software lineage: NewPixie CRT by Mattias Gustavsson; Slang adaptation by hunterk.
// Albatross published a separate configurable ReShade modification and described a
// Slang-to-HLSL conversion. See README.md / AGENTS.md for precise attribution.
// Mainly judged with Castlevania: Symphony of the Night and Metal Gear Solid 1.
//
// Developed with AI-assisted research, implementation and iterative technical review.
// The defaults are the author's preferred visual settings, selected by eye rather than
// measured calibration. Flat geometry is the default. Most users should begin with
// the defaults and make only a few high-level changes. See README.md for usage guidance
// and AGENTS.md for the technical architecture.
// -----------------------------------------------------------------------------

/*
 * Copyright (c) 2016 Mattias Gustavsson
 * Copyright (c) 2026 bone-machine
 * SPDX-License-Identifier: MIT
 * See LICENSE for the full license text.
 */


// Declared here because the accumulation pass uses it to clear undefined history on frame 1.
uniform int FCount < source = "framecount"; >;
// DuckStation exposes Timer in milliseconds since game start. Convert it to a
// 60 Hz-equivalent frame clock so existing per-frame animation rates are retained
// at 60 FPS while continuous phases remain independent of the actual frame rate.
uniform float timer < source = "timer"; >;

float animation_frame_clock()
{
    return max(timer, 0.0) * 0.06;
}

// User-facing shader options. Declarations are ordered for a practical DuckStation UI flow.

// Locked values retained from the chosen baseline; intentionally not user-editable.
#define japanese_whitepoint 71.0
#define edge_feather 1.0
#define enable_selective_warm_desaturation true
#define selective_warm_hue_center 0.0
#define selective_warm_hue_range 0.0
#define selective_warm_hue_feather 50.0
#define selective_warm_saturation_reduction 0.4

// CRT-TRINITY -----------------------------------------------------------------

uniform int project_version <
    ui_type = "combo";
    ui_items = "v1\0";
    ui_label = "Version";
    ui_category = "CRT-Trinity";
> = 0;

uniform int project_author <
    ui_type = "combo";
    ui_items = "bone-machine\0";
    ui_label = "Author";
    ui_category = "CRT-Trinity";
> = 0;

uniform int project_credits <
    ui_type = "combo";
    ui_items = "Mattias Gustavsson — original NewPixie\0Albatross — community ReShade adaptation\0hunterk — Slang adaptation\0DuckStation — ReShade FX support\0";
    ui_label = "Credits";
    ui_category = "CRT-Trinity";
    ui_tooltip = "Original shader, adaptations and host integration. See README.md for details.";
> = 0;

// DISPLAY & PHOSPHOR ------------------------------------------------------------

uniform int display_profile <
    ui_type = "combo";
    ui_items = "Sony Trinitron — Japanese Cool\0Sony Trinitron — Balanced Color\0Sony BVM-D24 — EBU Cool\0Sony KX-14CP1 — Monitor Reference\0Toshiba AF — Balanced Color\0Toshiba AF — Warm Cinema\0Neutral — Standard\0";
    ui_label = "Display Color Profile";
    ui_category = "Display Setup";
    ui_tooltip = "Choose the color character. Sony P22 is the cooler Japanese-inspired reference; Toshiba uses SMPTE-C with balanced D65 and warm D55 interpretations; BVM-D24 EBU Cool uses the published EBU phosphor primaries with the existing Japanese Cool white character; Neutral bypasses only the display-color transform; masks and all later shader processing still apply. These are reference interpretations, not individual-tube calibrations.";
> = 0;

uniform int phosphor_mask_selection <
    ui_type = "combo";
    ui_items = "Use Display Profile Default\0Aperture Grille\0Slot Mask\0Shadow Mask (Staggered Dots)\0None\0";
    ui_label = "Phosphor Mask Type";
    ui_category = "Display Setup";
    ui_tooltip = "Use Display Profile Default follows the selected profile’s built-in mask and settings. An explicit mask choice uses the corresponding group under Phosphor Mask Settings and overrides only the mask. The display color profile remains active. None disables the mask.";
> = 0;

uniform int phosphor_mask_help
<
    ui_label = " ";
    ui_text = "Defaults: Sony Trinitron and Neutral use Aperture Grille; Toshiba AF uses Slot Mask. Explicit mask selection changes only the mask; the display profile remains active.";
    ui_category = "Display Setup";
> = 0;

// IMAGE & COLOR -----------------------------------------------------------------

uniform float brightness <
    ui_type = "drag";
    ui_min = 0.5;
    ui_max = 2.0;
    ui_step = 0.01;
    ui_label = "Brightness";
    ui_category = "Image & Color";
> = 1.1;

uniform float contrast_curve <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
    ui_label = "Contrast Curve";
    ui_category = "Image & Color";
> = 1.0;

uniform float saturation <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
    ui_label = "Saturation";
    ui_category = "Image & Color";
> = 0.94;

uniform float crt_gamma <
    ui_type = "drag";
    ui_min = 2.2;
    ui_max = 2.6;
    ui_step = 0.01;
    ui_label = "Gamma";
    ui_category = "Image & Color";
    ui_tooltip = "Power-law approximation to CRT light output. The saved profile uses 2.2. The same curve is used by image and blur paths.";
> = 2.2;

uniform float black_level <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.1;
    ui_step = 0.001;
    ui_label = "Black Level";
    ui_category = "Image & Color";
    ui_tooltip = "Normalized input display-black reference used by the BT.1886-style EOTF. The filmic toe retains its saved 0.004 baseline and tracks changes to this control after the existing 1.25 input gain. 0.004 means 0.4% of reference white.";
> = 0.004;


// These spatial finishing controls are grouped with the image-level adjustments.
uniform float vignette_strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.5;
    ui_step = 0.05;
    ui_label = "Vignette Strength";
    ui_category = "Image & Color";
> = 0.5;

uniform int vignette_mapping <
    ui_type = "combo";
    ui_items = "Legacy Fit\0Symmetric Viewport\0";
    ui_label = "Vignette Mapping";
    ui_category = "Image & Color";
    ui_tooltip = "Symmetric Viewport (default) evaluates the vignette in normalized coordinates of DuckStation's active image viewport, giving matching falloff at all four image edges. Legacy Fit preserves the existing NewPixie-derived framing coordinates.";
> = 1;

uniform float fringe_amount <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 3.0;
    ui_step = 0.05;
    ui_label = "Color Fringing";
    ui_category = "Image & Color";
    ui_tooltip = "Offsets the red, green and blue source sampling positions slightly to approximate mild channel misregistration.";
> = 0.15;

uniform float edge_zoom <
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = 1.4;
    ui_step = 0.001;
    ui_label = "Edge Zoom";
    ui_category = "Image & Color";
    ui_tooltip = "Enlarges the displayed image within the active viewport, cropping the outer edges.";
> = 1.0;


// SOURCE IMAGE FILTERING ---------------------------------------------------------

// These controls filter the accumulated source image before the CRT beam treatment.
// Pixel Smoothing can use Edge-Aware reconstruction, symmetric Subpixel Blend, or both.
// Subpixel Blend is the saved default.
uniform int pixel_smoothing_mode <
    ui_type = "combo";
    ui_items = "Edge-Aware\0Subpixel Blend\0Hybrid\0";
    ui_label = "Pixel Smoothing Mode";
    ui_category = "Source Image Filtering";
    ui_tooltip = "Edge-Aware uses the current adaptive source-grid reconstruction. Subpixel Blend applies symmetric half-offset sampling on both axes and is the saved default. Hybrid combines edge-aware source reconstruction with the subpixel blend.";
> = 1;

uniform float pixel_smoothing <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
    ui_label = "Pixel Smoothing";
    ui_category = "Source Image Filtering";
    ui_tooltip = "Controls the strength of the selected Pixel Smoothing Mode. Edge-Aware blends source samples while protecting coherent edges; Subpixel Blend applies symmetric half-offset sampling; Hybrid combines both. Uses DuckStation’s internal render grid when available. This is source reconstruction, separate from the CRT beam spot. 0 disables Pixel Smoothing in every mode.";
> = 0.35;

uniform bool adjacent_tap_edge_blending <
    hidden = true;
    ui_type = "boolean";
    ui_label = "Adjacent-Tap Edge Blending";
    ui_category = "Source Image Filtering";
    ui_tooltip = "Experimental: applies a cached 2-column, 3-row edge-aware blend to the horizontal reconstruction taps immediately beside the centre tap. It can soften source-cell transition changes without additional texture fetches. Only affects Edge-Aware and Hybrid Pixel Smoothing modes; off preserves the existing reconstruction.";
> = false;

// Optional Gaussian source-pixel smoothing. These remain independent of Pixel Smoothing.
uniform float source_smooth_h <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.5;
    ui_step = 0.01;
    ui_label = "Horizontal Source-Pixel Smoothing";
    ui_category = "Source Image Filtering";
    ui_tooltip = "Adds horizontal Gaussian width to the source reconstruction, measured in fractions of a native game pixel and converted to the available internal sample grid. It combines with Horizontal Beam Spot Width in the same kernel. 0 disables this added width.";
> = 0.17;

uniform float source_smooth_v <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.5;
    ui_step = 0.01;
    ui_label = "Vertical Source-Pixel Smoothing";
    ui_category = "Source Image Filtering";
    ui_tooltip = "Adds vertical Gaussian width to the native-line source reconstruction, measured in fractions of a native raster line. It runs before the CRT beam. 0 disables this added width.";
> = 0.10;

// OPTIONAL SCREEN GEOMETRY ------------------------------------------------------
// Flat is intentionally the default; curvature is an optional display effect, not a requirement
// for the intended look. Curved profiles project the completed CRT image as one faceplate.
uniform int screen_geometry <
    ui_type = "combo";
    ui_items = "Flat\0Cylindrical\0Spherical\0Aspherical\0";
    ui_label = "CRT Surface Profile";
    ui_category = "Screen Geometry";
    ui_tooltip = "Flat bypasses projection. Cylindrical curves horizontally; Spherical uses a true spherical cap; Aspherical uses independent horizontal/vertical radii plus edge departure. Shared by all display color profiles.";
> = 0;

uniform float surface_radius <
    ui_type = "drag";
    ui_min = 2.0;
    ui_max = 40.0;
    ui_step = 0.1;
    ui_label = "Surface Radius";
    ui_category = "Screen Geometry";
    ui_tooltip = "Radius in screen half-widths. Used by Cylindrical and Spherical profiles. Smaller values produce stronger curvature.";
> = 8.0;

uniform float surface_radius_horizontal <
    hidden = true;
    ui_type = "drag";
    ui_min = 2.0;
    ui_max = 40.0;
    ui_step = 0.1;
    ui_label = "Aspherical Horizontal Radius";
    ui_category = "Screen Geometry";
    ui_tooltip = "Horizontal radius used only by the Aspherical profile. Smaller values produce stronger horizontal curvature.";
> = 6.0;

uniform float surface_radius_vertical <
    hidden = true;
    ui_type = "drag";
    ui_min = 2.0;
    ui_max = 40.0;
    ui_step = 0.1;
    ui_label = "Aspherical Vertical Radius";
    ui_category = "Screen Geometry";
    ui_tooltip = "Vertical radius used only by the Aspherical profile. Smaller values produce stronger vertical curvature. Its default differs from the horizontal radius so Aspherical is visibly distinct from Spherical.";
> = 12.0;

uniform float surface_aspheric_departure <
    hidden = true;
    ui_type = "drag";
    ui_min = -0.12;
    ui_max = 0.12;
    ui_step = 0.001;
    ui_label = "Aspheric Edge Departure";
    ui_category = "Screen Geometry";
    ui_tooltip = "Adds or subtracts higher-order depth at the faceplate perimeter. 0 keeps the toric base surface; positive values increase edge recession and negative values flatten it. Used only by Aspherical.";
> = 0.015;

uniform float camera_distance <
    ui_type = "drag";
    ui_min = 2.0;
    ui_max = 20.0;
    ui_step = 0.1;
    ui_label = "Virtual Camera Distance";
    ui_category = "Screen Geometry";
    ui_tooltip = "Distance from the virtual eye to the centre tangent plane, in screen half-widths. Smaller values exaggerate perspective; larger values approach an orthographic view.";
> = 4.0;

uniform float camera_horizontal_offset <
    ui_type = "drag";
    ui_min = -0.5;
    ui_max = 0.5;
    ui_step = 0.005;
    ui_label = "Virtual Camera Horizontal Offset";
    ui_category = "Screen Geometry";
    ui_tooltip = "Moves the virtual eye left/right relative to the CRT. Has no effect in Flat mode because a flat plane has no parallax.";
> = 0.0;

uniform float camera_vertical_offset <
    ui_type = "drag";
    ui_min = -0.5;
    ui_max = 0.5;
    ui_step = 0.005;
    ui_label = "Virtual Camera Vertical Offset";
    ui_category = "Screen Geometry";
    ui_tooltip = "Moves the virtual eye up/down relative to the CRT. Has no effect in Flat mode because a flat plane has no parallax.";
> = 0.0;

uniform float screen_corner_radius <
    hidden = true;
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.08;
    ui_step = 0.001;
    ui_label = "Screen Corner Radius";
    ui_category = "Screen Geometry";
    ui_tooltip = "Rounds the projected faceplate boundary. Measured as a fraction of the shorter image dimension. 0 gives square corners; applies to curved profiles.";
> = 0.02;

uniform int geometry_antialiasing <
    ui_type = "combo";
    ui_items = "Bilinear (1 tap)\0Adaptive up to 4 taps\0Adaptive up to 8 taps\0";
    ui_label = "Geometry Reconstruction";
    ui_category = "Screen Geometry";
    ui_tooltip = "Derivative-driven anisotropic reconstruction. Tap count grows with the projected source footprint and is capped at 4 or 8; it stays at one bilinear tap when the geometry does not minify the image.";
> = 0;

// SCANLINES & BEAM --------------------------------------------------------------

// Retained as a hidden compatibility gate. The UI now uses Scanline Strength = 0
// as its sole visible way to disable beam modulation; this default remains enabled.
uniform bool scanlines_enabled <
    hidden = true;
    ui_type = "boolean";
    ui_label = "Enable Scanlines";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Hidden compatibility master gate. The visible Scanline Strength control can disable vertical beam modulation by setting it to 0.";
> = true;

uniform int scanline_profile <
    hidden = true;
    ui_type = "combo";
    ui_items = "Sine\0Gaussian Beam\0";
    ui_label = "Scanline Beam Profile";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Hidden profile selector. Sine preserves the earlier waveform; Gaussian Beam uses the localized beam model. Gaussian Beam is the default and is the only profile exposed in the UI legend.";
> = 1;

uniform float scanline_strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.05;
    ui_label = "Scanline Strength";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Controls the strength of the Gaussian beam modulation. Set to 0 to disable vertical beam modulation; phosphor masks and damping wires remain active.";
> = 1.7;

uniform int fixed_beam_shape_help <
    ui_label = " ";
    ui_text = "Active defaults: Gaussian Beam scanlines, Gaussian spot kernel and Single Lobe horizontal spot.";
    ui_category = "Scanlines & Beam";
> = 0;


uniform int beam_spot_profile <
    hidden = true;
    ui_type = "combo";
    ui_items = "Gaussian\0Super-Gaussian\0Lorentzian\0";
    ui_label = "Beam Spot Profile";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Hidden profile selector shared by the horizontal source-cell spot kernel and Gaussian-family vertical beam. Gaussian is the default; Super-Gaussian has a flatter centre and sharper shoulders; Lorentzian has longer tails.";
> = 0;

uniform int horizontal_spot_structure <
    hidden = true;
    ui_type = "combo";
    ui_items = "Single Lobe\0Core + Tail\0";
    ui_label = "Horizontal Spot Structure";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Hidden structure selector. Core + Tail redistributes a selected fraction of spot energy into a wider component. Single Lobe is the default.";
> = 0;

uniform float horizontal_spot_tail_energy <
    hidden = true;
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 10.0;
    ui_step = 0.25;
    ui_label = "Horizontal Spot Tail Energy (%)";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Hidden Core + Tail parameter: percentage of horizontal spot energy redistributed from the core into the wider tail. Default 2%.";
> = 2.0;

uniform float horizontal_spot_tail_width <
    hidden = true;
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = 4.0;
    ui_step = 0.05;
    ui_label = "Horizontal Spot Tail Width (x)";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Hidden Core + Tail parameter: tail sigma as a multiplier of the core sigma. Default 2x.";
> = 2.0;

uniform int vertical_beam_model <
    ui_type = "combo";
    ui_items = "Shared Beam\0Per-source-line RGB\0";
    ui_label = "Vertical Beam Model";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Shared Beam derives one vertical beam from source luminance. Per-source-line RGB samples nearby source-line centres independently and derives separate red, green and blue beam contributions.";
> = 0;

uniform int per_source_line_attenuation_stage <
    ui_type = "combo";
    ui_items = "Source-Domain\0Post-Display (Shared Beam-aligned)\0";
    ui_label = "Per-source-line RGB Attenuation";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Only affects Per-source-line RGB. Source-Domain (default) applies RGB attenuation before ghosting and the display transforms. Post-Display applies its channel-specific factor after display color, contrast, saturation and vignette, alongside Shared Beam. Field-Phase Flicker forces Post-Display while active.";
> = 0;

uniform float scanline_sharpness <
    ui_type = "drag";
    ui_min = 0.5;
    ui_max = 3.0;
    ui_step = 0.05;
    ui_label = "Vertical Beam Sharpness";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Controls the Gaussian vertical beam sigma; higher values produce a narrower spot.";
> = 1.0;

uniform float scanline_beam <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.05;
    ui_label = "Scanline Beam Widening";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Controls brightness-dependent vertical beam widening. Beam Current Response shapes the drive-to-widening relationship.";
> = 0.75;

uniform float beam_current_response <
    ui_type = "drag";
    ui_min = 0.5;
    ui_max = 2.0;
    ui_step = 0.05;
    ui_label = "Beam Current Response";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Shared Beam uses source luminance; Per-source-line RGB uses each line's corresponding channel drive. This exponent controls how drive widens the vertical beam; 1 is linear.";
> = 0.50;

uniform float beam_average_drive <
    ui_type = "drag";
    ui_min = 0.1;
    ui_max = 1.0;
    ui_step = 0.01;
    ui_label = "Beam Average Drive";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Sets the mean linear output of the normalized vertical Gaussian beam at full scanline strength.";
> = 0.15;

uniform float beam_horizontal_spot <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.05;
    ui_label = "Horizontal Beam Spot Width";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Horizontal Gaussian spot sigma in output pixels at 1080p. Scales with output height and combines with Horizontal Source-Pixel Smoothing in the source reconstruction kernel.";
> = 0.15;

uniform float scanline_lines <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 625.0;
    ui_step = 1.0;
    ui_label = "Manual Scanline Density";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Sets the spatial density of the vertical beam pattern. Higher values produce more closely spaced scanlines; 0 uses the original NewPixie pitch, which varies with output resolution. This is not a refresh-rate setting and is ignored when Match Scanlines to Native Resolution is enabled with valid DuckStation native dimensions.";
> = 340.0;

uniform bool native_scanline_pitch <
    ui_type = "boolean";
    ui_label = "Match Scanlines to Native Resolution";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Derives vertical beam spacing from DuckStation's native raster height (NativeHeight), mapped to the active viewport; it does not use enhanced internal resolution or monitor refresh rate. When valid native dimensions are available, this overrides Manual Scanline Density; otherwise manual or stock pitch is used.";
> = false;

uniform bool interlace <
    ui_type = "boolean";
    ui_label = "Alternating Field Phase";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Alternates Gaussian beam phase on odd/even rendered frames. This is a procedural phase shift, not true 480i field reconstruction.";
> = true;

uniform bool scanroll <
    ui_type = "boolean";
    ui_label = "Rolling Scanlines";
    ui_category = "Scanlines & Beam";
    ui_tooltip = "Continuously moves the Gaussian beam phase using elapsed time. Disable it to isolate Alternating Field Phase.";
> = true;

// 12 user-adjustable Scanlines & Beam settings. Hidden profile defaults are Gaussian Beam /
// Gaussian / Single Lobe; alternative implementations remain available in the source.

// DuckStation supplies the active native raster dimensions and final viewport.
// These are runtime source uniforms, not additional DuckStation UI controls.
uniform float NativeWidth < source = "nativewidth"; >;
uniform float NativeHeight < source = "nativeheight"; >;
// The internal render dimensions can exceed the PS1 native raster when enhanced
// resolution is enabled. Source reconstruction uses these dimensions when available;
// CRT scanline pitch remains tied to NativeWidth/NativeHeight.
uniform float InternalWidth < source = "internalwidth"; >;
uniform float InternalHeight < source = "internalheight"; >;
uniform float2 ViewportOffset < source = "viewportoffset"; >;
uniform float2 ViewportSize < source = "viewportsize"; >;

// NOISE & GRAIN -----------------------------------------------------------------
// Grain can follow output pixels or the native source raster, and can adapt to local detail/color.

uniform float noise_amount <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.10;
    ui_step = 0.001;
    ui_label = "Noise Amount";
    ui_category = "Noise & Grain";
    ui_tooltip = "Controls animated grain amplitude. Before final clipping, per-channel noise has a standard deviation of about 0.3 times this value. 0 disables grain.";
> = 0.06;

uniform float noise_luminance_adaptation <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.05;
    ui_label = "Luminance Adaptation";
    ui_category = "Noise & Grain";
    ui_tooltip = "Controls how strongly grain is reduced in darker areas. 0 applies uniform grain; 1 strongly suppresses grain in shadows and midtones while keeping full strength at white.";
> = 0.15;

uniform bool headroom_aware_grain <
    hidden = true;
    ui_type = "boolean";
    ui_label = "Headroom-Aware Grain";
    ui_category = "Noise & Grain";
    ui_tooltip = "Scales each grain excursion symmetrically to the available distance from black and white before adding it. This prevents one-sided clipping at the SDR output limits and reduces grain near the extremes. Off preserves the existing grain response.";
> = true;

uniform float noise_chroma <
    hidden = true;
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
    ui_label = "Grain Chroma";
    ui_category = "Noise & Grain";
    ui_tooltip = "0 uses the same neutral grain variation for all RGB channels; 1 uses independent RGB grain. Intermediate values blend between them while approximately preserving noise strength. Image-Aware Chroma can modulate this by the underlying image color.";
> = 0.71;

uniform float noise_animation_speed <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.05;
    ui_label = "Grain Animation Speed";
    ui_category = "Noise & Grain";
    ui_tooltip = "1 advances the grain field at 60 patterns per second; 0 freezes it. Intermediate values slow its evolution with smooth temporal blending. The animation rate is independent of the render frame rate.";
> = 1.0;

uniform float noise_grain_size <
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = 4.0;
    ui_step = 0.05;
    ui_label = "Grain Size";
    ui_category = "Noise & Grain";
    ui_tooltip = "1 uses one cell of the selected Grain Alignment grid. Larger values create broader, smoothly interpolated grain rather than enlarged square noise blocks. Noise variance is normalized to keep Noise Amount broadly comparable.";
> = 1.0;

uniform int noise_alignment <
    ui_type = "combo";
    ui_items = "Output Pixels\0Native Game Pixels\0Mixed\0";
    ui_label = "Grain Alignment";
    ui_category = "Noise & Grain";
    ui_tooltip = "Output Pixels keeps the current screen-resolution grain. Native Game Pixels anchors the pattern to DuckStation's source raster. Mixed combines independent fields from both grids.";
> = 0;

uniform float noise_detail_protection <
    hidden = true;
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.05;
    ui_label = "Detail Protection";
    ui_category = "Noise & Grain";
    ui_tooltip = "Reduces grain around high-contrast native-pixel details and outlines. 0 disables protection; higher values preserve fine image detail by lowering grain in locally busy areas.";
> = 0.50;

uniform float noise_color_awareness <
    hidden = true;
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.05;
    ui_label = "Image-Aware Chroma";
    ui_category = "Noise & Grain";
    ui_tooltip = "Adapts Grain Chroma to the rendered color. Near-neutral areas receive mostly monochromatic grain; moderately colored areas retain chroma, while highly saturated details get gentler color variation. 0 disables this adaptation.";
> = 0.25;

// SIGNAL & TEMPORAL EFFECTS ------------------------------------------------------
// These follow Noise & Grain in the UI. The final flicker remains implemented but hidden.
uniform float acc_modulate <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.99;
    ui_step = 0.01;
    ui_label = "Temporal Trail Persistence";
    ui_category = "Signal & Temporal Effects";
    ui_tooltip = "Fraction of previous-frame linear light retained where the picture got darker. 0 disables trails; higher values need retuning compared with the original encoded-domain accumulation.";
> = 0.0;

uniform bool history_reset <
    ui_type = "boolean";
    ui_label = "Reset History";
    ui_category = "Signal & Temporal Effects";
    ui_tooltip = "Hold on to clear temporal history; toggle on/off after a target resize. First frame is cleared automatically.";
> = false;

uniform float interference_strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
    ui_label = "Interference Strength";
    ui_category = "Signal & Temporal Effects";
    ui_tooltip = "Controls the animated horizontal signal wobble. 0 disables it; 1 uses the original effect strength.";
> = 0.0;

uniform float interference_speed <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 3.0;
    ui_step = 0.05;
    ui_label = "Interference Speed";
    ui_category = "Signal & Temporal Effects";
    ui_tooltip = "Controls how quickly the wobble moves. 1 preserves the original animation speed; 0 freezes its phase.";
> = 1.0;

uniform float flicker_amount <
    hidden = true;
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.03;
    ui_step = 0.001;
    ui_label = "Flicker Amount";
    ui_category = "Signal & Temporal Effects";
    ui_tooltip = "Hidden fixed aesthetic brightness modulation. Retained for implementation continuity; not the Field-Phase Flicker effect.";
> = 0.003;

// GLOW & GHOSTING --------------------------------------------------------

uniform float blur_x <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 5.0;
    ui_step = 0.25;
    ui_label = "Horizontal Blur";
    ui_category = "Glow & Ghosting";
> = 0.5;

uniform float blur_y <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 5.0;
    ui_step = 0.25;
    ui_label = "Vertical Blur";
    ui_category = "Glow & Ghosting";
> = 0.5;

uniform float ghost_strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 3.0;
    ui_step = 0.05;
    ui_label = "Ghost Strength";
    ui_category = "Glow & Ghosting";
> = 0.6;

uniform float halation_strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.05;
    ui_label = "Halation Strength";
    ui_category = "Glow & Ghosting";
    ui_tooltip = "Adds glow from highlights emitted by the completed CRT phosphor image. Set to 0 to disable.";
> = 0.15;

uniform bool halation_respects_scanlines <
    ui_type = "boolean";
    ui_label = "Halation Respects Scanlines";
    ui_category = "Glow & Ghosting";
    ui_tooltip = "Off: optical halation spreads into scanline gaps (recommended). On: the blurred glow is attenuated by the local scanline pattern.";
> = false;

uniform float halation_threshold <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.99;
    ui_step = 0.01;
    ui_label = "Halation Threshold";
    ui_category = "Glow & Ghosting";
    ui_tooltip = "Linear-light luminance cutoff. Contribution rises smoothly from zero at this threshold to full strength at white.";
> = 0.8;

uniform float halation_warmth <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.05;
    ui_label = "Halation Warmth";
    ui_category = "Glow & Ghosting";
    ui_tooltip = "0 is neutral white; 1 gives the glow a warm amber tint.";
> = 0.3;

// BLOOM -------------------------------------------------------------------------

uniform float bloom_intensity <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.05;
    ui_label = "Bloom Intensity";
    ui_category = "Bloom";
    ui_tooltip = "Wide, colored highlight spill over the phosphor image. It stacks with Halation, so lower Halation if the combined glow gets too strong. Set to 0 to disable bloom.";
> = 0.15;

uniform float bloom_threshold <
    ui_type = "drag";
    ui_min = 0.25;
    ui_max = 8.0;
    ui_step = 0.05;
    ui_label = "Bloom Threshold";
    ui_category = "Bloom";
    ui_tooltip = "Linear-light maximum RGB-channel value where bloom starts. This catches saturated red, blue and purple highlights as well as white; higher values restrict bloom to stronger peaks.";
> = 4.0;

uniform float bloom_soft_knee <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.05;
    ui_label = "Bloom Soft Knee";
    ui_category = "Bloom";
    ui_tooltip = "Softens the threshold transition. 0 is a hard cutoff; higher values bring in highlights more gradually.";
> = 0.15;

uniform float bloom_radius <
    ui_type = "drag";
    ui_min = 4.0;
    ui_max = 64.0;
    ui_step = 1.0;
    ui_label = "Bloom Radius (pixels at 1080p)";
    ui_category = "Bloom";
    ui_tooltip = "Approximate maximum blur reach on each axis at 1080p. Scales with output height; highlights are prefiltered to quarter resolution before a separable Gaussian blur.";
> = 8.0;

// PHOSPHOR MASK SETTINGS -------------------------------------------------------
// Profile defaults use built-in mask constants. The editable groups below apply
// when the corresponding mask is explicitly selected in Display Setup.

uniform int phosphor_mask_settings_help <
    ui_label = " ";
    ui_text = "To customize a phosphor mask, select Aperture Grille, Slot Mask or Staggered Shadow Mask under Display Setup → Phosphor Mask Type. Use Display Profile Default to retain the selected profile's predefined mask and settings.";
    ui_category = "Phosphor Mask Settings";
    ui_category_closed = true;
> = 0;

uniform int aperture_grille_group_label <
    ui_label = " ";
    ui_text = "- Aperture Grille -";
    ui_category = "Phosphor Mask Settings";
> = 0;

uniform float aperture_custom_strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.5;
    ui_step = 0.001;
    ui_label = "Mask Strength (Custom)";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Aperture-grille-only strength. Used when Aperture Grille is explicitly selected in Display Setup → Phosphor Mask Type.";
> = 0.24;

uniform float aperture_custom_pitch <
    ui_type = "drag";
    ui_min = 1.5;
    ui_max = 12.0;
    ui_step = 0.25;
    ui_label = "Triad Pitch (pixels at 1080p)";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Aperture-grille-only RGB triad pitch, scaled with active viewport height. The rendered triplet period is kept at least 3 output pixels to avoid low-resolution color aliasing.";
> = 3.0;

uniform float aperture_custom_stripe_width <
    ui_type = "drag";
    ui_min = 0.5;
    ui_max = 1.0;
    ui_step = 0.01;
    ui_label = "Stripe / Aperture Width";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Aperture-grille-only emitting width as a fraction of one RGB cell.";
> = 0.95;

uniform float aperture_custom_gap <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.5;
    ui_step = 0.01;
    ui_label = "Inter-Stripe Gap";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Minimum dark separation between aperture-grille phosphor stripes, as a fraction of one RGB cell.";
> = 0.10;

uniform bool aperture_custom_damper_wires <
    ui_type = "boolean";
    ui_label = "Show Grille Damping Wires";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Two subtle horizontal support wires, present on many but not all aperture-grille tubes.";
> = false;

uniform float aperture_custom_wire_strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.2;
    ui_step = 0.001;
    ui_label = "Damping Wire Strength";
    ui_category = "Phosphor Mask Settings";
> = 0.05;

uniform int slot_mask_group_label <
    ui_label = " ";
    ui_text = "- Slot Mask -";
    ui_category = "Phosphor Mask Settings";
> = 0;

uniform float slot_custom_strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.5;
    ui_step = 0.001;
    ui_label = "Mask Strength (Custom)";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Slot-mask-only strength. Used when Slot Mask is explicitly selected in Display Setup → Phosphor Mask Type.";
> = 0.4;

uniform float slot_custom_pitch <
    ui_type = "drag";
    ui_min = 1.5;
    ui_max = 12.0;
    ui_step = 0.25;
    ui_label = "Triad Pitch (pixels at 1080p)";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Slot-mask-only RGB triad pitch, scaled with output height. Used when Slot Mask is explicitly selected.";
> = 4.0;

uniform float slot_custom_stripe_width <
    ui_type = "drag";
    ui_min = 0.5;
    ui_max = 1.0;
    ui_step = 0.01;
    ui_label = "Slot Width";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Width of each emitting vertical color slot, as a fraction of one RGB cell.";
> = 0.6;

uniform float slot_custom_gap <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.5;
    ui_step = 0.01;
    ui_label = "Inter-Slot Gap";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Minimum dark separation between adjacent color slots, as a fraction of one RGB cell.";
> = 0.5;

uniform float slot_custom_height <
    ui_type = "drag";
    ui_min = 0.25;
    ui_max = 1.0;
    ui_step = 0.01;
    ui_label = "Slot Height";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Vertical emitting height of each slot, as a fraction of its row cell. 1 fills the full row cell vertically.";
> = 1.0;

uniform int staggered_shadow_mask_group_label <
    ui_label = " ";
    ui_text = "- Staggered Shadow Mask -";
    ui_category = "Phosphor Mask Settings";
> = 0;

uniform float shadow_custom_strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.5;
    ui_step = 0.001;
    ui_label = "Mask Strength (Custom)";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Staggered-shadow-mask-only strength. Used when Shadow Mask (Staggered Dots) is explicitly selected in Display Setup → Phosphor Mask Type.";
> = 0.24;

uniform float shadow_custom_pitch <
    ui_type = "drag";
    ui_min = 1.5;
    ui_max = 12.0;
    ui_step = 0.25;
    ui_label = "Triad Pitch (pixels at 1080p)";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Staggered-shadow-mask-only RGB triad pitch, scaled with output height.";
> = 3.0;

uniform float shadow_custom_dot_width <
    ui_type = "drag";
    ui_min = 0.5;
    ui_max = 1.0;
    ui_step = 0.01;
    ui_label = "Dot Width";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Controls the horizontal size of the staggered phosphor dots.";
> = 0.95;

uniform float shadow_custom_gap <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.5;
    ui_step = 0.01;
    ui_label = "Dot Gap";
    ui_category = "Phosphor Mask Settings";
    ui_tooltip = "Minimum dark separation between the dots, as a fraction of one RGB cell.";
> = 0.10;

// EXPERIMENTAL ------------------------------------------------------------------

uniform bool field_phase_flicker <
    ui_type = "boolean";
    ui_label = "Field-Phase Flicker";
    ui_category = "Experimental";
    ui_tooltip = "Overrides every Scanlines & Beam setting while enabled. Uses that section's saved defaults, but forces Gaussian Beam with Per-source-line RGB, Post-Display (Shared Beam-aligned) attenuation, Rolling Scanlines off and Alternating Field Phase on. FCount parity switches the phase between 0 and π on successive rendered frames—a half-period shift that redistributes neighbouring source-line beam contributions. This creates a pronounced CRT-like flicker that can look like a very fast top-to-bottom flicker. The whole pattern changes phase globally; it is not a physical beam sweep or true 480i. Other image settings affect its appearance, not its timing. Experiment with it in motion and consider viewing comfort: it may cause eye strain or dizziness. Off by default.";
> = false;

uniform int field_phase_flicker_help <
    ui_label = " ";
    ui_text = "Enable for a very fast, pronounced CRT-like flicker. It may cause eye strain or dizziness; use at your discretion.";
    ui_category = "Experimental";
> = 0;

// Field-Phase Flicker pins the 12 user-adjustable Scanlines & Beam controls to their
// documented saved defaults, then applies its explicit model/phase overrides. The beam
// profile, spot kernel and horizontal structure default to Gaussian Beam / Gaussian / Single Lobe.
#define PX_SCANLINES_ENABLED          (field_phase_flicker ? true  : scanlines_enabled)
#define PX_SCANLINE_PROFILE             (field_phase_flicker ? 1     : scanline_profile)
#define PX_SCANLINE_STRENGTH           (field_phase_flicker ? 1.7   : scanline_strength)
#define PX_SCANLINE_SHARPNESS          (field_phase_flicker ? 1.0   : scanline_sharpness)
#define PX_SCANLINE_BEAM               (field_phase_flicker ? 0.75  : scanline_beam)
#define PX_BEAM_SPOT_PROFILE             (field_phase_flicker ? 0     : beam_spot_profile)
#define PX_HORIZONTAL_SPOT_STRUCTURE    (field_phase_flicker ? 0     : horizontal_spot_structure)
#define PX_HORIZONTAL_SPOT_TAIL_ENERGY  (field_phase_flicker ? 2.0   : horizontal_spot_tail_energy)
#define PX_HORIZONTAL_SPOT_TAIL_WIDTH   (field_phase_flicker ? 2.0   : horizontal_spot_tail_width)
#define PX_VERTICAL_BEAM_MODEL         (field_phase_flicker ? 1     : vertical_beam_model)
#define PX_PER_SOURCE_LINE_ATTENUATION_STAGE (field_phase_flicker ? 1 : per_source_line_attenuation_stage)
#define PX_BEAM_HORIZONTAL_SPOT        (field_phase_flicker ? 0.15  : beam_horizontal_spot)
#define PX_BEAM_CURRENT_RESPONSE       (field_phase_flicker ? 0.50  : beam_current_response)
#define PX_BEAM_AVERAGE_DRIVE          (field_phase_flicker ? 0.15  : beam_average_drive)
#define PX_SCANLINE_LINES              (field_phase_flicker ? 340.0 : scanline_lines)
#define PX_NATIVE_SCANLINE_PITCH       (field_phase_flicker ? false : native_scanline_pitch)
#define PX_INTERLACE                   (field_phase_flicker ? true  : interlace)
#define PX_SCANROLL                    (field_phase_flicker ? false : scanroll)

// DIAGNOSTICS -------------------------------------------------------------------

uniform int debug_view <
    ui_type = "combo";
    ui_items = "Off\0Accumulated Frame (Linear)\0Current Input (Encoded)\0Trail Only (Linear x4)\0Counter and Toggle Test\0Phosphor Mask Only\0CRT Scene (Display View, No Bloom)\0Bloom Blur (x4)\0Bloom Extract (x4)\0Horizontal Source Reconstruction\0Vertical Source Reconstruction\0Source Detail Confidence\0Source Ghost Blur (x4)\0Scanline / Beam Factor\0Halation Bright Pass (x4)\0Halation Horizontal Blur (x4)\0Halation Blur (x4)\0Vignette Falloff\0CRT Surface Coverage\0Phosphor Mask + Damping Wires\0CRT Scene (Linear, Pre-Glow)\0";
    ui_label = "Debug View";
    ui_category = "Diagnostics";
    ui_tooltip = "Inspect source reconstruction, detail confidence, temporal history, ghosting, beam attenuation, phosphor masks, geometry, vignette, halation and bloom. Intermediate linear-light views are tone-mapped or amplified where needed for visibility. See README.md for the full view list.";
> = 0;

uniform int debug_view_help <
    ui_label = " ";
    ui_text = "Diagnostics are temporary inspection views; set Debug View to Off to restore the normal image.";
    ui_category = "Diagnostics";
> = 0;

// BT.1886-style EOTF with configurable gamma and normalized black level, assuming normalized
// display white LW=1. L(0)=black_level and L(1)=1.0. The user-facing range is constrained to keep
// the SDR working path bounded; this is an EOTF approximation, not source-transfer detection.
float3 decode_crt_eotf(float3 signal)
{
    float gamma = clamp(crt_gamma, 2.2, 2.6);
    float lb = clamp(black_level, 0.0, 0.1);
    float lb_root = pow(lb, 1.0 / gamma);

    // Algebraically equivalent to the BT.1886-style a*(V+b)^gamma form, but
    // written as one interpolation between the black and white signal roots.
    // This avoids the large intermediate b when black_level approaches its limit.
    float3 v = saturate(max(signal, float3(0.0, 0.0, 0.0)));
    float3 normalized_drive = lerp(lb_root.xxx, float3(1.0, 1.0, 1.0), v);
    return pow(normalized_drive, gamma);
}

// Dedicated linear-light temporal history. DuckStation keeps named render targets between frames,
// but a newly created/reallocated target is not guaranteed to be initialized. FCount clears frame 1;
// the manual reset remains useful after later resizes. There is no reliable FX-only way to detect
// arbitrary uninitialized finite values that happen to resemble valid linear-light pixels.
texture2D tAccTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; };
sampler sAccTex { Texture = tAccTex; AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };

// Current-frame linear-light accumulation target. tAccTex is prior-frame history;
// tAccumFrame is this frame's accumulated image. Explicit targets avoid relying on implicit
// backbuffer ping-pong behavior.
texture2D tAccumFrame { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; };
sampler sAccumFrame { Texture = tAccumFrame; AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };

// Separable source/beam smoothing buffers. The H target carries X edge validity; the V target
// completes Y validity. Both stay in the same linear-light domain as tAccumFrame.
texture2D tSmoothH { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; };
sampler sSmoothH { Texture = tSmoothH; AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };
texture2D tSmoothV { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; };
sampler sSmoothV { Texture = tSmoothV; AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };

// Save this frame's accumulated result into temporal history after the Accum pass has completed.
float4 PrevColor(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    return tex2D(sAccumFrame, uv);
}

float4 PS_AccumulateFrame(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    float4 history = tex2D(sAccTex, uv.xy);
    // Linear history includes the preserved 1.25 beam-drive gain, so valid RGB can reach 1.25.
    // Values above 1.5 are outside this shader's SDR working range and are treated as stale/bad.
    bool invalid_history = any(isnan(history)) || any(isinf(history)) ||
        any(history < float4(0.0, 0.0, 0.0, 0.0)) ||
        any(history > float4(1.5, 1.5, 1.5, 1.0));
    history = invalid_history
        ? float4(0.0, 0.0, 0.0, 0.0)
        : history;

    // m_frame_count starts at 0 and DuckStation increments it at the start of Apply(), before
    // updating source uniforms. Therefore frame 1 is a reliable first-frame clear on a new shader.
    if (history_reset || FCount <= 1)
        history = float4(0.0, 0.0, 0.0, 0.0);

    history *= acc_modulate;

    // Decode once here. Both temporal history and the current-frame target are linear-light
    // RGB from this point onward. Preserve NewPixie's original 1.25 beam-drive gain here so the
    // main image and pre-CRT ghost blur share the same scale.
    float4 current = tex2D(ReShade::BackBuffer, uv.xy);
    current.rgb = decode_crt_eotf(current.rgb) * 1.25;
    current.a = 1.0;

    // Keep current-frame brightness intact. Retention only affects older, brighter pixels after
    // they move away; a static image should not darken just because persistence is enabled.
    return max(history, current);
}

// Full-resolution Gaussian scratch buffers are reused in two sequential stages:
// before the CRT scene, they hold the source-image blur used for ghosting; after the CRT
// scene is rendered, they hold the bright-pass blur used for post-phosphor optical halation.
// Both stages use the existing blur radius and avoid adding another full-resolution target.
texture GaussianBlurTemp { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; };
sampler GaussianBlurTempSampler { Texture = GaussianBlurTemp; AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };

texture GaussianBlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; };
sampler GaussianBlurSampler { Texture = GaussianBlurTex; AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };

// The CRT scene is stored before the filmic roll-off. RGBA16F halves scene-target bandwidth and
// storage versus RGBA32F; it retains ample precision for this SDR-oriented image path.
texture2D tCrtScene { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; };
sampler sCrtScene { Texture = tCrtScene; AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };

// Bloom is downsampled with a 4x4 source-pixel prefilter, then blurred at quarter width/height.
// Two small FP16 targets provide a safe ping-pong chain without overwriting the full-res
// ghosting/halation buffers or adding full-resolution bloom bandwidth.
texture2D tBloomA { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16f; };
sampler sBloomA { Texture = tBloomA; AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };
texture2D tBloomB { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16f; };
sampler sBloomB { Texture = tBloomB; AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };

// The first blur stage supplies the full-image linear-light signal used by ghosting. The same
// scratch targets are overwritten after PS_RenderCRTScene with the completed scene's halation.

float4 SampleAccumFrameLinear(float2 uv)
{
    // Accumulation already decoded the source and applied the beam-drive gain.
    float4 c = tex2D(sAccumFrame, uv);

    // This is the horizontal pass: mask only X here. Y validity is applied by the vertical
    // pass below. Applying both axes in both passes would square the Y edge fade.
    float inside_x = (uv.x >= 0.0 && uv.x <= 1.0) ? 1.0 : 0.0;
    float pixels_from_edge_x = min(uv.x, 1.0 - uv.x) / ReShade::PixelSize.x;
    float edge_valid_x = inside_x * saturate(pixels_from_edge_x + 0.5);

    c.rgb *= edge_valid_x;
    c.a = 0.0; // This pre-scene blur is used only for RGB ghosting.
    return c;
}

float4 PS_GaussianBlurHorizontal(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    if (ghost_strength <= 0.00001)
        return float4(0.0, 0.0, 0.0, 0.0);
    if (blur_x <= 0.00001)
        return SampleAccumFrameLinear(uv);

    float2 stp = float2(blur_x, 0.0) * ReShade::PixelSize.xy;
    bool pairable = abs(blur_x - 0.5) < 0.0001 || abs(blur_x - 1.0) < 0.0001;
    bool safe_pair_region = uv.x > (4.0 * stp.x + 2.0 * ReShade::PixelSize.x)
        && uv.x < (1.0 - 4.0 * stp.x - 2.0 * ReShade::PixelSize.x);
    if (pairable && safe_pair_region)
    {
        // Exact bilinear pairing of taps +/-1,+/-2 and +/-3,+/-4.
        float4 paired = SampleAccumFrameLinear(uv) * 0.2270270270;
        paired += SampleAccumFrameLinear(uv - 1.3846153846 * stp) * 0.3162162162;
        paired += SampleAccumFrameLinear(uv + 1.3846153846 * stp) * 0.3162162162;
        paired += SampleAccumFrameLinear(uv - 3.2307692308 * stp) * 0.0702702703;
        paired += SampleAccumFrameLinear(uv + 3.2307692308 * stp) * 0.0702702703;
        return paired;
    }

    float4 sum = SampleAccumFrameLinear(uv) * 0.2270270270;
    sum += SampleAccumFrameLinear(uv - 4.0 * stp) * 0.0162162162;
    sum += SampleAccumFrameLinear(uv - 3.0 * stp) * 0.0540540541;
    sum += SampleAccumFrameLinear(uv - 2.0 * stp) * 0.1216216216;
    sum += SampleAccumFrameLinear(uv - 1.0 * stp) * 0.1945945946;
    sum += SampleAccumFrameLinear(uv + 1.0 * stp) * 0.1945945946;
    sum += SampleAccumFrameLinear(uv + 2.0 * stp) * 0.1216216216;
    sum += SampleAccumFrameLinear(uv + 3.0 * stp) * 0.0540540541;
    sum += SampleAccumFrameLinear(uv + 4.0 * stp) * 0.0162162162;
    return sum;
}

// The horizontal pass already handled X; this helper masks only Y to avoid applying the
// horizontal edge factor twice. It also rejects taps beyond the source image boundary.
float blur_valid_y(float y)
{
    float inside = (y >= 0.0 && y <= 1.0) ? 1.0 : 0.0;
    float pixels_from_edge = min(y, 1.0 - y) / ReShade::PixelSize.y;
    return inside * saturate(pixels_from_edge + 0.5);
}

float4 PS_GaussianBlurVertical(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    if (ghost_strength <= 0.00001)
        return float4(0.0, 0.0, 0.0, 0.0);
    if (blur_y <= 0.00001)
        return tex2D(GaussianBlurTempSampler, uv)
            * blur_valid_y(uv.y);

    float2 stp = float2(0.0, blur_y) * ReShade::PixelSize.xy;
    bool pairable = abs(blur_y - 0.5) < 0.0001 || abs(blur_y - 1.0) < 0.0001;
    bool safe_pair_region = uv.y > (4.0 * stp.y + 2.0 * ReShade::PixelSize.y)
        && uv.y < (1.0 - 4.0 * stp.y - 2.0 * ReShade::PixelSize.y);
    if (pairable && safe_pair_region)
    {
        float4 paired = tex2D(GaussianBlurTempSampler, uv) * 0.2270270270;
        paired += tex2D(GaussianBlurTempSampler, uv - 1.3846153846 * stp) * 0.3162162162;
        paired += tex2D(GaussianBlurTempSampler, uv + 1.3846153846 * stp) * 0.3162162162;
        paired += tex2D(GaussianBlurTempSampler, uv - 3.2307692308 * stp) * 0.0702702703;
        paired += tex2D(GaussianBlurTempSampler, uv + 3.2307692308 * stp) * 0.0702702703;
        return paired;
    }

    float2 tap = uv;
    float4 sum = tex2D(GaussianBlurTempSampler, tap)
        * (0.2270270270 * blur_valid_y(tap.y));
    tap = uv - 4.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap) * (0.0162162162 * blur_valid_y(tap.y));
    tap = uv - 3.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap) * (0.0540540541 * blur_valid_y(tap.y));
    tap = uv - 2.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap) * (0.1216216216 * blur_valid_y(tap.y));
    tap = uv - 1.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap) * (0.1945945946 * blur_valid_y(tap.y));
    tap = uv + 1.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap) * (0.1945945946 * blur_valid_y(tap.y));
    tap = uv + 2.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap) * (0.1216216216 * blur_valid_y(tap.y));
    tap = uv + 3.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap) * (0.0540540541 * blur_valid_y(tap.y));
    tap = uv + 4.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap) * (0.0162162162 * blur_valid_y(tap.y));
    return sum;
}

float edge_mask(float2 suv)
{
    float inside = (suv.x >= 0.0 && suv.x <= 1.0 &&
                    suv.y >= 0.0 && suv.y <= 1.0) ? 1.0 : 0.0;
    float2 pixels_from_edge = min(suv, 1.0 - suv) / ReShade::PixelSize.xy;
    float2 m = saturate((pixels_from_edge + 0.5) / max(edge_feather, 1.0));
    return inside * m.x * m.y;
}


float beam_profile_value(float normalized_distance, int profile)
{
    float x = abs(normalized_distance);
    if (profile == 1)
    {
        float x2 = x * x;
        return exp(-0.5 * x2 * x2); // Super-Gaussian: flatter centre, sharper shoulders.
    }
    if (profile == 2)
        return 1.0 / (1.0 + x * x);      // Lorentzian: broader tails.
    return exp(-0.5 * x * x);            // Gaussian.
}

float beam_erf_approx(float x)
{
    float ax = abs(x);
    float t = 1.0 / (1.0 + 0.5 * ax);
    float tau = t * exp(-ax * ax - 1.26551223 + t * (
        1.00002368 + t * (0.37409196 + t * (0.09678418 + t * (
       -0.18628806 + t * (0.27886807 + t * (-1.13520398 + t * (
        1.48851587 + t * (-0.82215223 + t * 0.17087277)))))))));
    return (x < 0.0) ? (tau - 1.0) : (1.0 - tau);
}

float beam_super_gaussian_integral(float lo, float hi, float sigma)
{
    // 16-point Gauss-Legendre quadrature for exp(-0.5*(x/sigma)^4).
    lo = max(lo, -4.0 * sigma);
    hi = min(hi, 4.0 * sigma);
    if (hi <= lo)
        return 0.0;

    float midpoint = 0.5 * (lo + hi);
    float half_span = 0.5 * (hi - lo);
    float a1 = half_span * 0.0950125098;
    float a2 = half_span * 0.2816035508;
    float a3 = half_span * 0.4580167777;
    float a4 = half_span * 0.6178762444;
    float a5 = half_span * 0.7554044084;
    float a6 = half_span * 0.8656312024;
    float a7 = half_span * 0.9445750231;
    float a8 = half_span * 0.98940093499165;
    float q1a = (midpoint - a1) / sigma, q1b = (midpoint + a1) / sigma;
    float q2a = (midpoint - a2) / sigma, q2b = (midpoint + a2) / sigma;
    float q3a = (midpoint - a3) / sigma, q3b = (midpoint + a3) / sigma;
    float q4a = (midpoint - a4) / sigma, q4b = (midpoint + a4) / sigma;
    float q5a = (midpoint - a5) / sigma, q5b = (midpoint + a5) / sigma;
    float q6a = (midpoint - a6) / sigma, q6b = (midpoint + a6) / sigma;
    float q7a = (midpoint - a7) / sigma, q7b = (midpoint + a7) / sigma;
    float q8a = (midpoint - a8) / sigma, q8b = (midpoint + a8) / sigma;
    float f1a = exp(-0.5 * q1a * q1a * q1a * q1a), f1b = exp(-0.5 * q1b * q1b * q1b * q1b);
    float f2a = exp(-0.5 * q2a * q2a * q2a * q2a), f2b = exp(-0.5 * q2b * q2b * q2b * q2b);
    float f3a = exp(-0.5 * q3a * q3a * q3a * q3a), f3b = exp(-0.5 * q3b * q3b * q3b * q3b);
    float f4a = exp(-0.5 * q4a * q4a * q4a * q4a), f4b = exp(-0.5 * q4b * q4b * q4b * q4b);
    float f5a = exp(-0.5 * q5a * q5a * q5a * q5a), f5b = exp(-0.5 * q5b * q5b * q5b * q5b);
    float f6a = exp(-0.5 * q6a * q6a * q6a * q6a), f6b = exp(-0.5 * q6b * q6b * q6b * q6b);
    float f7a = exp(-0.5 * q7a * q7a * q7a * q7a), f7b = exp(-0.5 * q7b * q7b * q7b * q7b);
    float f8a = exp(-0.5 * q8a * q8a * q8a * q8a), f8b = exp(-0.5 * q8b * q8b * q8b * q8b);
    return half_span * (
        0.1894506105 * (f1a + f1b) + 0.1826034150 * (f2a + f2b)
      + 0.1691565194 * (f3a + f3b) + 0.1495959888 * (f4a + f4b)
      + 0.1246289713 * (f5a + f5b) + 0.0951585117 * (f6a + f6b)
      + 0.0622535239 * (f7a + f7b) + 0.0271524594 * (f8a + f8b));
}

float beam_profile_integral(float lo, float hi, float sigma, int profile)
{
    sigma = max(sigma, 1e-5);
    if (profile == 0)
    {
        float scale = sigma * 1.2533141373155;
        return scale * (beam_erf_approx(hi / (1.41421356237 * sigma))
                      - beam_erf_approx(lo / (1.41421356237 * sigma)));
    }
    if (profile == 2)
        return sigma * (atan(hi / sigma) - atan(lo / sigma));
    return beam_super_gaussian_integral(lo, hi, sigma);
}
float beam_profile_pixel_average(float signed_distance, float pixel_height,
                                 float sigma, int profile)
{
    pixel_height = max(pixel_height, 1e-5);
    float lo = signed_distance - 0.5 * pixel_height;
    float hi = signed_distance + 0.5 * pixel_height;
    float integral = 0.0;

    // The beam profile repeats every source-line period. Split any footprint
    // crossing a +/-0.5 boundary and wrap each segment into the central period.
    [unroll]
    for (int period = -3; period <= 3; ++period)
    {
        float segment_lo = max(lo, (float)period - 0.5);
        float segment_hi = min(hi, (float)period + 0.5);
        if (segment_hi > segment_lo)
            integral += beam_profile_integral(segment_lo - period,
                                              segment_hi - period,
                                              sigma, profile);
    }
    return integral / pixel_height;
}

float beam_profile_source_line_radius(float sigma, int profile)
{
    // Bound the source-line tails while retaining Lorentzian overlap between
    // neighboring lines. Gaussian-family tails are negligible beyond 4 sigma;
    // Lorentzian uses a wider fixed +/-5.5-line support like the horizontal kernel.
    return (profile == 2) ? 5.5 : (4.0 * max(sigma, 1e-5));
}

float beam_profile_source_line_pixel_average(float signed_distance, float pixel_height,
                                             float sigma, int profile)
{
    pixel_height = max(pixel_height, 1e-5);
    float radius = beam_profile_source_line_radius(sigma, profile);
    float lo = max(signed_distance - 0.5 * pixel_height, -radius);
    float hi = min(signed_distance + 0.5 * pixel_height, radius);
    if (hi <= lo)
        return 0.0;
    return beam_profile_integral(lo, hi, sigma, profile) / pixel_height;
}

float beam_profile_source_line_area(float sigma, int profile)
{
    float radius = beam_profile_source_line_radius(sigma, profile);
    return beam_profile_integral(-radius, radius, sigma, profile);
}

// Axis-specific hard validity prevents CLAMP from repeating border texels into the image.
// The visual edge feather is applied once at the final mapped scene sample, not in both passes.
// Internal-resolution source reconstruction -------------------------------------
// Pixel Smoothing computes an edge-aware blend for the current internal source cell when available.
// Horizontal reconstruction integrates source cells with a box-convolved spot kernel;
// the vertical source filter performs the corresponding line reconstruction. Neighboring
// horizontal taps remain raw source cells so the 3x3 adaptive analysis is not repeated
// for every tap. The two existing full-resolution targets are retained. Their alpha
// channels carry detail confidence for final grain protection (not opacity).
#define HORIZONTAL_CURRENT_EXPANSION 0.035
#define PIXEL_EDGE_BASELINE_FLOOR 0.30
#define PIXEL_EDGE_NORMAL_SCALE 0.62
#define PIXEL_EDGE_TANGENT_SCALE 1.18
#define PIXEL_RANGE_SIGMA_SQRT 0.18
#define SOURCE_FILTER_EPSILON 0.0001

float2 source_native_pixel_size_px()
{
    float2 viewport_size = (ViewportSize.x > 0.0 && ViewportSize.y > 0.0)
        ? ViewportSize : ReShade::ScreenSize.xy;

    if (NativeWidth > 0.0 && NativeHeight > 0.0)
        return max(viewport_size / float2(NativeWidth, NativeHeight),
                   float2(0.0001, 0.0001));

    // Conservative fallback for hosts that do not provide native dimensions:
    // the original 240-line assumption with square displayed source pixels.
    float ny = 1.0 / 240.0;
    float nx = ny * (ReShade::ScreenSize.y / ReShade::ScreenSize.x);
    return max(float2(nx, ny) / ReShade::PixelSize.xy,
               float2(0.0001, 0.0001));
}

// Reconstruct from DuckStation's actual internal render grid when it is available.
// At 1x this matches the native grid; at enhanced resolutions it retains the additional
// spatial detail rendered for 3D geometry instead of selecting only one sample per PS1 pixel.
// The CRT beam/raster helpers below intentionally continue to use source_native_pixel_size_px().
float2 source_reconstruction_pixel_size_px()
{
    float2 viewport_size = (ViewportSize.x > 0.0 && ViewportSize.y > 0.0)
        ? ViewportSize : ReShade::ScreenSize.xy;

    if (InternalWidth > 0.0 && InternalHeight > 0.0)
        return max(viewport_size / float2(InternalWidth, InternalHeight),
                   float2(0.0001, 0.0001));

    // Older hosts/builds without internal dimensions retain the previous native-grid path.
    return source_native_pixel_size_px();
}

// Preserve the existing source-smoothing controls in native-pixel units even though the
// reconstruction lattice can now be finer than the native raster.
float2 source_reconstruction_scale_from_native()
{
    if (InternalWidth > 0.0 && InternalHeight > 0.0
        && NativeWidth > 0.0 && NativeHeight > 0.0)
    {
        return max(float2(InternalWidth, InternalHeight)
                   / float2(NativeWidth, NativeHeight), float2(1.0, 1.0));
    }
    return float2(1.0, 1.0);
}

float2 source_native_pixel_size_uv()
{
    return source_native_pixel_size_px() * ReShade::PixelSize.xy;
}
float2 source_viewport_offset_px()
{
    return ViewportSize.x > 0.0 && ViewportSize.y > 0.0
        ? ViewportOffset : float2(0.0, 0.0);
}

float2 source_viewport_size_px()
{
    return (ViewportSize.x > 0.0 && ViewportSize.y > 0.0)
        ? ViewportSize : ReShade::ScreenSize.xy;
}

int2 source_sample_pixel_count(float2 viewport_size, float2 sample_size)
{
    return max((int2)floor(viewport_size / sample_size + 0.5), int2(1, 1));
}

int2 source_sample_cell_from_position(float4 pos, float2 viewport_offset,
                                      float2 sample_size, int2 sample_count)
{
    float2 coordinate = (pos.xy - viewport_offset) / sample_size;
    return clamp((int2)floor(coordinate), int2(0, 0), sample_count - 1);
}

float3 sample_accum_source_cell(int2 cell, float2 viewport_offset,
                                float2 sample_size, int2 sample_count,
                                float2 viewport_size)
{
    int2 safe_cell = clamp(cell, int2(0, 0), sample_count - 1);
    float2 sample_centre = viewport_offset + (float2(safe_cell) + 0.5) * sample_size;

    // Keep fractional internal-pixel centres. Rounding to an output texel centre here
    // collapses multiple internal samples together whenever their spacing is below 1 px.
    sample_centre = clamp(sample_centre, viewport_offset + 0.5,
                          viewport_offset + viewport_size - 0.5);
    return tex2D(sAccumFrame, sample_centre * ReShade::PixelSize.xy).rgb;
}

float3 source_sqrt_rgb(float3 color)
{
    return sqrt(max(color, float3(0.0, 0.0, 0.0)));
}

// YCoCg-like distance in the square-root RGB comparison domain. Inputs are
// pretransformed once per source-sample cell, then reused by tensor, bilateral
// weights and grain-detail confidence. Accumulated image values remain linear.
float source_color_distance_sqrt(float3 a_sqrt, float3 b_sqrt)
{
    float3 d = a_sqrt - b_sqrt;
    float d_y = abs(dot(d, float3(0.2126, 0.7152, 0.0722)));
    float d_co = abs(d.r - d.b);
    float d_cg = abs(d.g - 0.5 * (d.r + d.b));
    return d_y + 0.25 * (d_co + d_cg);
}

void source_edge_frame(
    float3 nw, float3 n, float3 ne,
    float3 w, float3 c, float3 e,
    float3 sw, float3 s, float3 se,
    out float2 edge_normal, out float edge_activity)
{
    // Inputs are already in square-root RGB comparison space. This lets the
    // caller reuse the same transformed samples for distance and blend weights.
    float3 gx0 = 0.5 * ((n - nw) + (c - w));
    float3 gy0 = 0.5 * ((w - nw) + (c - n));
    float3 gx1 = 0.5 * ((ne - n) + (e - c));
    float3 gy1 = 0.5 * ((c - n) + (e - ne));
    float3 gx2 = 0.5 * ((c - w) + (s - sw));
    float3 gy2 = 0.5 * ((sw - w) + (s - c));
    float3 gx3 = 0.5 * ((e - c) + (se - s));
    float3 gy3 = 0.5 * ((s - c) + (se - e));

    float jxx = 0.25 * (dot(gx0, gx0) + dot(gx1, gx1)
                      + dot(gx2, gx2) + dot(gx3, gx3));
    float jyy = 0.25 * (dot(gy0, gy0) + dot(gy1, gy1)
                      + dot(gy2, gy2) + dot(gy3, gy3));
    float jxy = 0.25 * (dot(gx0, gy0) + dot(gx1, gy1)
                      + dot(gx2, gy2) + dot(gx3, gy3));
    float trace = jxx + jyy;
    float discriminant = sqrt(max((jxx - jyy) * (jxx - jyy)
                                + 4.0 * jxy * jxy, 0.0));
    float coherence = saturate(discriminant / max(trace, 1e-8));
    float edge_magnitude = sqrt(max(trace, 0.0));
    float dominant_eigenvalue = 0.5 * (trace + discriminant);
    float2 eigenvector = (jxx >= jyy)
        ? float2(dominant_eigenvalue - jyy, jxy)
        : float2(jxy, dominant_eigenvalue - jxx);
    float eigenvector_length_sq = dot(eigenvector, eigenvector);
    bool orientation_exists = trace > 1e-8
        && discriminant > max(trace * 1e-5, 1e-10)
        && eigenvector_length_sq > 1e-16;
    edge_normal = orientation_exists
        ? eigenvector * rsqrt(max(eigenvector_length_sq, 1e-16))
        : float2(1.0, 0.0);

    float contrast_confidence = smoothstep(0.025, 0.20, edge_magnitude);
    float orientation_confidence = smoothstep(0.15, 0.60, coherence);
    edge_activity = contrast_confidence * orientation_confidence;
}

float source_edge_neighbour_weight(
    float range_distance, float2 offset,
    float2 edge_normal, float edge_activity)
{
    float2 edge_tangent = float2(-edge_normal.y, edge_normal.x);
    float normal_distance = dot(offset, edge_normal);
    float tangent_distance = dot(offset, edge_tangent);
    float normal_scale = lerp(1.0, PIXEL_EDGE_NORMAL_SCALE,
        saturate(edge_activity * 0.75));
    float tangent_scale = lerp(1.0, PIXEL_EDGE_TANGENT_SCALE,
        saturate(edge_activity * 0.8125));
    float anisotropy_exponent = -0.5 * (
        normal_distance * normal_distance * (rcp(normal_scale * normal_scale) - 1.0)
      + tangent_distance * tangent_distance * (rcp(tangent_scale * tangent_scale) - 1.0));
    float anisotropy_weight = exp(anisotropy_exponent);
    float spatial_weight = (abs(offset.x) + abs(offset.y) < 1.5)
        ? 1.0 : 0.70710678;
    float range_weight = exp(-0.5 * range_distance * range_distance
        / (PIXEL_RANGE_SIGMA_SQRT * PIXEL_RANGE_SIGMA_SQRT));
    return spatial_weight * anisotropy_weight * range_weight;
}

float3 source_edge_aware_pixel_blend(
    float3 nw, float3 n, float3 ne,
    float3 w, float3 centre, float3 e,
    float3 sw, float3 south, float3 se,
    float d_nw, float d_n, float d_ne, float d_w,
    float d_e, float d_sw, float d_s, float d_se,
    float2 edge_normal, float edge_activity, float blend_amount)
{
    float w_nw = source_edge_neighbour_weight(d_nw, float2(-1.0, -1.0), edge_normal, edge_activity);
    float w_n  = source_edge_neighbour_weight(d_n,  float2( 0.0, -1.0), edge_normal, edge_activity);
    float w_ne = source_edge_neighbour_weight(d_ne, float2( 1.0, -1.0), edge_normal, edge_activity);
    float w_w  = source_edge_neighbour_weight(d_w,  float2(-1.0,  0.0), edge_normal, edge_activity);
    float w_e  = source_edge_neighbour_weight(d_e,  float2( 1.0,  0.0), edge_normal, edge_activity);
    float w_sw = source_edge_neighbour_weight(d_sw, float2(-1.0,  1.0), edge_normal, edge_activity);
    float w_s  = source_edge_neighbour_weight(d_s,  float2( 0.0,  1.0), edge_normal, edge_activity);
    float w_se = source_edge_neighbour_weight(d_se, float2( 1.0,  1.0), edge_normal, edge_activity);

    float3 filtered = centre * 1.5
        + nw * w_nw + n * w_n + ne * w_ne
        + w * w_w + e * w_e
        + sw * w_sw + south * w_s + se * w_se;
    float weight_sum = 1.5 + w_nw + w_n + w_ne + w_w + w_e + w_sw + w_s + w_se;
    filtered /= max(weight_sum, 1e-5);
    return lerp(centre, filtered, saturate(blend_amount));
}

// Adjacent horizontal reconstruction taps have only one cached column on their
// outside edge. This two-column / three-row variant builds a local tensor from the
// two overlapping 2x2 quadrants and uses the six cached source samples. It is a
// bounded approximation to the full 3x3 centre filter, not an identical 3x3 solve.
void source_edge_frame_two_columns(
    float3 outer_top, float3 target, float3 outer_bottom,
    float3 inner_top, float3 inner_centre, float3 inner_bottom,
    float inner_direction_x,
    out float2 edge_normal, out float edge_activity)
{
    // The adjacent tap may lie on either side of the central column. Orient the
    // horizontal derivatives consistently in output-image X before forming Jxy.
    float3 gx_top = 0.5 * ((inner_top - outer_top) + (inner_centre - target))
        * inner_direction_x;
    float3 gy_top = 0.5 * ((target - outer_top) + (inner_centre - inner_top));
    float3 gx_bottom = 0.5 * ((inner_centre - target) + (inner_bottom - outer_bottom))
        * inner_direction_x;
    float3 gy_bottom = 0.5 * ((outer_bottom - target) + (inner_bottom - inner_centre));

    float jxx = 0.5 * (dot(gx_top, gx_top) + dot(gx_bottom, gx_bottom));
    float jyy = 0.5 * (dot(gy_top, gy_top) + dot(gy_bottom, gy_bottom));
    float jxy = 0.5 * (dot(gx_top, gy_top) + dot(gx_bottom, gy_bottom));
    float trace = jxx + jyy;
    float discriminant = sqrt(max((jxx - jyy) * (jxx - jyy)
                                + 4.0 * jxy * jxy, 0.0));
    float coherence = saturate(discriminant / max(trace, 1e-8));
    float edge_magnitude = sqrt(max(trace, 0.0));
    float dominant_eigenvalue = 0.5 * (trace + discriminant);
    float2 eigenvector = (jxx >= jyy)
        ? float2(dominant_eigenvalue - jyy, jxy)
        : float2(jxy, dominant_eigenvalue - jxx);
    float eigenvector_length_sq = dot(eigenvector, eigenvector);
    bool orientation_exists = trace > 1e-8
        && discriminant > max(trace * 1e-5, 1e-10)
        && eigenvector_length_sq > 1e-16;
    edge_normal = orientation_exists
        ? eigenvector * rsqrt(max(eigenvector_length_sq, 1e-16))
        : float2(1.0, 0.0);

    float contrast_confidence = smoothstep(0.025, 0.20, edge_magnitude);
    float orientation_confidence = smoothstep(0.15, 0.60, coherence);
    edge_activity = contrast_confidence * orientation_confidence;
}

float3 source_edge_aware_adjacent_pixel_blend(
    float3 outer_top, float3 target, float3 outer_bottom,
    float3 inner_top, float3 inner_centre, float3 inner_bottom,
    float inner_direction_x)
{
    float3 s_outer_top = source_sqrt_rgb(outer_top);
    float3 s_target = source_sqrt_rgb(target);
    float3 s_outer_bottom = source_sqrt_rgb(outer_bottom);
    float3 s_inner_top = source_sqrt_rgb(inner_top);
    float3 s_inner_centre = source_sqrt_rgb(inner_centre);
    float3 s_inner_bottom = source_sqrt_rgb(inner_bottom);

    float2 edge_normal;
    float edge_activity;
    source_edge_frame_two_columns(
        s_outer_top, s_target, s_outer_bottom,
        s_inner_top, s_inner_centre, s_inner_bottom,
        inner_direction_x, edge_normal, edge_activity);

    float d_outer_top = source_color_distance_sqrt(s_target, s_outer_top);
    float d_outer_bottom = source_color_distance_sqrt(s_target, s_outer_bottom);
    float d_inner_top = source_color_distance_sqrt(s_target, s_inner_top);
    float d_inner_centre = source_color_distance_sqrt(s_target, s_inner_centre);
    float d_inner_bottom = source_color_distance_sqrt(s_target, s_inner_bottom);

    float w_outer_top = source_edge_neighbour_weight(
        d_outer_top, float2(0.0, -1.0), edge_normal, edge_activity);
    float w_outer_bottom = source_edge_neighbour_weight(
        d_outer_bottom, float2(0.0, 1.0), edge_normal, edge_activity);
    float w_inner_top = source_edge_neighbour_weight(
        d_inner_top, float2(inner_direction_x, -1.0), edge_normal, edge_activity);
    float w_inner_centre = source_edge_neighbour_weight(
        d_inner_centre, float2(inner_direction_x, 0.0), edge_normal, edge_activity);
    float w_inner_bottom = source_edge_neighbour_weight(
        d_inner_bottom, float2(inner_direction_x, 1.0), edge_normal, edge_activity);

    float3 filtered = target * 1.5
        + outer_top * w_outer_top + outer_bottom * w_outer_bottom
        + inner_top * w_inner_top + inner_centre * w_inner_centre
        + inner_bottom * w_inner_bottom;
    float weight_sum = 1.5 + w_outer_top + w_outer_bottom
        + w_inner_top + w_inner_centre + w_inner_bottom;
    filtered /= max(weight_sum, 1e-5);

    float activity_scale = lerp(PIXEL_EDGE_BASELINE_FLOOR, 1.0,
                                saturate(edge_activity));
    float blend_amount = saturate(pixel_smoothing) * activity_scale;
    return lerp(target, filtered, blend_amount);
}

float source_erf_approx(float x)
{
    float ax = abs(x);
    float t = 1.0 / (1.0 + 0.5 * ax);
    float tau = t * exp(-ax * ax - 1.26551223 + t * (
        1.00002368 + t * (0.37409196 + t * (0.09678418 + t * (
       -0.18628806 + t * (0.27886807 + t * (-1.13520398 + t * (
        1.48851587 + t * (-0.82215223 + t * 0.17087277)))))))));
    return (x < 0.0) ? (tau - 1.0) : (1.0 - tau);
}

float source_normal_cdf(float x)
{
    return 0.5 * (1.0 + source_erf_approx(x * 0.7071067811865475));
}

float source_super_gaussian_integral(float lo, float hi, float sigma)
{
    // 16-point Gauss-Legendre quadrature for exp(-0.5*(x/sigma)^4).
    // Integrating only the clipped interval keeps the evaluation bounded.
    float midpoint = 0.5 * (lo + hi);
    float half_span = 0.5 * (hi - lo);
    float x0 = midpoint;
    float a1 = half_span * 0.0950125098;
    float a2 = half_span * 0.2816035508;
    float a3 = half_span * 0.4580167777;
    float a4 = half_span * 0.6178762444;
    float a5 = half_span * 0.7554044084;
    float a6 = half_span * 0.8656312024;
    float a7 = half_span * 0.9445750231;
    float a8 = half_span * 0.98940093499165;

    float q1a = (x0 - a1) / sigma, q1b = (x0 + a1) / sigma;
    float q2a = (x0 - a2) / sigma, q2b = (x0 + a2) / sigma;
    float q3a = (x0 - a3) / sigma, q3b = (x0 + a3) / sigma;
    float q4a = (x0 - a4) / sigma, q4b = (x0 + a4) / sigma;
    float q5a = (x0 - a5) / sigma, q5b = (x0 + a5) / sigma;
    float q6a = (x0 - a6) / sigma, q6b = (x0 + a6) / sigma;
    float q7a = (x0 - a7) / sigma, q7b = (x0 + a7) / sigma;
    float q8a = (x0 - a8) / sigma, q8b = (x0 + a8) / sigma;
    float f1a = exp(-0.5 * q1a * q1a * q1a * q1a);
    float f1b = exp(-0.5 * q1b * q1b * q1b * q1b);
    float f2a = exp(-0.5 * q2a * q2a * q2a * q2a);
    float f2b = exp(-0.5 * q2b * q2b * q2b * q2b);
    float f3a = exp(-0.5 * q3a * q3a * q3a * q3a);
    float f3b = exp(-0.5 * q3b * q3b * q3b * q3b);
    float f4a = exp(-0.5 * q4a * q4a * q4a * q4a);
    float f4b = exp(-0.5 * q4b * q4b * q4b * q4b);
    float f5a = exp(-0.5 * q5a * q5a * q5a * q5a);
    float f5b = exp(-0.5 * q5b * q5b * q5b * q5b);
    float f6a = exp(-0.5 * q6a * q6a * q6a * q6a);
    float f6b = exp(-0.5 * q6b * q6b * q6b * q6b);
    float f7a = exp(-0.5 * q7a * q7a * q7a * q7a);
    float f7b = exp(-0.5 * q7b * q7b * q7b * q7b);
    float f8a = exp(-0.5 * q8a * q8a * q8a * q8a);
    float f8b = exp(-0.5 * q8b * q8b * q8b * q8b);

    return half_span * (
        0.1894506105 * (f1a + f1b)
      + 0.1826034150 * (f2a + f2b)
      + 0.1691565194 * (f3a + f3b)
      + 0.1495959888 * (f4a + f4b)
      + 0.1246289713 * (f5a + f5b)
      + 0.0951585117 * (f6a + f6b)
      + 0.0622535239 * (f7a + f7b)
      + 0.0271524594 * (f8a + f8b));
}
float source_profile_cell_weight(float sample_coordinate, float cell_index,
                                 float sigma, int profile, float native_to_sample_scale)
{
    sigma = max(sigma, 1e-5);
    float distance = sample_coordinate - cell_index;
    float lo = distance - 0.5;
    float hi = distance + 0.5;
    if (profile == 2)
    {
        // Finite-support, unit-area Lorentzian. The +/-5.5-native-cell support
        // bounds the long tail while normalizing each source-cell kernel itself.
        float radius = 5.5 * max(native_to_sample_scale, 1.0);
        lo = max(lo, -radius);
        hi = min(hi, radius);
        if (hi <= lo)
            return 0.0;
        return (atan(hi / sigma) - atan(lo / sigma))
            / max(2.0 * atan(radius / sigma), 1e-6);
    }
    if (profile == 1)
    {
        // Exclude negligible tails so the fixed quadrature resolves narrow spots.
        lo = max(lo, -4.0 * sigma);
        hi = min(hi, 4.0 * sigma);
        if (hi <= lo)
            return 0.0;
        float area = source_super_gaussian_integral(lo, hi, sigma);
        return area / max(2.1556 * sigma, 1e-6);
    }
    return source_normal_cdf(hi / sigma) - source_normal_cdf(lo / sigma);
}

float3 source_profile_cell_weight3(float sample_coordinate, float cell_index,
                                   float3 sigma, int profile, float native_to_sample_scale)
{
    return float3(
        source_profile_cell_weight(sample_coordinate, cell_index, sigma.r, profile, native_to_sample_scale),
        source_profile_cell_weight(sample_coordinate, cell_index, sigma.g, profile, native_to_sample_scale),
        source_profile_cell_weight(sample_coordinate, cell_index, sigma.b, profile, native_to_sample_scale));
}

float3 source_profile_cell_weight3_structured(float sample_coordinate, float cell_index,
                                              float3 sigma, int profile,
                                              float native_to_sample_scale)
{
    float3 core = source_profile_cell_weight3(
        sample_coordinate, cell_index, sigma, profile, native_to_sample_scale);
    if (PX_HORIZONTAL_SPOT_STRUCTURE == 0)
        return core;

    // Both components are individually unit-area normalized by the existing
    // profile integrator. This preserves total energy while redistributing the
    // user-selected fraction into a wider spot. The controls have no effect in
    // Single Lobe mode because this function returns above.
    float tail_energy = saturate(PX_HORIZONTAL_SPOT_TAIL_ENERGY * 0.01);
    float tail_scale = max(PX_HORIZONTAL_SPOT_TAIL_WIDTH, 1.0);
    if (tail_energy <= 0.0 || tail_scale <= 1.0001)
        return core;

    float3 tail = source_profile_cell_weight3(
        sample_coordinate, cell_index, sigma * tail_scale, profile, native_to_sample_scale);
    return lerp(core, tail, tail_energy);
}

float gaussian_source_cell_weight(float sample_coordinate, float cell_index, float sigma)
{
    sigma = max(sigma, 1e-5);
    float distance = sample_coordinate - cell_index;
    return source_normal_cdf((distance + 0.5) / sigma)
         - source_normal_cdf((distance - 0.5) / sigma);
}

float4 PS_SmoothH(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    float2 viewport_offset = source_viewport_offset_px();
    float2 viewport_size = source_viewport_size_px();
    if (pos.x < viewport_offset.x || pos.y < viewport_offset.y
        || pos.x >= viewport_offset.x + viewport_size.x
        || pos.y >= viewport_offset.y + viewport_size.y)
        return float4(tex2D(sAccumFrame, uv).rgb, 0.0);

    float2 sample_size = source_reconstruction_pixel_size_px();
    int2 sample_count = source_sample_pixel_count(viewport_size, sample_size);
    int2 centre_cell = source_sample_cell_from_position(
        pos, viewport_offset, sample_size, sample_count);
    float2 source_coordinate = (pos.xy - viewport_offset) / sample_size - 0.5;
    float3 centre = sample_accum_source_cell(
        centre_cell, viewport_offset, sample_size, sample_count, viewport_size);
    float3 adaptive_centre = centre;
    float3 cached_horizontal_left = centre;
    float3 cached_horizontal_right = centre;
    float3 adaptive_horizontal_left = centre;
    float3 adaptive_horizontal_right = centre;
    bool horizontal_neighbours_cached = false;
    float detail_confidence = 0.0;

    // One 3x3 source-sample neighbourhood feeds both the adaptive pixel blend
    // and the grain-detail metadata. No second detail-analysis pass is needed.
    bool use_edge_aware_smoothing = (pixel_smoothing_mode == 0 || pixel_smoothing_mode == 2)
        && pixel_smoothing > 0.0001;
    bool use_subpixel_smoothing = (pixel_smoothing_mode == 1 || pixel_smoothing_mode == 2)
        && pixel_smoothing > 0.0001;

    if (use_edge_aware_smoothing || noise_detail_protection > 0.0001)
    {
        float3 nw = sample_accum_source_cell(centre_cell + int2(-1, -1), viewport_offset, sample_size, sample_count, viewport_size);
        float3 n  = sample_accum_source_cell(centre_cell + int2( 0, -1), viewport_offset, sample_size, sample_count, viewport_size);
        float3 ne = sample_accum_source_cell(centre_cell + int2( 1, -1), viewport_offset, sample_size, sample_count, viewport_size);
        float3 w  = sample_accum_source_cell(centre_cell + int2(-1,  0), viewport_offset, sample_size, sample_count, viewport_size);
        float3 e  = sample_accum_source_cell(centre_cell + int2( 1,  0), viewport_offset, sample_size, sample_count, viewport_size);
        cached_horizontal_left = w;
        cached_horizontal_right = e;
        horizontal_neighbours_cached = true;
        float3 sw = sample_accum_source_cell(centre_cell + int2(-1,  1), viewport_offset, sample_size, sample_count, viewport_size);
        float3 so = sample_accum_source_cell(centre_cell + int2( 0,  1), viewport_offset, sample_size, sample_count, viewport_size);
        float3 se = sample_accum_source_cell(centre_cell + int2( 1,  1), viewport_offset, sample_size, sample_count, viewport_size);

        // Transform each source sample once. These same values feed the
        // four-quadrant tensor, all eight bilateral weights and detail gating.
        float3 snw = source_sqrt_rgb(nw);
        float3 sn  = source_sqrt_rgb(n);
        float3 sne = source_sqrt_rgb(ne);
        float3 swc = source_sqrt_rgb(w);
        float3 sc  = source_sqrt_rgb(centre);
        float3 sec = source_sqrt_rgb(e);
        float3 ssw = source_sqrt_rgb(sw);
        float3 sso = source_sqrt_rgb(so);
        float3 sse = source_sqrt_rgb(se);

        float2 edge_normal;
        float edge_activity;
        source_edge_frame(snw, sn, sne, swc, sc, sec, ssw, sso, sse,
                          edge_normal, edge_activity);

        float d_nw = source_color_distance_sqrt(sc, snw);
        float d_n  = source_color_distance_sqrt(sc, sn);
        float d_ne = source_color_distance_sqrt(sc, sne);
        float d_w  = source_color_distance_sqrt(sc, swc);
        float d_e  = source_color_distance_sqrt(sc, sec);
        float d_sw = source_color_distance_sqrt(sc, ssw);
        float d_s  = source_color_distance_sqrt(sc, sso);
        float d_se = source_color_distance_sqrt(sc, sse);
        float local_detail = max(max(max(d_nw, d_n), max(d_ne, d_w)),
                                 max(max(d_e, d_sw), max(d_s, d_se)));
        float contrast_detail = smoothstep(0.025, 0.16, local_detail);
        // The distance term protects isolated pixels and irregular texture;
        // the tensor term also protects coherent edge structure.
        detail_confidence = max(contrast_detail, 0.75 * edge_activity);

        if (use_edge_aware_smoothing)
        {
            float activity_scale = lerp(PIXEL_EDGE_BASELINE_FLOOR, 1.0,
                                         saturate(edge_activity));
            float blend_amount = saturate(pixel_smoothing) * activity_scale;
            adaptive_centre = source_edge_aware_pixel_blend(
                nw, n, ne, w, centre, e, sw, so, se,
                d_nw, d_n, d_ne, d_w, d_e, d_sw, d_s, d_se,
                edge_normal, edge_activity, blend_amount);

            // The neighbouring tap filters reuse the same cached 3x3 values. Each
            // adjacent centre gets a two-column tensor/filter; no texture fetches
            // are added. The asymmetric cached footprint is intentional and bounded.
            if (adjacent_tap_edge_blending)
            {
                adaptive_horizontal_left = source_edge_aware_adjacent_pixel_blend(
                    nw, w, sw, n, centre, so, 1.0);
                adaptive_horizontal_right = source_edge_aware_adjacent_pixel_blend(
                    ne, e, se, n, centre, so, -1.0);
            }
        }
    }

    // Box-convolved horizontal spot reconstruction. Edge-Aware/Hybrid modes apply
    // their adaptive blend to the centre source cell; Subpixel Blend shifts the
    // integrated kernel symmetrically. Neighbouring source cells do not repeat the
    // 3x3 analysis for every horizontal tap.
    float spot_sigma_output = PX_BEAM_HORIZONTAL_SPOT * (ReShade::ScreenSize.y / 1080.0);
    float spot_sigma_source = spot_sigma_output / max(sample_size.x, 0.0001);
    float2 reconstruction_scale = source_reconstruction_scale_from_native();
    float source_smooth_sigma = source_smooth_h * reconstruction_scale.x;
    float base_sigma = sqrt(source_smooth_sigma * source_smooth_sigma
                          + spot_sigma_source * spot_sigma_source);
    // The legacy Pixel Smoothing operation offsets the complete horizontal
    // reconstruction by half the slider value in output-pixel units.
    float subpixel_offset_source_x = use_subpixel_smoothing
        ? (0.5 * saturate(pixel_smoothing) / max(sample_size.x, 0.0001)) : 0.0;
    if (base_sigma <= SOURCE_FILTER_EPSILON)
    {
        if (!use_subpixel_smoothing)
            return float4(adaptive_centre, detail_confidence);

        // With no horizontal Gaussian/beam width, reproduce the old two-sample
        // output-pixel blend directly. Clamp to active viewport pixel centres so
        // letterbox/viewport boundaries do not pull unrelated pixels inward.
        float2 viewport_uv_min = (viewport_offset + 0.5) * ReShade::PixelSize.xy;
        float2 viewport_uv_max = (viewport_offset + viewport_size - 0.5) * ReShade::PixelSize.xy;
        float2 offset_uv = float2(0.5 * saturate(pixel_smoothing) * ReShade::PixelSize.x, 0.0);
        float2 uv_left = uv - offset_uv;
        float2 uv_right = uv + offset_uv;
        uv_left.x = clamp(uv_left.x, viewport_uv_min.x, viewport_uv_max.x);
        uv_right.x = clamp(uv_right.x, viewport_uv_min.x, viewport_uv_max.x);
        float3 subpixel_color = 0.5 * (
            tex2D(sAccumFrame, uv_left).rgb + tex2D(sAccumFrame, uv_right).rgb);
        if (pixel_smoothing_mode == 2)
            subpixel_color = lerp(subpixel_color, adaptive_centre, 0.5);
        return float4(subpixel_color, detail_confidence);
    }

    float maximum_sigma = base_sigma * (1.0 + HORIZONTAL_CURRENT_EXPANSION);
    float tail_energy = saturate(PX_HORIZONTAL_SPOT_TAIL_ENERGY * 0.01);
    float tail_width = max(PX_HORIZONTAL_SPOT_TAIL_WIDTH, 1.0);
    float support_scale = (PX_HORIZONTAL_SPOT_STRUCTURE == 1 && tail_energy > 0.0)
        ? tail_width : 1.0;
    int support;
    if (PX_BEAM_SPOT_PROFILE == 2)
    {
        // Preserve the Lorentzian's +/-5.5-native-cell support on the finer grid.
        support = (int)ceil(5.5 * reconstruction_scale.x + 0.5);
    }
    else
    {
        // Keep the original five/six native-cell safety bound, scaled into internal cells.
        // Core + Tail needs a wider tap allowance, scaled by the selected tail
        // width. Keep the existing single-lobe support bound unchanged.
        float support_native_cells = (PX_HORIZONTAL_SPOT_STRUCTURE == 1 && tail_energy > 0.0)
            ? max(6.0, 3.5 * tail_width * maximum_sigma / max(reconstruction_scale.x, 1e-5))
            : 5.0;
        int support_limit = (int)ceil(support_native_cells * reconstruction_scale.x);
        support = clamp((int)ceil(3.5 * maximum_sigma * support_scale
                                   + subpixel_offset_source_x + 0.5),
                        1, max(support_limit, 1));
    }
    float3 reconstructed = float3(0.0, 0.0, 0.0);

    [loop]
    for (int tap = -support; tap <= support; ++tap)
    {
        int source_cell_index = centre_cell.x + tap;
        float3 raw_source_color;
        if (tap == 0)
            raw_source_color = centre;
        else if (tap == -1 && horizontal_neighbours_cached)
            raw_source_color = cached_horizontal_left;
        else if (tap == 1 && horizontal_neighbours_cached)
            raw_source_color = cached_horizontal_right;
        else
            raw_source_color = sample_accum_source_cell(
                int2(source_cell_index, centre_cell.y), viewport_offset,
                sample_size, sample_count, viewport_size);
        // Spot width follows the original source cell's three gun drives;
        // adaptive pixel blending changes reconstruction color, not current.
        float3 source_color = (tap == 0) ? adaptive_centre : raw_source_color;
        if (use_edge_aware_smoothing && adjacent_tap_edge_blending)
        {
            if (tap == -1)
                source_color = adaptive_horizontal_left;
            else if (tap == 1)
                source_color = adaptive_horizontal_right;
        }
        float3 current = saturate(raw_source_color / 1.25);
        float3 sigma = base_sigma * (1.0 + HORIZONTAL_CURRENT_EXPANSION * current);
        float3 weight;
        if (use_subpixel_smoothing)
        {
            // Average the same integrated source-cell kernel at two symmetric
            // output-pixel-relative positions. This is the legacy blend expressed
            // on the internal/native source-cell grid, so enhanced rendering keeps
            // its finer sampling lattice without changing the requested output-pixel offset.
            float3 weight_left = source_profile_cell_weight3_structured(
                source_coordinate.x - subpixel_offset_source_x,
                (float)source_cell_index, sigma, PX_BEAM_SPOT_PROFILE,
                reconstruction_scale.x);
            float3 weight_right = source_profile_cell_weight3_structured(
                source_coordinate.x + subpixel_offset_source_x,
                (float)source_cell_index, sigma, PX_BEAM_SPOT_PROFILE,
                reconstruction_scale.x);
            weight = 0.5 * (weight_left + weight_right);
        }
        else
        {
            weight = source_profile_cell_weight3_structured(
                source_coordinate.x, (float)source_cell_index, sigma, PX_BEAM_SPOT_PROFILE,
                reconstruction_scale.x);
        }
        reconstructed += source_color * weight;
    }

    return float4(reconstructed, detail_confidence);
}

float4 PS_SmoothV(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    float2 viewport_offset = source_viewport_offset_px();
    float2 viewport_size = source_viewport_size_px();
    if (pos.x < viewport_offset.x || pos.y < viewport_offset.y
        || pos.x >= viewport_offset.x + viewport_size.x
        || pos.y >= viewport_offset.y + viewport_size.y)
        return float4(tex2D(sSmoothH, uv).rgb, 0.0);

    float2 reconstruction_scale = source_reconstruction_scale_from_native();
    float sigma = source_smooth_v * reconstruction_scale.y;
    bool use_subpixel_smoothing = (pixel_smoothing_mode == 1 || pixel_smoothing_mode == 2)
        && pixel_smoothing > 0.0001;
    if (sigma <= SOURCE_FILTER_EPSILON && !use_subpixel_smoothing)
        return tex2D(sSmoothH, uv);

    float2 sample_size = source_reconstruction_pixel_size_px();
    if (sigma <= SOURCE_FILTER_EPSILON)
    {
        // With no vertical source Gaussian, the legacy mode is the original
        // symmetric pair of linear samples, now applied to the H-pass result.
        float2 viewport_uv_min = (viewport_offset + 0.5) * ReShade::PixelSize.xy;
        float2 viewport_uv_max = (viewport_offset + viewport_size - 0.5) * ReShade::PixelSize.xy;
        float offset_uv = 0.5 * saturate(pixel_smoothing) * ReShade::PixelSize.y;
        float2 uv_top = uv;
        float2 uv_bottom = uv;
        uv_top.y = clamp(uv.y - offset_uv, viewport_uv_min.y, viewport_uv_max.y);
        uv_bottom.y = clamp(uv.y + offset_uv, viewport_uv_min.y, viewport_uv_max.y);
        float4 top_sample = tex2D(sSmoothH, uv_top);
        float4 bottom_sample = tex2D(sSmoothH, uv_bottom);
        float4 subpixel_result = 0.5 * (top_sample + bottom_sample);
        if (pixel_smoothing_mode == 2)
            subpixel_result.rgb = lerp(subpixel_result.rgb, tex2D(sSmoothH, uv).rgb, 0.5);
        return subpixel_result;
    }

    int2 sample_count = source_sample_pixel_count(viewport_size, sample_size);
    float sample_coordinate = (pos.y - viewport_offset.y) / sample_size.y - 0.5;
    float subpixel_offset_source_y = use_subpixel_smoothing
        ? (0.5 * saturate(pixel_smoothing) / max(sample_size.y, 0.0001)) : 0.0;
    int centre_line = (int)floor(sample_coordinate + 0.5);
    // The existing maximum of two native lines is expressed on the internal grid.
    int support_limit = max((int)ceil(2.0 * reconstruction_scale.y), 1);
    int support = clamp((int)ceil(3.5 * sigma + subpixel_offset_source_y + 0.5),
                        1, support_limit);
    float3 accumulated = float3(0.0, 0.0, 0.0);
    float detail_accumulated = 0.0;

    // Vertical source smoothing is an area-integrated Gaussian over internal source-line
    // cells. The later CRT beam stage remains separate and retains native-raster pitch.
    [loop]
    for (int tap = -support; tap <= support; ++tap)
    {
        int source_line = centre_line + tap;
        float weight;
        if (use_subpixel_smoothing)
        {
            float weight_top = gaussian_source_cell_weight(
                sample_coordinate - subpixel_offset_source_y, (float)source_line, sigma);
            float weight_bottom = gaussian_source_cell_weight(
                sample_coordinate + subpixel_offset_source_y, (float)source_line, sigma);
            weight = 0.5 * (weight_top + weight_bottom);
        }
        else
        {
            weight = gaussian_source_cell_weight(
                sample_coordinate, (float)source_line, sigma);
        }
        float2 line_centre = viewport_offset
            + (float2(0.0, (float)clamp(source_line, 0, sample_count.y - 1)) + 0.5)
                * sample_size;
        float sample_y = clamp(line_centre.y, viewport_offset.y + 0.5,
                               viewport_offset.y + viewport_size.y - 0.5)
            * ReShade::PixelSize.y;
        float4 source = tex2D(sSmoothH, float2(uv.x, sample_y));
        accumulated += source.rgb * weight;
        detail_accumulated += source.a * weight;
    }

    return float4(accumulated, saturate(detail_accumulated));
}

float3 tsample_soft(float2 tc)
{
    tc = tc * float2(1.025, 0.92) + float2(-0.0125, 0.04);
    float2 suv = float2(tc.x, 1.0 - tc.y);
    return tex2D(sSmoothV, suv).rgb * edge_mask(suv);
}

float3 tsample_blurred(sampler samp, float2 tc)
{
    tc = tc * float2(1.025, 0.92) + float2(-0.0125, 0.04);
    float2 suv = float2(tc.x, 1.0 - tc.y);
    // The blur was generated from the same gained linear-light accumulation as the image path.
    return tex2D(samp, suv).rgb * edge_mask(suv);
}

// Built-in mask presets. Keep these separate from the custom UI values so the selector
// can switch between stable profile defaults and independently editable mask settings.
#define PROFILE_APERTURE_STRENGTH       0.24
#define PROFILE_APERTURE_PITCH          3.0
#define PROFILE_APERTURE_STRIPE_WIDTH   0.95
#define PROFILE_APERTURE_GAP            0.10
#define PROFILE_APERTURE_DAMPERS        false
#define PROFILE_APERTURE_WIRE_STRENGTH  0.05

#define PROFILE_SLOT_STRENGTH           0.4
#define PROFILE_SLOT_PITCH              4.0
#define PROFILE_SLOT_WIDTH              0.6
#define PROFILE_SLOT_GAP                0.5
#define PROFILE_SLOT_HEIGHT             1.0

#define PROFILE_SHADOW_STRENGTH         0.24
#define PROFILE_SHADOW_PITCH            3.0
#define PROFILE_SHADOW_DOT_WIDTH        0.95
#define PROFILE_SHADOW_GAP              0.10

// Resolve the single Phosphor Mask Type selector.
// Selector 0 follows the display profile: all Sony profiles -> aperture grille; Toshiba takes
// -> slot mask; Neutral -> aperture grille.
// Explicit selector values 1-4 map to mask types 0-3 and affect only mask rendering.
int active_phosphor_mask_type()
{
    if (phosphor_mask_selection == 0)
    {
        if (display_profile == 4 || display_profile == 5)
            return 1;
        return 0;
    }

    return phosphor_mask_selection - 1;
}

// Evaluate one subpixel sample of the selected two-dimensional phosphor mask. Coordinates are
// in output-buffer pixels; the triad pitch scales from the 1080p reference size.
float3 evaluate_phosphor_mask_sample(float2 pixel, float pitch, float stripe_width,
                                      float slot_height, int mask_type)
{
    float row_pitch = max(pitch * 0.80, 1.5);
    float row_index = floor(pixel.y / row_pitch);
    float row_phase = frac(pixel.y / row_pitch);
    float row_parity = row_index - 2.0 * floor(row_index * 0.5);
    float row_shift = (mask_type != 0 && row_parity > 0.5) ? 0.5 : 0.0;
    float phase_x = frac(pixel.x / pitch + row_shift);
    float3 mask = float3(0.0, 0.0, 0.0);

    float stripe_coordinate = phase_x * 3.0;
    float channel_index = floor(stripe_coordinate);
    float channel_position = frac(stripe_coordinate);
    float stripe_coverage = 1.0 - smoothstep(
        stripe_width * 0.5 - 0.015,
        stripe_width * 0.5 + 0.015,
        abs(channel_position - 0.5));

    if (mask_type == 1)
    {
        // Slot mask: stagger alternate rows and interrupt each vertical color slot with a
        // horizontal opaque gap. This is an illustrative slot-mask geometry, not a tube-specific
        // mask pitch calibration.
        slot_height = saturate(slot_height);
        float slot_edge_distance = abs(row_phase - 0.5);
        float y_coverage;
        if (slot_height >= 1.0)
        {
            // At exactly full height, the slot reaches both row boundaries with no gap.
            y_coverage = 1.0;
        }
        else
        {
            // Keep the smoothstep midpoint at the requested slot edge (slot_height / 2).
            // Above 0.95, the transition narrows so its outer edge remains inside row_phase.
            float slot_transition_upper = min(slot_height * 0.5 + 0.025, 0.5);
            float slot_transition_lower = slot_height - slot_transition_upper;
            y_coverage = 1.0 - smoothstep(
                slot_transition_lower,
                slot_transition_upper,
                slot_edge_distance);
        }
        float slot = stripe_coverage * y_coverage;
        if (channel_index < 0.5) mask.r = slot;
        else if (channel_index < 1.5) mask.g = slot;
        else mask.b = slot;
    }
    else if (mask_type == 2)
    {
        // Shadow mask: staggered RGB phosphor dots. Each channel has an elliptical emitting
        // region; alternate rows are displaced by half a triad. This is a generic dot-mask
        // approximation rather than an exact delta-triad layout from a specific tube.
        float dx_r = abs(phase_x - (1.0 / 6.0)); dx_r = min(dx_r, 1.0 - dx_r);
        float dx_g = abs(phase_x - 0.5);        dx_g = min(dx_g, 1.0 - dx_g);
        float dx_b = abs(phase_x - (5.0 / 6.0)); dx_b = min(dx_b, 1.0 - dx_b);
        float radius_x = max(stripe_width / 6.0, 0.025);
        float radius_y = 0.36;
        float dy = abs(row_phase - 0.5);
        float dy_norm = dy / radius_y;
        float dy2 = dy_norm * dy_norm;
        float dxr_norm = dx_r / radius_x;
        float dxg_norm = dx_g / radius_x;
        float dxb_norm = dx_b / radius_x;
        float dist_r = sqrt(dxr_norm * dxr_norm + dy2);
        float dist_g = sqrt(dxg_norm * dxg_norm + dy2);
        float dist_b = sqrt(dxb_norm * dxb_norm + dy2);
        mask = float3(
            1.0 - smoothstep(0.88, 1.04, dist_r),
            1.0 - smoothstep(0.88, 1.04, dist_g),
            1.0 - smoothstep(0.88, 1.04, dist_b));
    }

    return mask;
}

// Analytic integral of the aperture-grille stripe's smooth coverage function. The old
// 16-point box integration approximated this same 1D periodic profile; integrating its primitive
// over one output pixel removes those 16 evaluations without introducing a hard cell lookup.
float aperture_grille_transition_primitive(float z)
{
    float z2 = z * z;
    float z3 = z2 * z;
    float z4 = z2 * z2;
    return z - z3 + 0.5 * z4;
}

float aperture_grille_left_integral(float x, float inner, float outer)
{
    float lower_edge = max(0.5 - outer, 0.0);
    float upper_edge = 0.5 - inner;
    float width = max(outer - inner, 0.00001);
    float z_start = (0.5 - lower_edge - inner) / width;

    if (x <= lower_edge)
        return 0.0;

    if (x < upper_edge)
    {
        float z = (0.5 - x - inner) / width;
        return width * (aperture_grille_transition_primitive(z_start)
            - aperture_grille_transition_primitive(z));
    }

    return width * aperture_grille_transition_primitive(z_start) + x - upper_edge;
}

float aperture_grille_stripe_area(float inner, float outer)
{
    float lower_edge = max(0.5 - outer, 0.0);
    float width = max(outer - inner, 0.00001);
    float z_start = (0.5 - lower_edge - inner) / width;
    return 2.0 * (width * aperture_grille_transition_primitive(z_start) + inner);
}

float aperture_grille_coverage_integral(float x, float inner, float outer, float area)
{
    float period = floor(x);
    float phase = x - period;
    float local = (phase <= 0.5)
        ? aperture_grille_left_integral(phase, inner, outer)
        : area - aperture_grille_left_integral(1.0 - phase, inner, outer);
    return period * area + local;
}

// Integral over a three-cell RGB triad. Each channel occupies one cell per three-cell period.
float aperture_grille_channel_integral(float x, float channel, float inner, float outer, float area)
{
    float period = floor(x / 3.0);
    float phase = x - period * 3.0;
    float local;
    if (phase <= channel)
        local = 0.0;
    else if (phase >= channel + 1.0)
        local = area;
    else
        local = aperture_grille_coverage_integral(phase - channel, inner, outer, area);
    return period * area + local;
}

float3 analytic_aperture_grille(float pixel_x, float pitch, float inner, float outer, float area)
{
    float center = 3.0 * pixel_x / pitch;
    float half_span = 1.5 / pitch;
    float lo = center - half_span;
    float hi = center + half_span;
    float inv_span = 0.5 / max(half_span, 0.00001);
    return saturate(float3(
        (aperture_grille_channel_integral(hi, 0.0, inner, outer, area)
            - aperture_grille_channel_integral(lo, 0.0, inner, outer, area)) * inv_span,
        (aperture_grille_channel_integral(hi, 1.0, inner, outer, area)
            - aperture_grille_channel_integral(lo, 1.0, inner, outer, area)) * inv_span,
        (aperture_grille_channel_integral(hi, 2.0, inner, outer, area)
            - aperture_grille_channel_integral(lo, 2.0, inner, outer, area)) * inv_span));
}

float3 build_phosphor_mask(float2 uv, float2 screen_size)
{
    int mask_type = active_phosphor_mask_type();
    if (mask_type == 3)
        return float3(1.0, 1.0, 1.0);

    float mask_strength;
    float mask_pitch;
    float requested_width;
    float gap_fraction;
    float slot_height = PROFILE_SLOT_HEIGHT;
    bool using_profile_mask_defaults = (phosphor_mask_selection == 0);

    if (mask_type == 0)
    {
        if (using_profile_mask_defaults)
        {
            mask_strength = PROFILE_APERTURE_STRENGTH;
            mask_pitch = PROFILE_APERTURE_PITCH;
            requested_width = PROFILE_APERTURE_STRIPE_WIDTH;
            gap_fraction = PROFILE_APERTURE_GAP;
        }
        else
        {
            mask_strength = aperture_custom_strength;
            mask_pitch = aperture_custom_pitch;
            requested_width = aperture_custom_stripe_width;
            gap_fraction = aperture_custom_gap;
        }
    }
    else if (mask_type == 1)
    {
        if (using_profile_mask_defaults)
        {
            mask_strength = PROFILE_SLOT_STRENGTH;
            mask_pitch = PROFILE_SLOT_PITCH;
            requested_width = PROFILE_SLOT_WIDTH;
            gap_fraction = PROFILE_SLOT_GAP;
            slot_height = PROFILE_SLOT_HEIGHT;
        }
        else
        {
            mask_strength = slot_custom_strength;
            mask_pitch = slot_custom_pitch;
            requested_width = slot_custom_stripe_width;
            gap_fraction = slot_custom_gap;
            slot_height = slot_custom_height;
        }
    }
    else // Staggered shadow mask: explicitly selected, with its own custom settings.
    {
        if (using_profile_mask_defaults)
        {
            mask_strength = PROFILE_SHADOW_STRENGTH;
            mask_pitch = PROFILE_SHADOW_PITCH;
            requested_width = PROFILE_SHADOW_DOT_WIDTH;
            gap_fraction = PROFILE_SHADOW_GAP;
        }
        else
        {
            mask_strength = shadow_custom_strength;
            mask_pitch = shadow_custom_pitch;
            requested_width = shadow_custom_dot_width;
            gap_fraction = shadow_custom_gap;
        }
    }

    if (mask_strength <= 0.0001)
        return float3(1.0, 1.0, 1.0);

    float2 viewport_offset = source_viewport_offset_px();
    float2 viewport_size = source_viewport_size_px();
    float pitch;
    float2 pixel = uv * screen_size;
    if (mask_type == 0)
    {
        // Keep the RGB triplet period at or above three output pixels. Below that
        // limit a grille becomes spatially undersampled and aliases into false
        // color/brightness patterns. Scale against the active viewport, not bars.
        pitch = max(mask_pitch, 1.5) * (viewport_size.y / 1080.0);
        pitch = max(pitch, 3.0);
        pixel.x -= viewport_offset.x;
    }
    else
    {
        // Preserve existing slot/shadow-mask pitch and placement semantics.
        pitch = max(mask_pitch, 1.5) * (screen_size.y / 1080.0);
        pitch = max(pitch, 0.75);
    }
    requested_width = saturate(requested_width);
    gap_fraction = saturate(gap_fraction);
    float stripe_width = min(requested_width, 1.0 - gap_fraction);
    float inner = max(stripe_width * 0.5 - 0.015, 0.0);
    float outer = stripe_width * 0.5 + 0.015;
    float stripe_area = aperture_grille_stripe_area(inner, outer);
    float3 pattern = float3(0.0, 0.0, 0.0);

    if (mask_type == 0)
    {
        // Exact 1D coverage integral for the aperture grille; no 16-sample loop is needed.
        pattern = analytic_aperture_grille(pixel.x, pitch, inner, outer, stripe_area);
    }
    else
    {
        // Slot and staggered-dot masks remain 8x8 integrated because they are two-dimensional.
        for (int sy = 0; sy < 8; ++sy)
        {
            for (int sx = 0; sx < 8; ++sx)
            {
                float2 p = pixel + float2((sx + 0.5) * (1.0 / 8.0) - 0.5,
                                          (sy + 0.5) * (1.0 / 8.0) - 0.5);
                pattern += evaluate_phosphor_mask_sample(p, pitch, stripe_width,
                                                         slot_height, mask_type);
            }
        }
        pattern *= (1.0 / 64.0);
    }

    // Compensate average RGB transmission. The aperture-grille analytic integral has an exact
    // per-channel mean of stripe_width / 3. Slot and shadow-dot factors remain approximations.
    float mean_duty = (mask_type == 0) ? (stripe_area / 3.0) : (stripe_width / 3.0);
    if (mask_type == 1)
        mean_duty *= saturate(slot_height);
    else if (mask_type == 2)
        mean_duty *= 0.78539816339 * 0.72;

    float strength = saturate(mask_strength);
    float mean_transmission = lerp(1.0, mean_duty, strength);
    float3 mask = lerp(float3(1.0, 1.0, 1.0), pattern, strength);
    return mask / max(mean_transmission, 0.001);
}

// Analytic primitive of the existing damper-wire profile:
// 1 inside |d|<=0.25 px, a smoothstep shoulder to zero at |d|=1 px.
// Integrating the primitive over a one-pixel footprint removes subpixel shimmer
// without changing the wire's saved width or attenuation shape.
float damper_wire_positive_primitive(float distance_px)
{
    float d = abs(distance_px);
    if (d <= 0.25)
        return d;
    if (d >= 1.0)
        return 0.625;
    float t = (d - 0.25) / 0.75;
    return 0.25 + 0.75 * (t - t * t * t + 0.5 * t * t * t * t);
}

float damper_wire_signed_primitive(float signed_distance_px)
{
    float integral = damper_wire_positive_primitive(signed_distance_px);
    return (signed_distance_px < 0.0) ? -integral : integral;
}

float damper_wire_pixel_average(float pixel_center_y, float wire_center_y)
{
    float lo = pixel_center_y - 0.5;
    float hi = pixel_center_y + 0.5;
    return saturate(damper_wire_signed_primitive(hi - wire_center_y)
                  - damper_wire_signed_primitive(lo - wire_center_y));
}

float aperture_damper_transmission(float2 output_pixel_position)
{
    bool using_profile_mask_defaults = (phosphor_mask_selection == 0);
    bool wires_enabled = using_profile_mask_defaults
        ? PROFILE_APERTURE_DAMPERS : aperture_custom_damper_wires;
    float wire_strength = using_profile_mask_defaults
        ? PROFILE_APERTURE_WIRE_STRENGTH : aperture_custom_wire_strength;
    if (!wires_enabled || active_phosphor_mask_type() != 0)
        return 1.0;

    float2 viewport_offset = source_viewport_offset_px();
    float2 viewport_size = source_viewport_size_px();
    float wire_a_y = viewport_offset.y + viewport_size.y / 3.0;
    float wire_b_y = viewport_offset.y + 2.0 * viewport_size.y / 3.0;
    float wire_a = damper_wire_pixel_average(output_pixel_position.y, wire_a_y);
    float wire_b = damper_wire_pixel_average(output_pixel_position.y, wire_b_y);
    return 1.0 - wire_strength * max(wire_a, wire_b);
}

// Convert linear RGB channel drives through the selected display's approximate phosphor gamut,
// then express emitted light in the output monitor's linear BT.709 primaries. The Japanese P22
// profiles use the aggregate NTSC-J reference; KX-14CP1 uses the separate manually calibrated
// model profile documented in CRT-Guest. Both Toshiba takes use SMPTE-C primaries with different
// reference whites; Neutral bypasses the display transform.
//
// The Toshiba SMPTE-C -> BT.709 matrices below use standard SMPTE-C primaries (R 0.630/0.340,
// G 0.310/0.595, B 0.155/0.070) as a reference proxy, not measured Toshiba tube data. The Balanced Color
// take uses D65, preserving the existing Toshiba reference transform. The Warm take uses CIE D55
// (xy=0.33242, 0.34743) as an explicitly aesthetic, warmer white-point interpretation; this is
// not a measured AF/Cinema setting or a claim about its factory color temperature. The aggregate
// Japanese P22 estimates are from libretro's grade.slang reference, not a Sony-specific calibration.
float3 apply_display_color_profile(float3 rgb)
{
    // Neutral BT.709/D65 is a direct working-space bypass.
    if (display_profile == 6)
        return rgb;

    // Toshiba AF: same SMPTE-C primary approximation, two different white-point takes.
    if (display_profile == 4 || display_profile == 5)
    {
        float3 mapped_toshiba;
        if (display_profile == 5)
        {
            // Warm take: SMPTE-C primaries with a D55-style white.
            mapped_toshiba = float3(
                dot(rgb, float3( 1.04608966,  0.04954541,  0.00847210)),
                dot(rgb, float3( 0.01978766,  0.95355347,  0.01354909)),
                dot(rgb, float3(-0.00180550, -0.00431437,  0.82934834)));
        }
        else
        {
            // Balanced Color take: existing SMPTE-C primaries with D65 reference white, unchanged.
            mapped_toshiba = float3(
                dot(rgb, float3( 0.93954206,  0.05018136,  0.01027658)),
                dot(rgb, float3( 0.01777222,  0.96579286,  0.01643491)),
                dot(rgb, float3(-0.00162160, -0.00436975,  1.00599135)));
        }

        float y_toshiba = max(dot(mapped_toshiba, float3(0.2126, 0.7152, 0.0722)), 0.0);
        float min_toshiba = min(mapped_toshiba.r,
            min(mapped_toshiba.g, mapped_toshiba.b));
        if (min_toshiba < 0.0 && y_toshiba > 0.0)
        {
            float chroma_scale_toshiba = saturate(
                y_toshiba / max(y_toshiba - min_toshiba, 0.00001));
            mapped_toshiba = y_toshiba.xxx
                + (mapped_toshiba - y_toshiba.xxx) * chroma_scale_toshiba;
        }
        return max(mapped_toshiba, float3(0.0, 0.0, 0.0));
    }

    // KX-14CP1: CRT-Guest's manually calibrated model profile gives R (0.647, 0.335),
    // G (0.279, 0.635), B (0.152, 0.060), and white XYZ (0.903, 1.000, 1.185).
    // This matrix maps that profiled RGB basis into BT.709/D65. Its notes recommend Gamma Out 2.25.
    if (display_profile == 3)
    {
        float3 mapped_kx = float3(
            dot(rgb, float3( 0.91882817, -0.13068814,  0.01021891)),
            dot(rgb, float3( 0.00122467,  1.05152071, -0.00276214)),
            dot(rgb, float3(-0.00777756, -0.02628253,  1.13282834)));

        float y_kx = max(dot(mapped_kx, float3(0.2126, 0.7152, 0.0722)), 0.0);
        float min_kx = min(mapped_kx.r, min(mapped_kx.g, mapped_kx.b));
        if (min_kx < 0.0 && y_kx > 0.0)
        {
            float chroma_scale_kx = saturate(
                y_kx / max(y_kx - min_kx, 0.00001));
            mapped_kx = y_kx.xxx + (mapped_kx - y_kx.xxx) * chroma_scale_kx;
        }
        return max(mapped_kx, float3(0.0, 0.0, 0.0));
    }

    // Sony BVM-D24 EBU reference (D24E1WE / D24E1WA phosphor standard).
    // The nominal EBU primaries come from Sony's manual. Their matrix is
    // calculated with the actual white produced by the existing Japanese Cool
    // P22 matrix blend (D65 toward estimated NTSC-J at 71%). This deliberately
    // gives the EBU phosphors the same cool neutral character as Trinity's default;
    // it is a hybrid reference profile, not a factory BVM-D24 color-temperature
    // preset or a measured individual monitor calibration.
    if (display_profile == 2)
    {
        float3 mapped_ebu = float3(
            dot(rgb, float3( 0.85876539, -0.04575544,  0.00000000)),
            dot(rgb, float3( 0.00000000,  1.03887627,  0.00000000)),
            dot(rgb, float3( 0.00000000,  0.01225186,  1.15339305)));
        float y_ebu = max(dot(mapped_ebu, float3(0.2126, 0.7152, 0.0722)), 0.0);
        float min_ebu = min(mapped_ebu.r, min(mapped_ebu.g, mapped_ebu.b));
        if (min_ebu < 0.0 && y_ebu > 0.0)
        {
            float chroma_scale_ebu = saturate(
                y_ebu / max(y_ebu - min_ebu, 0.00001));
            mapped_ebu = y_ebu.xxx + (mapped_ebu - y_ebu.xxx) * chroma_scale_ebu;
        }
        return max(mapped_ebu, float3(0.0, 0.0, 0.0));
    }

    // Sony Trinitron / Japanese P22 profile. The P22 primaries and NTSC-J white are estimates
    // compiled from consumer CRT measurements and historical P22 data, not a factory calibration.
    float3 p22_d65 = float3(
         dot(rgb, float3( 1.08177006, -0.08841256,  0.00648352)),
         dot(rgb, float3( 0.03803245,  0.96001294,  0.00197753)),
         dot(rgb, float3(-0.00748256,  0.01517390,  0.99254868)));

    float3 p22_ntscj = float3(
         dot(rgb, float3( 0.82297198, -0.09424931,  0.00798715)),
         dot(rgb, float3( 0.02893373,  1.02339033,  0.00243615)),
         dot(rgb, float3(-0.00569246,  0.01617563,  1.22273749)));

    // The two matrices share the same P22 primaries and differ only in their reference white.
    // The D65 profile uses the D65 endpoint directly; the original Japanese take retains its
    // existing 71% interpolation toward the cooler NTSC-J white. Do not CAT-adapt that emitted
    // white back to D65: it would remove the intended blue-ish appearance on a D65 output.
    float3 mapped = (display_profile == 1)
        ? p22_d65
        : lerp(p22_d65, p22_ntscj, saturate(japanese_whitepoint / 100.0));

    // Hue-preserving compression for colors that fall below the output gamut's zero
    // boundary. Values above 1 are left for the existing highlight roll-off further down.
    float y = max(dot(mapped, float3(0.2126, 0.7152, 0.0722)), 0.0);
    float min_channel = min(mapped.r, min(mapped.g, mapped.b));
    if (min_channel < 0.0 && y > 0.0)
    {
        float chroma_scale = saturate(y / max(y - min_channel, 0.00001));
        mapped = y.xxx + (mapped - y.xxx) * chroma_scale;
    }

    return max(mapped, float3(0.0, 0.0, 0.0));
}

// Legacy NewPixie highlight roll-off, applied to luminance and shared by all RGB channels.
// This retains the grayscale tone curve while preserving the display profile's chromaticity.
// It is not itself the CRT EOTF (which is applied on input by decode_crt_eotf).
float filmic_luminance(float linear_luma)
{
    // Keep the legacy toe exactly at its saved 0.004 value when black_level
    // is unchanged. When the user adjusts the input black reference, move the
    // toe by the corresponding change after the retained 1.25 accumulation gain.
    // This coordinates the controls without retuning the default image.
    float toe = max(0.004 + 1.25 * (clamp(black_level, 0.0, 0.1) - 0.004), 0.0);
    float x = max(linear_luma - toe, 0.0);
    return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

float3 filmic(float3 linear_color)
{
    float3 source = max(linear_color, float3(0.0, 0.0, 0.0));
    float y = max(dot(source, float3(0.2126, 0.7152, 0.0722)), 0.0);
    float mapped_y = filmic_luminance(y);

    // Retain the existing project look: apply the luminance roll-off uniformly to RGB.
    float scale = (y > 0.00001) ? (mapped_y / y) : 0.0;
    float3 mapped = source * scale;
    float peak = max(mapped.r, max(mapped.g, mapped.b));
    if (peak > 1.0)
        mapped /= peak;
    return mapped;
}

float2 screen_fit_uv(float2 uv)
{
    // Keep NewPixie's aspect/framing compensation and inset, with a flat image plane.
    // Edge Zoom remains the crop control for modern displays.
    float2 p = (uv - 0.5) * float2(0.925, 1.095);
    return (p + 0.5) * 0.92 + 0.04;
}

float vignette_multiplier(float2 legacy_screen_uv, float2 output_pixel_position)
{
    float2 vignette_uv = legacy_screen_uv;
    if (vignette_mapping == 1)
    {
        float2 viewport_offset = source_viewport_offset_px();
        float2 viewport_size = max(source_viewport_size_px(), float2(1.0, 1.0));
        vignette_uv = saturate((output_pixel_position - viewport_offset) / viewport_size);
    }
    float shape = 0.1 + 16.0 * vignette_uv.x * vignette_uv.y
        * (1.0 - vignette_uv.x) * (1.0 - vignette_uv.y);
    return 1.3 * sqrt(max(shape, 0.1));
}

// Integer avalanche hash for repeatable per-cell grain values.
// Unsigned overflow is intentional: the arithmetic wraps modulo 2^32.
uint hash_noise_u32(uint value)
{
    value ^= value >> 16;
    value *= 0x7feb352du;
    value ^= value >> 15;
    value *= 0x846ca68bu;
    value ^= value >> 16;
    return value;
}

float hash_noise_value(uint2 cell, uint frame, uint channel)
{
    uint value = cell.x * 0x9e3779b9u;
    value ^= cell.y * 0x85ebca6bu;
    value ^= frame * 0xc2b2ae35u;
    value ^= channel * 0x27d4eb2fu;
    return (float)(hash_noise_u32(value) >> 8) * (1.0 / 16777216.0);
}

float spatial_grain_value(float2 pixel_position, uint frame, uint channel)
{
    // At the default size, retain crisp one-output-pixel grain. Above 1 px, blend into
    // smooth value noise on a coarser lattice instead of enlarging square random blocks.
    if (noise_grain_size <= 1.0001)
    {
        int2 fine_cell_signed = (int2)floor(pixel_position);
        uint2 fine_cell = (uint2)fine_cell_signed;
        return hash_noise_value(fine_cell, frame, channel);
    }

    float2 coarse_position = pixel_position / noise_grain_size;
    float2 coarse_floor = floor(coarse_position);
    float2 f = frac(coarse_position);
    float2 blend = f * f * (3.0 - 2.0 * f);
    uint2 cell = (uint2)((int2)coarse_floor);

    // Use a separate hash domain for the interpolated field, so the crossfade below
    // combines statistically independent fine and coarse samples.
    uint coarse_channel = channel + 16u;
    float n00 = hash_noise_value(cell, frame, coarse_channel);
    float n10 = hash_noise_value(cell + uint2(1u, 0u), frame, coarse_channel);
    float n01 = hash_noise_value(cell + uint2(0u, 1u), frame, coarse_channel);
    float n11 = hash_noise_value(cell + uint2(1u, 1u), frame, coarse_channel);

    float w00 = (1.0 - blend.x) * (1.0 - blend.y);
    float w10 = blend.x * (1.0 - blend.y);
    float w01 = (1.0 - blend.x) * blend.y;
    float w11 = blend.x * blend.y;
    float coarse_value = n00 * w00 + n10 * w10 + n01 * w01 + n11 * w11;

    // Normalize the interpolation's local variance so Grain Size changes correlation/scale,
    // not the nominal Noise Amount. The four lattice values are independent hashes.
    float spatial_norm = rsqrt(max(w00 * w00 + w10 * w10 + w01 * w01 + w11 * w11, 0.000001));
    coarse_value = 0.5 + (coarse_value - 0.5) * spatial_norm;

    // A short crossfade avoids a hard visual switch immediately above Grain Size = 1.
    float size_blend = smoothstep(1.0, 1.5, noise_grain_size);
    if (size_blend >= 0.999)
        return coarse_value;

    int2 fine_cell_signed = (int2)floor(pixel_position);
    uint2 fine_cell = (uint2)fine_cell_signed;
    float fine_value = hash_noise_value(fine_cell, frame, channel);
    float mixed = lerp(fine_value, coarse_value, size_blend);
    float blend_norm = rsqrt(max((1.0 - size_blend) * (1.0 - size_blend)
                               + size_blend * size_blend, 0.000001));
    return 0.5 + (mixed - 0.5) * blend_norm;
}

float animated_grain_value(float2 pixel_position, float frame_clock, uint channel)
{
    float frame_floor = floor(frame_clock);
    uint frame0 = (uint)frame_floor;
    float frame_fraction = frac(frame_clock);
    float value0 = spatial_grain_value(pixel_position, frame0, channel);
    if (frame_fraction <= 0.0001)
        return value0;

    uint frame1 = frame0 + 1u;
    if (frame1 >= 640u)
        frame1 = 0u;
    float value1 = spatial_grain_value(pixel_position, frame1, channel);
    float temporal_blend = frame_fraction * frame_fraction * (3.0 - 2.0 * frame_fraction);
    float mixed = lerp(value0, value1, temporal_blend);
    float temporal_norm = rsqrt(max((1.0 - temporal_blend) * (1.0 - temporal_blend)
                                  + temporal_blend * temporal_blend, 0.000001));
    return 0.5 + (mixed - 0.5) * temporal_norm;
}

// Native source-pixel dimensions in normalized accumulation-buffer UV coordinates.
// Fall back to a 240-line, square-displayed-pixel raster when DuckStation does not supply them.
float2 grain_native_pixel_uv_size()
{
    return source_native_pixel_size_uv();
}

// Map the output pixel back to the same centre source coordinate used by the green scene sample.
// This mirrors the screen-fit, Edge Zoom, interference and texture-coordinate transform in
// PS_RenderCRTScene, so native-aligned grain follows the game image rather than the monitor grid.
float2 grain_source_uv(float2 output_uv, float2 screen_uv)
{
    float2 scuv = (screen_uv - 0.5) * float2(1.0713922, 1.0821518) / edge_zoom + 0.5;
    float frame_number = animation_frame_clock();
    float render_time = mod(frame_number, 849.0) * 36.0;
    float interference_time = render_time * interference_speed;
    float wobble = interference_strength
        * sin(0.1 * interference_time + screen_uv.y * 13.0)
        * sin(0.23 * interference_time + screen_uv.y * 19.0)
        * sin(0.3 + 0.11 * interference_time + screen_uv.y * 23.0) * 0.0012;
    wobble += sin(output_uv.y * 1.5) / ReShade::ScreenSize.x * 0.25;

    float2 tc = float2(scuv.x + wobble, scuv.y - 0.0011 * fringe_amount);
    tc = tc * float2(1.025, 0.92) + float2(-0.0125, 0.04);
    return float2(tc.x, 1.0 - tc.y);
}

// Read the source-raster detail confidence captured during the adaptive 3x3
// analysis, before CRT masks/scanlines are applied. It protects isolated dots,
// irregular texture, luminance edges and equal-luminance color boundaries.
float grain_detail_factor(float2 source_uv)
{
    if (noise_detail_protection <= 0.0001 ||
        any(source_uv < 0.0) || any(source_uv > 1.0))
        return 1.0;

    // tSmoothV.a carries source-grid detail confidence from the same 3x3
    // analysis used by adaptive Pixel Smoothing. It is metadata, not opacity.
    float detail = saturate(tex2D(sSmoothV, source_uv).a);
    return lerp(1.0, 1.0 - 0.85 * detail,
                saturate(noise_detail_protection));
}

// Alignment mode 2 blends independent screen-grid and native-grid grain fields. The 1/sqrt(2)
// scale keeps their combined variance close to that of either field alone.
float aligned_grain_value(float2 output_position, float2 native_position,
                          float frame_clock, uint channel)
{
    if (noise_alignment == 1)
        return animated_grain_value(native_position, frame_clock, channel);
    if (noise_alignment == 2)
    {
        float output_field = animated_grain_value(output_position, frame_clock, channel + 8u);
        float native_field = animated_grain_value(native_position, frame_clock, channel + 24u);
        return 0.5 + ((output_field - 0.5) + (native_field - 0.5)) * 0.70710678;
    }
    return animated_grain_value(output_position, frame_clock, channel);
}


float4 PS_RenderCRTScene(float4 pos : SV_Position, float2 uv_tx : TEXCOORD0) : SV_Target
{
    float2 screen_size = ReShade::ScreenSize.xy;

    if (debug_view == 12)
        return float4(saturate(tex2D(GaussianBlurSampler, uv_tx).rgb * 4.0), 1.0);

    if (debug_view > 0 && debug_view <= 4)
    {
        float3 acc_now = tex2D(sAccumFrame, uv_tx).rgb;
        float3 cur_in = tex2D(ReShade::BackBuffer, uv_tx).rgb;
        float3 dbg = float3(0.0, 0.0, 0.0);
        if (debug_view == 1)
            dbg = acc_now;
        else if (debug_view == 2)
            dbg = cur_in;
        else if (debug_view == 3)
        {
            float3 cur_linear = decode_crt_eotf(cur_in) * 1.25;
            dbg = saturate(acc_now - cur_linear) * 4.0;
        }
        else
        {
            float3 flash = (mod((float)FCount, 2.0) > 0.5)
                ? float3(1.0, 0.0, 0.0) : float3(0.0, 0.0, 1.0);
            float3 tog = PX_INTERLACE ? float3(0.0, 0.8, 0.0) : float3(0.15, 0.15, 0.15);
            dbg = (uv_tx.x < 0.5) ? flash : tog;
        }
        return float4(dbg, 1.0);
    }

    if (debug_view == 5)
        return float4(build_phosphor_mask(uv_tx, screen_size), 1.0);
    if (debug_view == 19)
    {
        float3 debug_mask = build_phosphor_mask(uv_tx, screen_size);
        debug_mask *= aperture_damper_transmission(pos.xy);
        return float4(debug_mask, 1.0);
    }

    float frame_clock = animation_frame_clock();
    float time = mod(frame_clock, 849.0) * 36.0;
    float2 uv = uv_tx.xy;
    uv.y = 1.0 - uv_tx.y;

    // Compensate the retained flat screen-fit inset; Edge Zoom adds user-controlled cropping.
    // x: 1 / ((0.6 * 0.925 * 0.92 + 0.4) * 1.025) ~= 1.0713922
    // y: 1 / ((0.6 * 1.095 * 0.92 + 0.4) * 0.92) ~= 1.0821518
    float2 screen_uv = lerp(screen_fit_uv(uv), uv, 0.4);
    float2 scuv = (screen_uv - 0.5) * float2(1.0713922, 1.0821518) / edge_zoom + 0.5;

    float3 col;
    float interference_time = time * interference_speed;
    float x = interference_strength * sin(0.1 * interference_time + screen_uv.y * 13.0)
        * sin(0.23 * interference_time + screen_uv.y * 19.0)
        * sin(0.3 + 0.11 * interference_time + screen_uv.y * 23.0) * 0.0012;
    float o = sin(uv_tx.y * 1.5) / screen_size.x;
    x += o * 0.25;

    time = mod(frame_clock, 640.0);
    col.r = tsample_soft(
        float2(x + scuv.x + 0.0009 * fringe_amount, scuv.y + 0.0009 * fringe_amount)).r;
    col.g = tsample_soft(
        float2(x + scuv.x, scuv.y - 0.0011 * fringe_amount)).g;
    col.b = tsample_soft(
        float2(x + scuv.x - 0.0015 * fringe_amount, scuv.y)).b;

    // Capture beam drive before ghosting, halation, profile, contrast, and vignette. Optical
    // spread must not feed back into the simulated electron-beam width.
    float beam_luma = clamp(dot(col, float3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
    // Algebraically identical to the legacy two-step shaping below, reusing beam_luma.
    float i = 0.15 + 0.85 * beam_luma * beam_luma;

    // The Per-source-line RGB model reconstructs native source lines here,
    // while the signal is still in the linear source domain of sSmoothV. Its RGB
    // beam attenuation can either remain here (Source-Domain) or be deferred to
    // the late display stage (Post-Display). Shared Beam remains unchanged.
    float per_source_beam_scanline_factor = 1.0;
    float3 per_source_beam_scanline_rgb_factor = float3(1.0, 1.0, 1.0);
    if (PX_SCANLINES_ENABLED && PX_SCANLINE_PROFILE != 0
        && PX_VERTICAL_BEAM_MODEL == 1 && PX_SCANLINE_STRENGTH > 0.0001)
    {
        float beam_tcy = scuv.y * 0.92 + 0.04;
        float beam_stock_phase = screen_uv.y * screen_size.y * 1.5;
        bool beam_use_native_pitch = PX_NATIVE_SCANLINE_PITCH
            && NativeWidth > 0.0 && NativeHeight > 0.0;
        bool beam_use_manual_pitch = !beam_use_native_pitch && PX_SCANLINE_LINES > 0.5;
        float beam_native_line_cycles = beam_tcy
            / max(source_native_pixel_size_uv().y, 0.000001);
        float beam_selected_line_cycles = beam_use_native_pitch
            ? beam_native_line_cycles : beam_tcy * PX_SCANLINE_LINES;
        // Alternating Field Phase changes this global beam phase by PI on odd
        // rendered frames. Dividing by 2*PI below makes that an exact half-cycle
        // displacement of the Per-source-line RGB beam pattern. Source-line sample
        // positions stay anchored; their beam weights are redistributed around them.
        float beam_frame_parity = mod((float)FCount, 2.0);
        float beam_field_phase = (PX_INTERLACE && beam_frame_parity > 0.5)
            ? 3.14159265359 : 0.0;
        float beam_rolling_phase = PX_SCANROLL
            ? mod(6.0 * frame_clock, 6.28318530718) : 0.0;
        float beam_line_cycles = (beam_use_native_pitch || beam_use_manual_pitch)
            ? beam_selected_line_cycles : (beam_stock_phase / 6.28318530718);
        float beam_phase_origin = (beam_use_native_pitch || beam_use_manual_pitch)
            ? 0.5 : 0.75;
        float beam_line_shift = (beam_rolling_phase - beam_field_phase)
            / 6.28318530718;
        // With rolling disabled, the alternating PI phase moves beam_coordinate
        // by 0.5 line cycle on odd frames: this is the source of the rapid flicker.
        float beam_coordinate = beam_line_cycles - beam_phase_origin - beam_line_shift;
        float beam_pixel_height = max(abs(ddy(beam_line_cycles)), 0.00001);
        int beam_centre_line = (int)floor(beam_coordinate + 0.5);

        float beam_sharpness_t = saturate((PX_SCANLINE_SHARPNESS - 0.5) / 2.5);
        float beam_base_sigma = max(lerp(0.14, 0.055, beam_sharpness_t), 0.02);
        float beam_max_sigma = beam_base_sigma * (1.0 + 0.65 * PX_SCANLINE_BEAM);
        float beam_support_radius = beam_profile_source_line_radius(
            beam_max_sigma, PX_BEAM_SPOT_PROFILE);
        int beam_line_support = clamp(
            (int)ceil(beam_support_radius + 0.5 * beam_pixel_height + 0.5), 1, 8);
        float3 beam_color_sum = float3(0.0, 0.0, 0.0);
        float3 beam_weight_sum = float3(0.0, 0.0, 0.0);
        [loop]
        for (int line_tap = -8; line_tap <= 8; ++line_tap)
        {
            if (abs(line_tap) <= beam_line_support)
            {
                int source_line = beam_centre_line + line_tap;
                float signed_distance = beam_coordinate - (float)source_line;
                bool overlaps_line = abs(signed_distance)
                    < beam_support_radius + 0.5 * beam_pixel_height;
                if (overlaps_line)
                {
                    // Source content remains anchored to the native line; the beam
                    // phase (including rolling/interlace) moves independently over it.
                    float source_line_cycles = (float)source_line + beam_phase_origin;
                    float line_scuv_y;
                    if (beam_use_native_pitch)
                    {
                        float line_tcy = source_line_cycles
                            * source_native_pixel_size_uv().y;
                        line_scuv_y = (line_tcy - 0.04) / 0.92;
                    }
                    else if (beam_use_manual_pitch)
                    {
                        float line_tcy = source_line_cycles / max(PX_SCANLINE_LINES, 0.5);
                        line_scuv_y = (line_tcy - 0.04) / 0.92;
                    }
                    else
                    {
                        float line_screen_uv_y = source_line_cycles
                            * 6.28318530718 / max(screen_size.y * 1.5, 0.00001);
                        line_scuv_y = (line_screen_uv_y - 0.5)
                            * 1.0821518 / edge_zoom + 0.5;
                    }

                    float line_screen_uv_y = (line_scuv_y - 0.5)
                        * edge_zoom / 1.0821518 + 0.5;
                    float line_interference_x = interference_strength
                        * sin(0.1 * interference_time + line_screen_uv_y * 13.0)
                        * sin(0.23 * interference_time + line_screen_uv_y * 19.0)
                        * sin(0.3 + 0.11 * interference_time + line_screen_uv_y * 23.0)
                        * 0.0012;
                    line_interference_x += sin(uv_tx.y * 1.5)
                        / screen_size.x * 0.25;

                    float2 line_uv_r = float2(
                        (line_interference_x + scuv.x + 0.0009 * fringe_amount)
                            * 1.025 - 0.0125,
                        1.0 - ((line_scuv_y + 0.0009 * fringe_amount) * 0.92 + 0.04));
                    float2 line_uv_g = float2(
                        (line_interference_x + scuv.x) * 1.025 - 0.0125,
                        1.0 - ((line_scuv_y - 0.0011 * fringe_amount) * 0.92 + 0.04));
                    float2 line_uv_b = float2(
                        (line_interference_x + scuv.x - 0.0015 * fringe_amount)
                            * 1.025 - 0.0125,
                        1.0 - (line_scuv_y * 0.92 + 0.04));

                    float line_mask_r = edge_mask(line_uv_r);
                    float line_mask_g = edge_mask(line_uv_g);
                    float line_mask_b = edge_mask(line_uv_b);
                    float3 line_r = tex2D(sSmoothV, line_uv_r).rgb;
                    float3 line_g = tex2D(sSmoothV, line_uv_g).rgb;
                    float3 line_b = tex2D(sSmoothV, line_uv_b).rgb;

                    // Each source line and gun channel has its own drive and sigma.
                    // Existing Vertical Source-Pixel Smoothing has already run in
                    // sSmoothV; it is not repeated in this beam integration.
                    float current_r = pow(saturate(line_r.r / 1.25), PX_BEAM_CURRENT_RESPONSE);
                    float current_g = pow(saturate(line_g.g / 1.25), PX_BEAM_CURRENT_RESPONSE);
                    float current_b = pow(saturate(line_b.b / 1.25), PX_BEAM_CURRENT_RESPONSE);
                    float sigma_r = max(beam_base_sigma
                        * (1.0 + 0.65 * PX_SCANLINE_BEAM * current_r), 0.02);
                    float sigma_g = max(beam_base_sigma
                        * (1.0 + 0.65 * PX_SCANLINE_BEAM * current_g), 0.02);
                    float sigma_b = max(beam_base_sigma
                        * (1.0 + 0.65 * PX_SCANLINE_BEAM * current_b), 0.02);

                    float raw_r = beam_profile_source_line_pixel_average(
                        signed_distance, beam_pixel_height, sigma_r, PX_BEAM_SPOT_PROFILE);
                    float raw_g = beam_profile_source_line_pixel_average(
                        signed_distance, beam_pixel_height, sigma_g, PX_BEAM_SPOT_PROFILE);
                    float raw_b = beam_profile_source_line_pixel_average(
                        signed_distance, beam_pixel_height, sigma_b, PX_BEAM_SPOT_PROFILE);
                    float mean_r = beam_profile_source_line_area(
                        sigma_r, PX_BEAM_SPOT_PROFILE);
                    float mean_g = beam_profile_source_line_area(
                        sigma_g, PX_BEAM_SPOT_PROFILE);
                    float mean_b = beam_profile_source_line_area(
                        sigma_b, PX_BEAM_SPOT_PROFILE);
                    float weight_r = raw_r / max(mean_r, 0.001) * line_mask_r;
                    float weight_g = raw_g / max(mean_g, 0.001) * line_mask_g;
                    float weight_b = raw_b / max(mean_b, 0.001) * line_mask_b;

                    beam_color_sum.r += line_r.r * weight_r;
                    beam_color_sum.g += line_g.g * weight_g;
                    beam_color_sum.b += line_b.b * weight_b;
                    beam_weight_sum += float3(weight_r, weight_g, weight_b);
                }
            }
        }

        // Normalize the weighted source color so chromatic line reconstruction is
        // preserved, while the independent accumulated beam factor retains the
        // spatial scanline profile. Each truncated source-line kernel has unit area.
        float amount = saturate(PX_SCANLINE_STRENGTH / 2.0);
        float3 reconstructed_source_color = beam_color_sum
            / max(beam_weight_sum, float3(0.0001, 0.0001, 0.0001));
        float3 beam_channel_factor = pow(
            saturate(beam_weight_sum * PX_BEAM_AVERAGE_DRIVE), float3(0.9, 0.9, 0.9));
        per_source_beam_scanline_rgb_factor = lerp(
            float3(1.0, 1.0, 1.0), beam_channel_factor, amount);
        per_source_beam_scanline_factor = dot(
            per_source_beam_scanline_rgb_factor, float3(0.2126, 0.7152, 0.0722));

        if (PX_PER_SOURCE_LINE_ATTENUATION_STAGE == 0)
        {
            // Existing behaviour: source-line RGB color reconstruction and its
            // per-channel beam attenuation both enter before ghosting/mask/profile.
            float3 beam_output = reconstructed_source_color * beam_channel_factor;
            col = lerp(col, beam_output, amount);
        }
        else
        {
            // Alternative: reconstruct the source color here, but defer the
            // per-channel beam attenuation until the Shared Beam display stage.
            col = lerp(col, reconstructed_source_color, amount);
        }
    }

    // Ghosting reads the already-linear separable blur buffer.
    if (ghost_strength > 0.00001)
    {
        float ghs = 0.017 * ghost_strength;
        float3 r = tsample_blurred(
            GaussianBlurSampler,
            float2(x - 0.014, -0.027) * 0.85
            + 0.007 * float2(
                0.35 * sin(1.0 / 7.0 + 15.0 * screen_uv.y + 0.9 * time),
                0.35 * sin(2.0 / 7.0 + 10.0 * screen_uv.y + 1.37 * time))
            + float2(scuv.x + 0.001, scuv.y + 0.001))
            * float3(0.5, 0.25, 0.25);

        float3 g = tsample_blurred(
            GaussianBlurSampler,
            float2(x - 0.019, -0.020) * 0.85
            + 0.007 * float2(
                0.35 * cos(1.0 / 9.0 + 15.0 * screen_uv.y + 0.5 * time),
                0.35 * sin(2.0 / 9.0 + 10.0 * screen_uv.y + 1.50 * time))
            + float2(scuv.x, scuv.y - 0.002))
            * float3(0.25, 0.5, 0.25);

        float3 b = tsample_blurred(
            GaussianBlurSampler,
            float2(x - 0.017, -0.003) * 0.85
            + 0.007 * float2(
                0.35 * sin(2.0 / 3.0 + 15.0 * screen_uv.y + 0.7 * time),
                0.35 * cos(2.0 / 3.0 + 10.0 * screen_uv.y + 1.63 * time))
            + float2(scuv.x - 0.002, scuv.y))
            * float3(0.25, 0.25, 0.5);

        float3 ghost_r = clamp(3.0 * r, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
        float3 ghost_g = clamp(3.0 * g, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
        float3 ghost_b = clamp(3.0 * b, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
        col += ghs * (1.0 - 0.2126) * ghost_r * ghost_r * i;
        col += ghs * (1.0 - 0.7152) * ghost_g * ghost_g * i;
        col += ghs * (1.0 - 0.0722) * ghost_b * ghost_b * i;
    }

    // The mask modulates individual P22 phosphor drives before the P22-to-BT.709 transform.
    // Subpixel coverage filtering supports non-integer pitches and scales pitch with output height.
    col *= build_phosphor_mask(uv_tx, screen_size);

    // Optional damping-wire transmission is part of the aperture-grille structure.
    col *= aperture_damper_transmission(pos.xy);

    col = apply_display_color_profile(col);

    // Optical halation is generated in a later pass from this completed, phosphor-masked
    // and scanline-modulated scene. This keeps the glow source tied to actual CRT emission.
    // Apply the legacy contrast curve to luminance, then scale RGB uniformly. This preserves
    // the selected CRT white point and avoids independently bending the three color channels.
    float contrast_luma = max(dot(col, float3(0.2126, 0.7152, 0.0722)), 0.0);
    float curved_luma = clamp(
        contrast_luma * 1.3 + 0.75 * contrast_luma * contrast_luma
            + 1.25 * contrast_luma * contrast_luma * contrast_luma * contrast_luma * contrast_luma,
        0.0, 10.0);
    float contrast_scale = (contrast_luma > 0.00001)
        ? (curved_luma / contrast_luma) : 1.0;
    col = lerp(col, col * contrast_scale, contrast_curve);

    // Desaturate toward the selected display white. For the NTSC-J profile this is not (1,1,1)
    // in BT.709 RGB; mixing toward equal RGB would pull the neutral axis back toward D65.
    float3 neutral_white = apply_display_color_profile(float3(1.0, 1.0, 1.0));
    float neutral_luma = max(dot(neutral_white, float3(0.2126, 0.7152, 0.0722)), 0.00001);
    neutral_white /= neutral_luma;
    float lum_sat = max(dot(col, float3(0.2126, 0.7152, 0.0722)), 0.0);
    col = lerp(neutral_white * lum_sat, col, saturation);

    // Legacy Fit preserves the previous screen-fit framing; Symmetric Viewport uses
    // normalized coordinates of the actual active DuckStation image rectangle.
    float vig = vignette_multiplier(screen_uv, pos.xy);
    col *= lerp(1.0, vig, vignette_strength);

        float tcy = scuv.y * 0.92 + 0.04;
    float stock_phase = screen_uv.y * screen_size.y * 1.5;
    bool use_native_pitch = PX_NATIVE_SCANLINE_PITCH && NativeWidth > 0.0 && NativeHeight > 0.0;
    bool use_manual_pitch = !use_native_pitch && PX_SCANLINE_LINES > 0.5;
    float native_line_cycles = tcy / max(source_native_pixel_size_uv().y, 0.000001);
    float selected_line_cycles = use_native_pitch ? native_line_cycles : tcy * PX_SCANLINE_LINES;
    float lines_phase = selected_line_cycles * 6.28318530718 + 1.57079632679;
    float line_phase = (use_native_pitch || use_manual_pitch) ? lines_phase : stock_phase;
    float frame_parity = mod((float)FCount, 2.0);
    float field_phase = (PX_INTERLACE && frame_parity > 0.5) ? 3.14159265359 : 0.0;
    // 6 rad per 1/60-second reference frame; wrap on a full turn to avoid phase jumps.
    float rolling_phase = PX_SCANROLL ? mod(6.0 * frame_clock, 6.28318530718) : 0.0;
    float scans = 1.0;
    float s = 1.0;

    if (PX_SCANLINES_ENABLED && PX_SCANLINE_STRENGTH > 0.0001)
    {
        if (PX_SCANLINE_PROFILE == 0)
        {
            // Retained legacy Sine waveform. It remains available internally but is not
            // exposed as a UI choice; Gaussian Beam is the saved default.
            float lum = clamp(dot(col, float3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
            float amp = 0.18 * PX_SCANLINE_STRENGTH * (1.0 - PX_SCANLINE_BEAM * lum);
            float sl = sin(rolling_phase - line_phase - field_phase);
            float shaped = sign(sl) * pow(abs(sl), PX_SCANLINE_SHARPNESS);
            float scanline_floor = lerp(1.0, 0.35, saturate(PX_SCANLINE_STRENGTH));
            scans = clamp(scanline_floor + amp * shaped, 0.0, 1.0);
            s = pow(saturate(scans), 0.9);
            col *= s;
        }
        else if (PX_VERTICAL_BEAM_MODEL == 1)
        {
            // Per-source-line RGB reconstructs each native source line independently.
            // Post-Display mode defers only its channel-specific beam factor to this stage.
            // The scalar is retained in alpha for Halation Respects Scanlines.
            s = per_source_beam_scanline_factor;
            if (PX_PER_SOURCE_LINE_ATTENUATION_STAGE == 1)
                col *= per_source_beam_scanline_rgb_factor;
        }
        else
        {
            // Shared Beam: selected Gaussian-family profile integrated over the output-pixel footprint.
            float line_cycles = (use_native_pitch || use_manual_pitch)
                ? selected_line_cycles
                : (stock_phase / 6.28318530718);
            float phase_origin = (use_native_pitch || use_manual_pitch) ? 0.5 : 0.75;
            float beam_center = frac(phase_origin + (rolling_phase - field_phase) / 6.28318530718);
            float line_pos = frac(line_cycles);

            float sharpness_t = saturate((PX_SCANLINE_SHARPNESS - 0.5) / 2.5);
            float sigma = lerp(0.14, 0.055, sharpness_t);
            float current = pow(saturate(beam_luma), PX_BEAM_CURRENT_RESPONSE);
            sigma *= 1.0 + 0.65 * PX_SCANLINE_BEAM * current;
            sigma = max(sigma, 0.02);

            float line_pixel_height = max(abs(ddy(line_cycles)), 0.00001);
            float signed_distance = line_pos - beam_center;
            signed_distance -= floor(signed_distance + 0.5);
            float beam_raw = beam_profile_pixel_average(
                signed_distance, line_pixel_height, sigma, PX_BEAM_SPOT_PROFILE);
            float beam_mean = beam_profile_integral(-0.5, 0.5, sigma, PX_BEAM_SPOT_PROFILE);
            float normalized_beam = beam_raw / max(beam_mean, 0.001);
            float beam_drive = normalized_beam * PX_BEAM_AVERAGE_DRIVE;
            scans = lerp(1.0, beam_drive, saturate(PX_SCANLINE_STRENGTH / 2.0));
            s = pow(saturate(scans), 0.9);
            col *= s;
        }
    }
    if (debug_view == 13)
        return float4(s.xxx, 1.0);

    // Keep the image in linear light until bloom is added. The RGBA16F scene target retains
    // highlights above 1.0 while reducing full-resolution render-target bandwidth.
    col *= brightness;
    // Alpha records local scanline attenuation for the optional scanline-modulated halation mode.
    return float4(col, s);
}

// Build halation from the completed CRT emission, after phosphor masking, display primaries,
// contrast/saturation, vignette, scanline modulation and brightness. The result is a scalar
// luminance bright-pass; tint and the A/B scanline choice are applied when it is composited.
float halation_brightpass(float2 uv)
{
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        return 0.0;

    float3 emitted = max(tex2D(sCrtScene, uv).rgb, float3(0.0, 0.0, 0.0));
    float luminance = dot(emitted, float3(0.2126, 0.7152, 0.0722));
    float threshold_range = max(1.0 - halation_threshold, 0.001);
    return saturate((luminance - halation_threshold) / threshold_range);
}

float4 PS_HalationBlurHorizontal(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    bool halation_diagnostic = (debug_view >= 14 && debug_view <= 16);
    if (debug_view == 14)
        return float4(halation_brightpass(uv) * 4.0, 0.0, 0.0, 0.0);
    if (halation_strength <= 0.00001 && !halation_diagnostic)
        return float4(0.0, 0.0, 0.0, 0.0);
    if (blur_x <= 0.00001)
        return float4(halation_brightpass(uv), 0.0, 0.0, 0.0);

    // Keep the full nine evaluations: bright-pass thresholding is nonlinear,
    // so bilinear pairing before that function would not equal pairing its output.
    float2 stp = float2(blur_x, 0.0) * ReShade::PixelSize.xy;
    float sum = halation_brightpass(uv) * 0.2270270270;
    sum += halation_brightpass(uv - 4.0 * stp) * 0.0162162162;
    sum += halation_brightpass(uv - 3.0 * stp) * 0.0540540541;
    sum += halation_brightpass(uv - 2.0 * stp) * 0.1216216216;
    sum += halation_brightpass(uv - 1.0 * stp) * 0.1945945946;
    sum += halation_brightpass(uv + 1.0 * stp) * 0.1945945946;
    sum += halation_brightpass(uv + 2.0 * stp) * 0.1216216216;
    sum += halation_brightpass(uv + 3.0 * stp) * 0.0540540541;
    sum += halation_brightpass(uv + 4.0 * stp) * 0.0162162162;
    return float4(sum, 0.0, 0.0, 0.0);
}
float4 PS_HalationBlurVertical(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    if (debug_view == 14 || debug_view == 15)
        return float4(0.0, 0.0, 0.0, 0.0);
    if (halation_strength <= 0.00001 && debug_view != 16)
        return float4(0.0, 0.0, 0.0, 0.0);
    if (blur_y <= 0.00001)
        return float4(tex2D(GaussianBlurTempSampler, uv).r * blur_valid_y(uv.y), 0.0, 0.0, 0.0);

    float2 stp = float2(0.0, blur_y) * ReShade::PixelSize.xy;
    bool pairable = abs(blur_y - 0.5) < 0.0001 || abs(blur_y - 1.0) < 0.0001;
    bool safe_pair_region = uv.y > (4.0 * stp.y + 2.0 * ReShade::PixelSize.y)
        && uv.y < (1.0 - 4.0 * stp.y - 2.0 * ReShade::PixelSize.y);
    if (pairable && safe_pair_region)
    {
        float paired = tex2D(GaussianBlurTempSampler, uv).r * 0.2270270270;
        paired += tex2D(GaussianBlurTempSampler, uv - 1.3846153846 * stp).r * 0.3162162162;
        paired += tex2D(GaussianBlurTempSampler, uv + 1.3846153846 * stp).r * 0.3162162162;
        paired += tex2D(GaussianBlurTempSampler, uv - 3.2307692308 * stp).r * 0.0702702703;
        paired += tex2D(GaussianBlurTempSampler, uv + 3.2307692308 * stp).r * 0.0702702703;
        return float4(paired, 0.0, 0.0, 0.0);
    }

    float2 tap = uv;
    float sum = tex2D(GaussianBlurTempSampler, tap).r
        * (0.2270270270 * blur_valid_y(tap.y));
    tap = uv - 4.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap).r * (0.0162162162 * blur_valid_y(tap.y));
    tap = uv - 3.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap).r * (0.0540540541 * blur_valid_y(tap.y));
    tap = uv - 2.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap).r * (0.1216216216 * blur_valid_y(tap.y));
    tap = uv - 1.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap).r * (0.1945945946 * blur_valid_y(tap.y));
    tap = uv + 1.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap).r * (0.1945945946 * blur_valid_y(tap.y));
    tap = uv + 2.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap).r * (0.1216216216 * blur_valid_y(tap.y));
    tap = uv + 3.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap).r * (0.0540540541 * blur_valid_y(tap.y));
    tap = uv + 4.0 * stp;
    sum += tex2D(GaussianBlurTempSampler, tap).r * (0.0162162162 * blur_valid_y(tap.y));
    return float4(sum, 0.0, 0.0, 0.0);
}

float3 halation_contribution(float2 faceplate_uv, float scanline_factor)
{
    if (halation_strength <= 0.00001)
        return float3(0.0, 0.0, 0.0);

    float halation = tex2D(GaussianBlurSampler, faceplate_uv).r;
    // A is the default optical model: the blur spreads into dark scanline gaps. B is a
    // selectable stylized mode that reapplies the local, pre-blur scanline attenuation.
    if (halation_respects_scanlines)
        halation *= saturate(scanline_factor);

    float3 halation_tint = lerp(
        float3(1.0, 1.0, 1.0),
        float3(1.0, 0.72, 0.48),
        halation_warmth);
    return halation_strength * halation * halation_tint;
}

// Extract colored highlights from the post-phosphor, post-scanline linear scene. A soft-knee
// threshold avoids an abrupt cutoff; RGB is retained rather than reducing bloom to white luma.
float3 extract_bloom_highlights(float3 source)
{
    source = max(source, float3(0.0, 0.0, 0.0));
    float peak = max(source.r, max(source.g, source.b));
    float threshold = max(bloom_threshold, 0.0001);
    float knee = threshold * saturate(bloom_soft_knee);
    float contribution;

    if (knee > 0.00001)
    {
        float soft = clamp(peak - threshold + knee, 0.0, 2.0 * knee);
        soft = soft * soft / (4.0 * knee);
        contribution = max(peak - threshold, soft);
    }
    else
    {
        contribution = max(peak - threshold, 0.0);
    }

    // Scale the full RGB vector by the same factor, preserving the highlight hue.
    return source * (contribution / max(peak, 0.00001));
}

// Downsample the actual post-mask/post-scanline phosphor image. The 4x4 box prefilter averages
// subpixel grille structure before the wider blur, reducing mask-phase aliasing in the bloom.
// Threshold the individual source samples before averaging so small bright highlights are not
// diluted below threshold merely by the downsample.
float4 PS_ExtractBloom(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    bool bloom_diagnostic = (debug_view == 7 || debug_view == 8);
    if ((!bloom_diagnostic && debug_view != 0) ||
        (bloom_intensity <= 0.0 && !bloom_diagnostic))
        return float4(0.0, 0.0, 0.0, 0.0);

    float2 source_pixel = ReShade::PixelSize.xy;
    float3 sum = float3(0.0, 0.0, 0.0);
    for (int sy = 0; sy < 4; ++sy)
    {
        for (int sx = 0; sx < 4; ++sx)
        {
            float2 sample_uv = uv + (float2((float)sx, (float)sy) - 1.5) * source_pixel;
            float4 crt_sample = tex2D(sCrtScene, sample_uv);
            float3 sample_color = crt_sample.rgb
                + halation_contribution(sample_uv, crt_sample.a);
            sum += extract_bloom_highlights(sample_color);
        }
    }
    return float4(sum * (1.0 / 16.0), 0.0);
}

// Separable Gaussian blur at quarter resolution. UV tap spacing is still expressed in full-size
// output pixels, so Bloom Radius retains the same 1080p reference meaning as the old full-res path.
float4 PS_BloomBlurHorizontal(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    // Diagnostic 8 copies the pre-blur extraction through both ping-pong targets.
    if (debug_view == 8)
        return tex2D(sBloomA, uv);
    if ((debug_view != 0 && debug_view != 7) ||
        (bloom_intensity <= 0.0 && debug_view != 7))
        return float4(0.0, 0.0, 0.0, 0.0);

    float pixel_reach = bloom_radius * (ReShade::ScreenSize.y / 1080.0) * 0.25;
    float2 stp = float2(pixel_reach, 0.0) * ReShade::PixelSize.xy;
    float target_step = pixel_reach * ((float)(BUFFER_WIDTH / 4) / (float)BUFFER_WIDTH);
    bool pairable_step = abs(target_step - 0.5) < 0.0001
        || abs(target_step - 1.0) < 0.0001;
    // The bilinear-paired form is exact for half- or whole-quarter-texel spacing when the
    // full kernel stays inside the image. Other radii/resolutions use the original 9 taps.
    bool safe_pair_region = uv.x > (4.0 * stp.x + 2.0 * ReShade::PixelSize.x)
        && uv.x < (1.0 - 4.0 * stp.x - 2.0 * ReShade::PixelSize.x);
    if (pairable_step && safe_pair_region)
    {
        float4 paired = tex2D(sBloomA, uv) * 0.2270270270;
        paired += tex2D(sBloomA, uv - 1.3846153846 * stp) * 0.3162162162;
        paired += tex2D(sBloomA, uv + 1.3846153846 * stp) * 0.3162162162;
        paired += tex2D(sBloomA, uv - 3.2307692308 * stp) * 0.0702702703;
        paired += tex2D(sBloomA, uv + 3.2307692308 * stp) * 0.0702702703;
        return paired;
    }

    float4 sum = tex2D(sBloomA, uv) * 0.2270270270;
    sum += tex2D(sBloomA, uv - 4.0 * stp) * 0.0162162162;
    sum += tex2D(sBloomA, uv - 3.0 * stp) * 0.0540540541;
    sum += tex2D(sBloomA, uv - 2.0 * stp) * 0.1216216216;
    sum += tex2D(sBloomA, uv - 1.0 * stp) * 0.1945945946;
    sum += tex2D(sBloomA, uv + 1.0 * stp) * 0.1945945946;
    sum += tex2D(sBloomA, uv + 2.0 * stp) * 0.1216216216;
    sum += tex2D(sBloomA, uv + 3.0 * stp) * 0.0540540541;
    sum += tex2D(sBloomA, uv + 4.0 * stp) * 0.0162162162;
    return sum;
}

float4 PS_BloomBlurVertical(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
    if (debug_view == 8)
        return tex2D(sBloomB, uv);
    if ((debug_view != 0 && debug_view != 7) ||
        (bloom_intensity <= 0.0 && debug_view != 7))
        return float4(0.0, 0.0, 0.0, 0.0);

    float pixel_reach = bloom_radius * (ReShade::ScreenSize.y / 1080.0) * 0.25;
    float2 stp = float2(0.0, pixel_reach) * ReShade::PixelSize.xy;
    float target_step = pixel_reach * ((float)(BUFFER_HEIGHT / 4) / (float)BUFFER_HEIGHT);
    bool pairable_step = abs(target_step - 0.5) < 0.0001
        || abs(target_step - 1.0) < 0.0001;
    bool safe_pair_region = uv.y > (4.0 * stp.y + 2.0 * ReShade::PixelSize.y)
        && uv.y < (1.0 - 4.0 * stp.y - 2.0 * ReShade::PixelSize.y);
    if (pairable_step && safe_pair_region)
    {
        float4 paired = tex2D(sBloomB, uv) * 0.2270270270;
        paired += tex2D(sBloomB, uv - 1.3846153846 * stp) * 0.3162162162;
        paired += tex2D(sBloomB, uv + 1.3846153846 * stp) * 0.3162162162;
        paired += tex2D(sBloomB, uv - 3.2307692308 * stp) * 0.0702702703;
        paired += tex2D(sBloomB, uv + 3.2307692308 * stp) * 0.0702702703;
        return paired;
    }

    float4 sum = tex2D(sBloomB, uv) * 0.2270270270;
    sum += tex2D(sBloomB, uv - 4.0 * stp) * 0.0162162162;
    sum += tex2D(sBloomB, uv - 3.0 * stp) * 0.0540540541;
    sum += tex2D(sBloomB, uv - 2.0 * stp) * 0.1216216216;
    sum += tex2D(sBloomB, uv - 1.0 * stp) * 0.1945945946;
    sum += tex2D(sBloomB, uv + 1.0 * stp) * 0.1945945946;
    sum += tex2D(sBloomB, uv + 2.0 * stp) * 0.1216216216;
    sum += tex2D(sBloomB, uv + 3.0 * stp) * 0.0540540541;
    sum += tex2D(sBloomB, uv + 4.0 * stp) * 0.0162162162;
    return sum;
}

// 3D CRT FACEPLATE PROJECTION ----------------------------------------------------
// Coordinates are measured in screen half-widths. The vertical coordinate is converted
// through the actual output aspect ratio so a spherical profile remains physically circular.
// The surface is a depth field z = sag(x,y), with its centre tangent plane at z=0.

float crt_surface_sag_gradient(float2 p, float aspect, out float2 gradient)
{
    float x = p.x;
    float y = p.y;
    gradient = float2(0.0, 0.0);

    if (screen_geometry == 0)
        return 0.0;

    if (screen_geometry == 1)
    {
        float radius = max(surface_radius, 1.25);
        float root = sqrt(max(radius * radius - x * x, 0.0001));
        gradient.x = x / root;
        return radius - root;
    }

    if (screen_geometry == 2)
    {
        float radius = max(surface_radius, 1.25);
        float r2 = x * x + y * y;
        float root = sqrt(max(radius * radius - r2, 0.0001));
        gradient = float2(x, y) / root;
        return radius - root;
    }

    // Aspherical is a toric faceplate: independent horizontal and vertical base radii,
    // plus a normalized fourth-order departure that reaches the selected value at corners.
    float radius_x = max(surface_radius_horizontal, 1.25);
    float radius_y = max(surface_radius_vertical, 1.25);
    float root_x = sqrt(max(radius_x * radius_x - x * x, 0.0001));
    float root_y = sqrt(max(radius_y * radius_y - y * y, 0.0001));
    float sag_x = radius_x - root_x;
    float sag_y = radius_y - root_y;
    gradient = float2(x / root_x, y / root_y);

    float normalized_r2 = x * x + (y * aspect) * (y * aspect);
    float edge_shape = 0.25 * normalized_r2 * normalized_r2;
    float departure = surface_aspheric_departure;
    gradient += departure * float2(
        normalized_r2 * x,
        normalized_r2 * y * aspect * aspect);
    return sag_x + sag_y + departure * edge_shape;
}

float2 project_crt_surface(float2 output_uv, float2 screen_size)
{
    if (screen_geometry == 0)
        return output_uv;

    float aspect = screen_size.x / max(screen_size.y, 1.0);
    float2 plane_xy = float2(
        output_uv.x * 2.0 - 1.0,
        (1.0 - output_uv.y * 2.0) / aspect);

    float camera_distance_value = max(camera_distance, 0.25);
    float3 camera = float3(camera_horizontal_offset, camera_vertical_offset, -camera_distance_value);
    float3 target = float3(plane_xy, 0.0);
    float3 ray = target - camera;

    // Newton iteration solves camera + t*ray against z = sag(x,y). At t=1 the ray
    // intersects the centre tangent plane; curved regions converge a little in front/behind it.
    float t = 1.0;
    [unroll]
    for (int iteration = 0; iteration < 6; ++iteration)
    {
        float3 hit = camera + ray * t;
        float2 gradient;
        float sag = crt_surface_sag_gradient(hit.xy, aspect, gradient);
        float error = hit.z - sag;
        float derivative = ray.z - dot(gradient, ray.xy);
        if (abs(derivative) > 0.00001)
            t = clamp(t - error / derivative, 0.25, 3.0);
    }

    float3 hit = camera + ray * t;
    return float2(
        0.5 + 0.5 * hit.x,
        0.5 - 0.5 * hit.y * aspect);
}

float crt_surface_coverage(float2 surface_uv, float2 texture_size)
{
    if (screen_geometry == 0)
        return 1.0;

    float aspect = texture_size.x / max(texture_size.y, 1.0);
    // Express both axes in units of the shorter image dimension. The half-extents therefore
    // retain the true output aspect ratio, while radius keeps its documented shorter-side basis.
    float2 half_extent = float2(max(aspect, 1.0), max(1.0 / max(aspect, 0.0001), 1.0));
    float2 p = float2(
        (surface_uv.x * 2.0 - 1.0) * half_extent.x,
        (1.0 - surface_uv.y * 2.0) * half_extent.y);
    float radius = min(saturate(screen_corner_radius) * 2.0,
                       min(half_extent.x, half_extent.y));
    float2 q = abs(p) - (half_extent - radius);
    float distance = length(max(q, float2(0.0, 0.0)))
        + min(max(q.x, q.y), 0.0) - radius;
    float aa = 2.0 / max(min(texture_size.x, texture_size.y), 1.0);
    return 1.0 - smoothstep(-aa, aa, distance);
}

float3 sample_crt_surface(sampler source_sampler, float2 centre_uv,
                          float2 texture_size, out float coverage,
                          out float scanline_factor)
{
    if (screen_geometry == 0 || geometry_antialiasing == 0)
    {
        coverage = crt_surface_coverage(centre_uv, texture_size);
        float4 sample_value = tex2D(source_sampler, saturate(centre_uv));
        scanline_factor = saturate(sample_value.a);
        return sample_value.rgb;
    }

    // Build the 2x2 Jacobian in source texels per output pixel. Its largest eigenvector
    // identifies the principal minification direction, including rotated/off-axis cases.
    float2 dx = ddx(centre_uv) * texture_size;
    float2 dy = ddy(centre_uv) * texture_size;
    float a = dot(dx, dx);
    float b = dot(dx, dy);
    float c = dot(dy, dy);
    float discriminant = sqrt(max((a - c) * (a - c) + 4.0 * b * b, 0.0));
    float lambda_max = max(0.5 * (a + c + discriminant), 1.0);
    float major_length = sqrt(lambda_max);

    float2 axis;
    if (abs(b) > 0.00001)
        axis = normalize(float2(lambda_max - c, b));
    else
        axis = (a >= c) ? float2(1.0, 0.0) : float2(0.0, 1.0);

    float2 major_uv = ddx(centre_uv) * axis.x + ddy(centre_uv) * axis.y;
    int maximum_taps = (geometry_antialiasing == 1) ? 4 : 8;
    int tap_count = (int)clamp(ceil(major_length), 1.0, (float)maximum_taps);
    float inverse_taps = 1.0 / (float)tap_count;
    float3 color_sum = float3(0.0, 0.0, 0.0);
    float scanline_sum = 0.0;
    float coverage_sum = 0.0;

    // Fixed upper bound keeps the loop compiler-friendly. Each selected tap is spread over
    // the principal-axis footprint; invalid/corner-exterior taps contribute zero coverage.
    [loop]
    for (int tap_index = 0; tap_index < 8; ++tap_index)
    {
        if (tap_index < tap_count)
        {
            float offset = ((float)tap_index + 0.5) * inverse_taps - 0.5;
            float2 tap_uv = centre_uv + major_uv * offset;
            float tap_coverage = crt_surface_coverage(tap_uv, texture_size);
            if (tap_coverage > 0.00001)
            {
                float4 tap_sample = tex2D(source_sampler, saturate(tap_uv));
                color_sum += tap_sample.rgb * tap_coverage;
                scanline_sum += tap_sample.a * tap_coverage;
                coverage_sum += tap_coverage;
            }
        }
    }

    coverage = coverage_sum * inverse_taps;
    scanline_factor = (coverage_sum > 0.00001)
        ? saturate(scanline_sum / coverage_sum)
        : 0.0;
    return (coverage_sum > 0.00001)
        ? (color_sum / coverage_sum)
        : float3(0.0, 0.0, 0.0);
}

// Selective warm-color saturation trim. Hue selection is evaluated in an approximate
// display-referred RGB view (2.2 power) so the degree slider behaves more like the visible
// screenshot colors. The actual desaturation is applied in linear RGB toward an equal-luma
// neutral, preserving Rec.709 luminance. This selects colors, not objects or screen regions.
float3 apply_selective_warm_desaturation(float3 linear_rgb)
{
    if (!enable_selective_warm_desaturation || selective_warm_saturation_reduction <= 0.00001)
        return linear_rgb;

    float3 hue_rgb = pow(saturate(linear_rgb), 1.0 / 2.2);
    float max_channel = max(hue_rgb.r, max(hue_rgb.g, hue_rgb.b));
    float min_channel = min(hue_rgb.r, min(hue_rgb.g, hue_rgb.b));
    float chroma = max_channel - min_channel;
    if (chroma <= 0.00001 || max_channel <= 0.00001)
        return linear_rgb;

    float hue_degrees;
    if (max_channel == hue_rgb.r)
        hue_degrees = 60.0 * ((hue_rgb.g - hue_rgb.b) / chroma);
    else if (max_channel == hue_rgb.g)
        hue_degrees = 60.0 * (((hue_rgb.b - hue_rgb.r) / chroma) + 2.0);
    else
        hue_degrees = 60.0 * (((hue_rgb.r - hue_rgb.g) / chroma) + 4.0);

    if (hue_degrees < 0.0)
        hue_degrees += 360.0;

    float hue_distance = abs(hue_degrees - selective_warm_hue_center);
    hue_distance = min(hue_distance, 360.0 - hue_distance);
    float feather = max(selective_warm_hue_feather, 0.01);
    float hue_weight = 1.0 - smoothstep(
        selective_warm_hue_range,
        selective_warm_hue_range + feather,
        hue_distance);

    // Avoid applying a hue adjustment to near-neutral pixels, where hue is unstable.
    float hsv_saturation = chroma / max(max_channel, 0.00001);
    float saturation_weight = smoothstep(0.08, 0.20, hsv_saturation);
    float adjustment = saturate(selective_warm_saturation_reduction)
        * hue_weight * saturation_weight;

    float luma = max(dot(linear_rgb, float3(0.2126, 0.7152, 0.0722)), 0.0);
    return lerp(linear_rgb, luma.xxx, adjustment);
}

// Final composite: bloom is added to the linear CRT scene before the filmic curve.
// filmic() is tone mapping, not an sRGB OETF. No manual output OETF is applied here:
// DuckStation's ReShade backbuffer encoding contract is backend-managed and is not
// reliably exposed as a shader source semantic, so an unconditional encode risks doubling it.
// With Bloom Intensity at exactly 0, all three bloom pixel shaders return before texture
// sampling or blur work, and the final composite does not sample the bloom texture. DuckStation
// still schedules the three quarter-resolution passes (ReShade FX has no uniform-driven per-pass
// dispatch switch), but they only write zero; debug bloom views 7/8 intentionally override this.
float4 PS_CompositeBloom(float4 pos : SV_Position, float2 uv_tx : TEXCOORD0) : SV_Target
{
    float2 screen_size = ReShade::ScreenSize.xy;

    // Intermediate diagnostics are unprojected unless the inspected stage is geometry itself.
    if (debug_view > 0 && debug_view <= 5)
        return float4(tex2D(sCrtScene, uv_tx).rgb, 1.0);
    if (debug_view == 7 || debug_view == 8)
        return float4(saturate(tex2D(sBloomA, uv_tx).rgb * 4.0), 1.0);
    if (debug_view == 9)
        return float4(filmic(tex2D(sSmoothH, uv_tx).rgb), 1.0);
    if (debug_view == 10)
        return float4(filmic(tex2D(sSmoothV, uv_tx).rgb), 1.0);
    if (debug_view == 11)
    {
        float detail = saturate(tex2D(sSmoothV, uv_tx).a);
        return float4(detail.xxx, 1.0);
    }
    if (debug_view == 12 || debug_view == 13 || debug_view == 19 || debug_view == 20)
        return float4(tex2D(sCrtScene, uv_tx).rgb, 1.0);
    if (debug_view == 14)
        return float4(saturate(tex2D(GaussianBlurTempSampler, uv_tx).r).xxx, 1.0);
    if (debug_view == 15)
        return float4(saturate(tex2D(GaussianBlurTempSampler, uv_tx).r * 4.0).xxx, 1.0);
    if (debug_view == 16)
        return float4(saturate(tex2D(GaussianBlurSampler, uv_tx).r * 4.0).xxx, 1.0);

    float2 geometry_uv = project_crt_surface(uv_tx, screen_size);
    if (debug_view == 18)
    {
        float coverage = crt_surface_coverage(geometry_uv, screen_size);
        return float4(coverage.xxx, 1.0);
    }
    float geometry_mask;
    float scanline_factor;
    float3 col = sample_crt_surface(
        sCrtScene, geometry_uv, screen_size, geometry_mask, scanline_factor);

    // Add the post-phosphor optical glow in faceplate coordinates. In default mode A it is not
    // cut by scanlines; mode B reapplies the local scanline factor stored in scene alpha.
    col += halation_contribution(geometry_uv, scanline_factor);

    // This view shows the processed CRT scene without bloom, using the normal filmic display curve.
    if (debug_view == 6)
    {
        float3 debug_scene = apply_selective_warm_desaturation(filmic(col));
        return float4(debug_scene * geometry_mask, 1.0);
    }

    if (bloom_intensity > 0.0)
        col += tex2D(sBloomA, geometry_uv).rgb * bloom_intensity;

    col = filmic(col);
    col = apply_selective_warm_desaturation(col);

    float2 uv = geometry_uv.xy;
    uv.y = 1.0 - geometry_uv.y;
    float2 screen_uv = lerp(screen_fit_uv(uv), uv, 0.4);
    if (debug_view == 17)
    {
        float debug_vignette = vignette_multiplier(screen_uv, uv_tx * screen_size);
        return float4(saturate(debug_vignette / 1.3).xxx, 1.0);
    }
    float frame_clock = animation_frame_clock();
    float time = mod(frame_clock, 640.0);

    if (noise_amount > 0.000001)
    {
        float grain_frame = mod(frame_clock * noise_animation_speed, 640.0);
        // Output-grid grain is anchored to the actual final composite pixel, not the projected
        // faceplate coordinate. Native and Mixed modes still use source-mapped coordinates below.
        float2 grain_position = uv_tx * screen_size;
        float2 native_position = grain_position;
        float detail_scale = 1.0;
        // Keep the new awareness paths free when their controls are left at zero. Output Pixels
        // uses uv_tx directly and avoids extra source-coordinate math or detail-analysis reads.
        if (noise_alignment != 0 || noise_detail_protection > 0.0001)
        {
            float2 source_uv = grain_source_uv(geometry_uv, screen_uv);
            if (noise_alignment != 0)
                native_position = source_uv / grain_native_pixel_uv_size();
            if (noise_detail_protection > 0.0001)
                detail_scale = grain_detail_factor(source_uv);
        }

        float chroma = saturate(noise_chroma);
        if (noise_color_awareness > 0.0001)
        {
            // Near-neutral pixels receive mostly monochromatic grain; moderate color keeps
            // chroma, while highly saturated details receive a gentler independent-RGB component.
            float3 color_for_noise = max(col, float3(0.0, 0.0, 0.0));
            float color_max = max(color_for_noise.r, max(color_for_noise.g, color_for_noise.b));
            float color_min = min(color_for_noise.r, min(color_for_noise.g, color_for_noise.b));
            float image_saturation = (color_max > 0.0001)
                ? (color_max - color_min) / color_max : 0.0;
            float chroma_activity = smoothstep(0.025, 0.24, image_saturation);
            float saturated_detail_guard = 1.0 - 0.5 * smoothstep(0.72, 0.95, image_saturation);
            float image_chroma_factor = chroma_activity * saturated_detail_guard;
            chroma *= lerp(1.0, image_chroma_factor, saturate(noise_color_awareness));
        }

        float3 grain_values;
        if (chroma <= 0.0001)
        {
            // Fully neutral grain needs only one random field shared by RGB.
            float mono_grain = aligned_grain_value(grain_position, native_position, grain_frame, 0u);
            grain_values = mono_grain.xxx;
        }
        else if (chroma >= 0.9999)
        {
            // Fully colored grain evaluates only the three independent channels.
            grain_values = float3(
                aligned_grain_value(grain_position, native_position, grain_frame, 1u),
                aligned_grain_value(grain_position, native_position, grain_frame, 2u),
                aligned_grain_value(grain_position, native_position, grain_frame, 3u));
        }
        else
        {
            // Intermediate chroma blends shared neutral grain with independent RGB grain.
            // Normalize the blend so changing chroma does not simply lower its standard deviation.
            float mono_grain = aligned_grain_value(grain_position, native_position, grain_frame, 0u);
            float3 rgb_grain = float3(
                aligned_grain_value(grain_position, native_position, grain_frame, 1u),
                aligned_grain_value(grain_position, native_position, grain_frame, 2u),
                aligned_grain_value(grain_position, native_position, grain_frame, 3u));
            grain_values = lerp(mono_grain.xxx, rgb_grain, chroma);
            float chroma_norm = rsqrt(max((1.0 - chroma) * (1.0 - chroma)
                                        + chroma * chroma, 0.000001));
            grain_values = 0.5 + (grain_values - 0.5) * chroma_norm;
        }

        // The centering/scaling gives a per-channel standard deviation of approximately 0.3
        // before luminance adaptation, detail protection and final clipping.
        float3 grain = (grain_values - 0.5) * 1.03923048;
        float grain_luma = saturate(dot(max(col, float3(0.0, 0.0, 0.0)),
                                        float3(0.2126, 0.7152, 0.0722)));
        // Blend from uniform grain to a squared-luminance response. White retains full strength.
        float grain_luminance_scale = lerp(1.0, grain_luma * grain_luma,
                                           saturate(noise_luminance_adaptation));
        float3 grain_delta = grain * noise_amount * grain_luminance_scale * detail_scale;
        if (headroom_aware_grain)
        {
            // Bound each signed excursion by the smaller of the positive and
            // negative headroom around the current channel value. Using abs(delta)
            // makes the attenuation symmetric for positive/negative grain and
            // prevents a one-sided SDR clamp from rectifying the noise near black
            // or white. The actual generated excursion is used, so all normalized
            // grain modes share the same safe path without a guessed global bound.
            float3 symmetric_headroom = max(
                float3(0.0, 0.0, 0.0), min(col, 1.0 - col));
            float3 headroom_scale = min(
                float3(1.0, 1.0, 1.0),
                symmetric_headroom / max(abs(grain_delta), float3(1e-6, 1e-6, 1e-6)));
            grain_delta *= headroom_scale;
        }
        col += grain_delta;
    }

    col *= 1.0 - flicker_amount
        * (sin(50.0 * time + screen_uv.y * 2.0) * 0.5 + 0.5);


    // Apply antialiased faceplate coverage after all image/grain/flicker layers.
    col *= geometry_mask;

    // SDR output clamp: this intentionally clips values outside [0,1], so this is not HDR-safe.
    col = saturate(col);
    return float4(col, 1.0);
}

technique CRT_Trinity
{
    pass Pass_AccumulateFrame
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_AccumulateFrame;
        RenderTarget = tAccumFrame;
    }

    pass Pass_SaveHistory
    {
        VertexShader = PostProcessVS;
        PixelShader = PrevColor;
        RenderTarget = tAccTex;
    }

    pass Pass_GaussianBlurHorizontal
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_GaussianBlurHorizontal;
        RenderTarget = GaussianBlurTemp;
    }

    pass Pass_GaussianBlurVertical
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_GaussianBlurVertical;
        RenderTarget = GaussianBlurTex;
    }

    pass Pass_SmoothH
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SmoothH;
        RenderTarget = tSmoothH;
    }

    pass Pass_SmoothV
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SmoothV;
        RenderTarget = tSmoothV;
    }

    pass Pass_RenderCRTScene
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_RenderCRTScene;
        RenderTarget = tCrtScene;
    }

    // The ghost blur has now been consumed by PS_RenderCRTScene. Reuse its full-resolution
    // scratch targets to extract and blur highlights from the completed phosphor/scanline image.
    pass Pass_HalationBlurHorizontal
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_HalationBlurHorizontal;
        RenderTarget = GaussianBlurTemp;
    }

    pass Pass_HalationBlurVertical
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_HalationBlurVertical;
        RenderTarget = GaussianBlurTex;
    }

    pass Pass_ExtractBloom
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_ExtractBloom;
        RenderTarget = tBloomA;
    }

    pass Pass_BloomBlurHorizontal
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BloomBlurHorizontal;
        RenderTarget = tBloomB;
    }

    pass Pass_BloomBlurVertical
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BloomBlurVertical;
        RenderTarget = tBloomA;
    }

    pass Pass_CompositeBloom
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_CompositeBloom;
    }
}
