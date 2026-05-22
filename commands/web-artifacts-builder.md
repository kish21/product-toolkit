---
name: web-artifacts-builder
description: Suite of tools for creating elaborate, multi-component HTML artifacts using React, Tailwind CSS, and shadcn/ui. Use for complex artifacts requiring state management, routing, or component libraries — not for simple single-file HTML/JSX.
---

# Web Artifacts Builder

Build powerful self-contained HTML artifacts using React 18 + TypeScript + Vite + Tailwind CSS + shadcn/ui.

**Stack**: React 18 + TypeScript + Vite + Parcel (bundling) + Tailwind CSS 3.4.1 + shadcn/ui (40+ components)

---

## Anti-AI-Slop Rule

> Avoid excessive centered layouts, purple gradients, uniform rounded corners, and Inter font.
> Every artifact should have one "wait, that's interesting" design moment.

---

## Workflow

### Step 1 — Initialize

```bash
bash scripts/init-artifact.sh <project-name>
cd <project-name>
```

Creates: React + TypeScript (Vite), Tailwind CSS, path aliases (`@/`), 40+ shadcn/ui components, Parcel bundling config.

### Step 2 — Develop

Edit the generated files. See Common Tasks below.

### Step 3 — Bundle

```bash
bash scripts/bundle-artifact.sh
```

Outputs `bundle.html` — a single self-contained file with all JS, CSS, and dependencies inlined. Ready to share as an artifact.

Requirements: project must have `index.html` in root.

### Step 4 — Share

Share `bundle.html` directly in conversation as an artifact.

### Step 5 — Test (Optional)

Only test if requested or if issues arise. Testing adds latency — present the artifact first.

---

## Design Guidelines

- shadcn/ui component reference: `https://ui.shadcn.com/docs/components`
- Use Tailwind utility classes, not inline styles
- Prefer `gap-*` over `margin-*` for spacing in flex/grid layouts
- State management: React `useState` / `useReducer` for local state; no external store needed for artifacts
- Routing: use hash-based routing (`#/path`) since artifacts run in iframes
