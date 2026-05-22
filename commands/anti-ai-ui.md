# Anti-AI UI Audit — Run Before Delivering Any UI

Audit the UI you just wrote against every item below. Fix every flagged item before reporting done.

## Pre-Design Commitment (answer before coding)
1. What is the ONE visual concept driving this design? (not just "clean and modern")
2. What single element will make someone stop and notice?
3. What is the layout doing that's unexpected or intentional?

If you cannot answer all three, rethink the design before writing code.

---

## The 12 AI Tells — Audit Checklist

### Typography
- [ ] **Same weight heading/subtitle** → apply minimum 200 weight difference
- [ ] **Flat font scale** → hero text should feel 3–5× body size
- [ ] **Uniform line-height** → headings: `1.0–1.1`, body: `1.65–1.8`
- [ ] **No tracking intent** → headings: `letterSpacing: "-0.03em"`, labels: `"0.08em"`+

### Color
- [ ] **Raw hex anywhere** → replace with `var(--color-*)`
- [ ] **Equal-weight colours** → apply 60/30/10 rule: dominant / accent / neutral
- [ ] **Plain background** → use `var(--bg-gradient)` not solid `var(--color-background)`

### Depth & Shadow
- [ ] **Flat single shadow** → layer `var(--shadow-sm)`, `var(--shadow-md)`, `var(--shadow-lg)`
- [ ] **All elements same z-plane** → base → elevated (`var(--color-surface)`) → floating (`var(--shadow-lg)` + border)

### Spacing & Layout
- [ ] **Uniform padding** → use tokens: 4, 8, 12, 16, 20, 24, 32, 40, 48
- [ ] **Everything centred** → break the grid at least once intentionally

### Motion & Interaction
- [ ] **`transition: all`** → replace with `transition: transform var(--transition), opacity var(--transition)`
- [ ] **Missing states** → every clickable: hover + focus-visible + active

### Visual Texture
- [ ] **Solid flat backgrounds** → add depth: gradient, border, or layered surface

---

## Self-Review Questions
- Could any other AI prompt have produced this exact design? If yes — change something.
- Is there at least one "wait, that's interesting" moment in the layout or typography?
- Would a design-savvy person call this "template-y"? If yes — find and fix the offending element.

## The One Rule
> If the design is only describable as "clean and modern" — it is generic.
> Every design must be describable by what makes it *that specific thing*.

---

Report: list which items passed, which were fixed, and one sentence describing the design's unique characteristic.
