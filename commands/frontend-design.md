---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces that avoid generic AI aesthetics. Use when building components, pages, dashboards, or any web UI. Guides design thinking, enforces design system rules, and audits for AI-slop tells before delivery.
---

> **Project setup required:** Before writing code, fill in the design system section below for your project. Replace the placeholders with your project's actual font constants, color variables, and theme hook.

This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

## Step 1 — Design Thinking (answer before writing code)

Before coding, commit to a BOLD aesthetic direction:

1. **Purpose**: What problem does this interface solve? Who uses it? (CFO? Procurement manager? System admin?)
2. **Tone**: Pick a direction — brutally minimal, data-dense/utilitarian, luxury/refined, editorial. Enterprise tools should feel authoritative and precise — never playful.
3. **Differentiation**: What makes this UNFORGETTABLE? What's the one element someone will remember?
4. **Constraints**: What design system does this project use? (CSS vars, fonts, theme system)

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. A refined minimalist card with perfect spacing beats a busy maximalist layout for a data dashboard.

## Step 2 — Design System Rules (customize for your project)

Replace these placeholders with your project's actual values:

### Fonts
```ts
// Example — replace with your project's font constants:
import { FONT, DISPLAY, MONO } from "@/lib/theme"
// FONT    → body/UI text
// DISPLAY → headings (heavy weight)
// MONO    → data/numbers/IDs
```

Differentiate through **weight and tracking**, not font family:
- Hero headings: `fontWeight: 800, letterSpacing: "-0.04em", lineHeight: 1.0`
- Section labels: `fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase"`
- Body: `fontWeight: 400, lineHeight: 1.65`
- Data/numbers: mono font, `fontWeight: 500`

### Colours — CSS variables only
```
var(--color-background)        page base
var(--color-surface)           cards, panels
var(--color-surface-hover)     hover states
var(--color-border)            dividers
var(--color-border-strong)     emphasis borders
var(--color-accent)            CTAs, active states
var(--color-accent-hover)      accent hover state
var(--color-accent-foreground) text on accent
var(--color-text)              primary text
var(--color-text-muted)        secondary / muted text
var(--color-success)           positive states
var(--color-warning)           pending / caution
var(--color-error)             destructive / failed
var(--color-info)              neutral / informational
var(--bg-gradient)             page background
var(--shadow-sm/md/lg)         elevation
var(--transition)              animation duration
var(--radius)                  border radius
```
**Never write a raw hex colour.** CSS vars must respond to theme changes.

### Component patterns that make interfaces distinctive
- **Depth layering**: base → elevated (`--color-surface` + `--shadow-sm`) → floating (`--shadow-lg` + border). Never flat.
- **Data density**: tight spacing for data rows (12px padding), generous spacing for hero sections (48px+). Contrast creates rhythm.
- **Accent sparing**: `--color-accent` only on interactive elements and the single most important number on screen. Never as a background on large surfaces.
- **Status always semantic**: success / warning / error / info vars — never raw colours for state.
- **Table hover**: `onMouseEnter` → `var(--color-surface-hover)`. Real hover states, not flat rows.
- **Number display**: large KPI numbers in mono font at 32–48px weight 700 — makes data feel authoritative.

## Step 3 — Aesthetics to Make It Distinctive

### Motion
- Page load: stagger card reveals with `animation-delay` (50ms increments)
- Hover: `transform: translateY(-1px)` on cards, `opacity` transitions on text
- Progress bars: `transition: width 600ms ease`
- Only animate `transform` and `opacity` — never `transition: all`

### Spatial composition
- Break the grid intentionally — a KPI row at 4 equal columns is generic; try `1fr 1fr 1fr 2fr`
- Use generous negative space in hero areas, controlled density in tables
- Left-align numbers, right-align labels occasionally to create visual rhythm
- Sticky sidebar or sticky table headers add perceived polish

### Background & texture
- Use `var(--bg-gradient)` for page — not flat `var(--color-background)`
- Cards: subtle `var(--shadow-sm)` + `1px solid var(--color-border)` gives depth
- Use `backdrop-filter: blur(12px)` on modals/overlays for glassmorphism
- Accent-tinted card tops: `borderTop: "2px solid var(--color-accent)"` for KPI cards

### Typography contrast
- One element should be dramatically larger than everything else (3–5× body size)
- Mix tight tracking (`-0.04em`) on big numbers with open tracking (`0.1em`) on labels
- Use `fontVariantNumeric: "tabular-nums"` on all data columns so numbers align

## Step 4 — Hard Stops

- ❌ No `transition: all` — only `transform` and `opacity`
- ❌ No `border` shorthand mixed with `borderTop`/`borderLeft` — use all 4 sides explicitly
- ❌ No raw hex anywhere
- ❌ No loading additional fonts — use your project's globally loaded fonts only
- ❌ No hardcoded dark/light mode per-component — use your project's theme hook

## Step 5 — Self-Review Before Delivering

- Could any other AI prompt have produced this? If yes — change something.
- Is there one "wait, that's interesting" moment in the layout or typography?
- Would a design-savvy person call this "template-y"? If yes — find and fix it.

> If the design is only describable as "clean and modern" — it is generic.
> Every interface 