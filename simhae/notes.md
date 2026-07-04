# 심해 simhae — Theme Foundation Notes

## Eye Strain — What Actually Matters

**1. Luminance difference (contrast gap)**
The gap between background and foreground is the #1 cause of eye fatigue.
Pure black `#000000` with pure white text is visually harsh, not gentle.
A very dark *colored* background with slightly tinted off-white text closes that gap gently.

**2. Saturation, not just hue**
Highly saturated colors force the iris to constantly adjust.
The ocean looks deep and dark — not vivid. Keep saturation low on large surfaces.
Desaturated backgrounds let your eyes relax across 14-hour sessions.

**3. Teal/green-blue is easier than pure blue**
Human eyes have the highest density of photoreceptors tuned to green wavelengths.
Teal (blue-green) sits at that boundary — it reads as "cool" but strains less than pure blue.

**4. Avoid pure black and pure white**
`#000000` background: too much contrast, edges feel sharp.
`#FFFFFF` text: blooms on dark backgrounds, especially in dim rooms.
Use color-tinted near-blacks and near-whites instead.

**5. Background lightness sweet spot: 5–12% (HSL)**
Below 5% — too close to black, loses depth.
Above 15% — starts to read as "gray", loses the ocean feeling.
12% is a safe upper limit for a dark theme that still shows color identity.

---

## Rules for Creating the simhae Theme

### Background
- Lightness: **5–12%** in HSL
- Saturation: **20–35%** — enough to feel like water, not enough to vibrate
- Hue: **200–220°** (blue leaning slightly teal, not pure cyan)

### Foreground / Text
- Never pure white. Use `#C8D8E8` or similar — slightly blue-tinted off-white
- Lightness of primary text: **75–85%**
- Secondary text (comments, hints): **40–55%** lightness, same hue family

### Accent Colors
- Never use fully saturated colors for large areas
- Accent saturation cap: **60%** — they should feel like bioluminescence, not neon
- Keep accent hues within **160–240°** (green-teal-blue family) for harmony
- One warm accent (amber or pale gold) is allowed as a single contrast point

### Syntax Colors (code)
- Strings: soft teal `~200°`
- Keywords: muted blue `~215°`
- Functions: slightly lighter than text, same hue
- Comments: **40–45%** lightness, hue-shifted slightly warmer to feel quieter
- Errors: desaturated red — not alarm-red, more like deep rust

### Surface Hierarchy (UI layers)
- Base background: the main color
- Raised surface (panels, sidebars): +3–5% lightness from base
- Elevated surface (modals, tooltips): +6–10% lightness from base
- Never jump more than 10% between layers — keep the depth gradual

### What to Avoid
- Avoid pure green, yellow, or magenta as any large-area color
- Avoid mixing warm and cool backgrounds — pick a side and stay there
- Avoid borders with high contrast — use +8–12% lightness from surface instead of a separate border color
