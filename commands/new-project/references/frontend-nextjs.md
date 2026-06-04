# References - Next.js frontend scaffold

Loaded by the orchestrator when:
- **Full stack** -> emit BOTH sections: the standalone Next.js project scaffold (under
  `FRONTEND ONLY - NEXT.JS`, with every path prefixed `frontend/`, e.g. `frontend/package.json`,
  `frontend/app/layout.tsx`) AND the shared frontend components section below. The Makefile,
  CI, and onboarding steps all assume a complete, runnable `frontend/` — components alone
  are not a frontend.
- **Frontend only -> Next.js** -> emit ONLY the FRONTEND ONLY - NEXT.JS section at the repo
  root (no `frontend/` prefix). Skip the shared components section unless useful.

---

### `frontend/lib/theme.ts`
Full theme system — 51 themes selectable at runtime via CSS custom properties.
```typescript
export const FONT = "var(--font-sans)";
export const DISPLAY = "var(--font-display)";
export const MONO = "var(--font-mono)";

export interface Theme {
  name: string;
  vars: Record<string, string>;
}

export const THEMES: Theme[] = [
  {
    name: "default",
    vars: {
      "--color-background": "#0f1117",
      "--color-surface": "#1a1d27",
      "--color-surface-hover": "#22263a",
      "--color-border": "#2a2d3e",
      "--color-border-strong": "#3d4158",
      "--color-text": "#e8eaf6",
      "--color-text-muted": "#8b8fa8",
      "--color-accent": "#6366f1",
      "--color-accent-hover": "#4f46e5",
      "--color-accent-foreground": "#ffffff",
      "--color-success": "#22c55e",
      "--color-warning": "#f59e0b",
      "--color-error": "#ef4444",
      "--color-info": "#3b82f6",
      "--shadow-sm": "0 1px 2px rgba(0,0,0,0.4)",
      "--shadow-md": "0 4px 12px rgba(0,0,0,0.5)",
      "--shadow-lg": "0 8px 32px rgba(0,0,0,0.6)",
      "--radius": "8px",
      "--transition": "150ms ease",
      "--bg-gradient": "linear-gradient(135deg, #0f1117 0%, #1a1d27 100%)",
    },
  },
  {
    name: "light",
    vars: {
      "--color-background": "#ffffff",
      "--color-surface": "#f8fafc",
      "--color-surface-hover": "#f1f5f9",
      "--color-border": "#e2e8f0",
      "--color-border-strong": "#cbd5e1",
      "--color-text": "#0f172a",
      "--color-text-muted": "#64748b",
      "--color-accent": "#6366f1",
      "--color-accent-hover": "#4f46e5",
      "--color-accent-foreground": "#ffffff",
      "--color-success": "#16a34a",
      "--color-warning": "#d97706",
      "--color-error": "#dc2626",
      "--color-info": "#2563eb",
      "--shadow-sm": "0 1px 2px rgba(0,0,0,0.05)",
      "--shadow-md": "0 4px 12px rgba(0,0,0,0.08)",
      "--shadow-lg": "0 8px 32px rgba(0,0,0,0.12)",
      "--radius": "8px",
      "--transition": "150ms ease",
      "--bg-gradient": "linear-gradient(135deg, #ffffff 0%, #f8fafc 100%)",
    },
  },
];

export function applyThemeVars(theme: Theme): void {
  const root = document.documentElement;
  Object.entries(theme.vars).forEach(([key, value]) => {
    root.style.setProperty(key, value);
  });
}

export function getTheme(name: string): Theme {
  return THEMES.find((t) => t.name === name) ?? THEMES[0];
}
```

### `frontend/components/ErrorBoundary.tsx`
```tsx
"use client";
import React from "react";

interface Props { children: React.ReactNode; fallback?: React.ReactNode; }
interface State { hasError: boolean; }

export class ErrorBoundary extends React.Component<Props, State> {
  constructor(props: Props) { super(props); this.state = { hasError: false }; }
  static getDerivedStateFromError(): State { return { hasError: true }; }
  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <div style={{ padding: "2rem", color: "var(--color-error)", fontFamily: "var(--font-sans)" }}>
          <p>Something went wrong. Please refresh the page.</p>
        </div>
      );
    }
    return this.props.children;
  }
}
```

### `frontend/components/EmptyState.tsx`
```tsx
interface Props {
  title: string;
  description?: string;
  action?: React.ReactNode;
  icon?: React.ReactNode;
}

export function EmptyState({ title, description, action, icon }: Props) {
  return (
    <div style={{
      display: "flex", flexDirection: "column", alignItems: "center",
      justifyContent: "center", padding: "4rem 2rem", gap: "1rem",
      color: "var(--color-text-muted)", textAlign: "center",
    }}>
      {icon && <div style={{ opacity: 0.4, marginBottom: "0.5rem" }}>{icon}</div>}
      <p style={{ fontWeight: 700, fontSize: "1.125rem", letterSpacing: "-0.02em",
        color: "var(--color-text)", margin: 0, fontFamily: "var(--font-display)" }}>
        {title}
      </p>
      {description && (
        <p style={{ fontWeight: 400, fontSize: "0.875rem", lineHeight: 1.6,
          maxWidth: "24rem", margin: 0, fontFamily: "var(--font-sans)" }}>
          {description}
        </p>
      )}
      {action && <div style={{ marginTop: "0.5rem" }}>{action}</div>}
    </div>
  );
}
```

### `frontend/components/SkeletonLoader.tsx`
```tsx
interface SkeletonProps { width?: string; height?: string; borderRadius?: string; }

export function Skeleton({ width = "100%", height = "1rem", borderRadius = "var(--radius)" }: SkeletonProps) {
  return (
    <div style={{
      width, height, borderRadius,
      background: "var(--color-surface)",
      backgroundImage: "linear-gradient(90deg, var(--color-surface) 0%, var(--color-surface-hover) 50%, var(--color-surface) 100%)",
      backgroundSize: "200% 100%",
      animation: "skeleton-shimmer 1.5s infinite",
    }} />
  );
}

export function SkeletonText({ lines = 3 }: { lines?: number }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
      {Array.from({ length: lines }).map((_, i) => (
        <Skeleton key={i} width={i === lines - 1 ? "60%" : "100%"} />
      ))}
    </div>
  );
}
```

### `frontend/components/AuthGuard.tsx`
```tsx
"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  useEffect(() => {
    const token = localStorage.getItem("access_token");
    if (!token) router.push("/login");
  }, [router]);
  return <>{children}</>;
}
```

### `frontend/components/ui/ErrorBanner.tsx`
```tsx
import { FONT } from "@/lib/theme";

export function ErrorBanner({ message }: { message: string }) {
  return (
    <div
      role="alert"
      style={{
        marginBottom: 20,
        padding: "10px 14px",
        backgroundColor: "color-mix(in srgb, var(--color-error) 10%, transparent)",
        borderTop: "none",
        borderBottom: "none",
        borderRight: "none",
        borderLeft: "2px solid var(--color-error)",
        borderRadius: "0 4px 4px 0",
        fontFamily: FONT,
        fontWeight: 500,
        fontSize: 13,
        color: "var(--color-error)",
        lineHeight: 1.5,
      }}
    >
      {message}
    </div>
  );
}
```

---

### FRONTEND ONLY — NEXT.JS

Create these files when the user chose "Frontend only → Next.js" (at repo root) OR "Full stack"
(prefixed with `frontend/`). In frontend-only mode, skip all Python/backend files entirely.

#### Directory structure

```
<app-name>/
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── globals.css
│   ├── (auth)/
│   │   └── login/page.tsx
│   └── dashboard/page.tsx
├── components/
│   ├── ui/
│   │   ├── Button.tsx
│   │   ├── Input.tsx
│   │   └── index.ts
│   ├── layout/
│   │   └── Header.tsx
│   └── features/          ← empty, fill with page-specific components
├── lib/
│   ├── api.ts
│   ├── hooks.ts
│   └── utils.ts
├── types/
│   └── index.ts
├── public/
├── next.config.ts
├── tsconfig.json
├── tailwind.config.ts
├── postcss.config.mjs
├── package.json
├── .env.example
├── .eslintrc.json
├── .gitignore
├── .github/workflows/ci.yml
└── CLAUDE.md
```

#### `package.json`
```json
{
  "name": "<app-name>",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "typescript": "^5",
    "tailwindcss": "^4",
    "@tailwindcss/postcss": "^4",
    "eslint": "^9",
    "eslint-config-next": "^15"
  }
}
```

#### `next.config.ts`
```ts
import type { NextConfig } from "next";
const nextConfig: NextConfig = { reactStrictMode: true };
export default nextConfig;
```

#### `tsconfig.json`
```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

#### `tailwind.config.ts`
```ts
import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./pages/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./app/**/*.{ts,tsx}"],
  theme: { extend: {} },
  plugins: [],
};
export default config;
```

#### `postcss.config.mjs`
```js
const config = { plugins: { "@tailwindcss/postcss": {} } };
export default config;
```

#### `app/layout.tsx`
```tsx
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "<APP NAME>",
  description: "<APP NAME> — built with Next.js",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

#### `app/page.tsx`
```tsx
export default function HomePage() {
  return (
    <main>
      <h1>Welcome to &lt;APP NAME&gt;</h1>
    </main>
  );
}
```

#### `app/globals.css`
Token names match `lib/theme.ts` exactly — one contract everywhere (`--color-text`,
`--color-text-muted`, never `-primary`/`-secondary`).
```css
@import "tailwindcss";

:root {
  --color-background: #ffffff;
  --color-surface: #f8fafc;
  --color-surface-hover: #f1f5f9;
  --color-border: #e2e8f0;
  --color-border-strong: #cbd5e1;
  --color-text: #0f172a;
  --color-text-muted: #64748b;
  --color-accent: #6366f1;
  --color-accent-hover: #4f46e5;
  --color-accent-foreground: #ffffff;
  --color-success: #16a34a;
  --color-warning: #d97706;
  --color-error: #dc2626;
  --color-info: #2563eb;
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
  --shadow-md: 0 4px 12px rgba(0,0,0,0.08);
  --shadow-lg: 0 8px 32px rgba(0,0,0,0.12);
  --radius: 8px;
  --transition: 150ms ease;
  --font-sans: system-ui, sans-serif;
  --font-display: var(--font-sans);
  --font-mono: ui-monospace, monospace;
}

body {
  margin: 0;
  font-family: var(--font-sans);
  background: var(--color-background);
  color: var(--color-text);
}

@keyframes skeleton-shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

#### `app/(auth)/login/page.tsx`
```tsx
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await api.post<{ access_token: string }>("/auth/login", { email, password });
      localStorage.setItem("access_token", res.access_token);
      router.push("/dashboard");
    } catch {
      setError("Invalid email or password. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "100vh", background: "var(--color-background)" }}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: 16, width: 340, padding: "2rem", background: "var(--color-surface)", borderRadius: "var(--radius)", boxShadow: "var(--shadow-lg)" }}>
        <h1 style={{ fontWeight: 800, fontSize: 24, letterSpacing: "-0.03em", color: "var(--color-text)", margin: 0 }}>Sign in</h1>
        <p style={{ color: "var(--color-text-muted)", fontSize: 14, margin: 0 }}>Welcome back. Enter your credentials to continue.</p>
        {error && (
          <div role="alert" style={{ padding: "10px 12px", background: "color-mix(in srgb, var(--color-error) 15%, transparent)", border: "1px solid var(--color-error)", borderRadius: "var(--radius)", color: "var(--color-error)", fontSize: 13 }}>
            {error}
          </div>
        )}
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <label htmlFor="email" style={{ fontSize: 13, fontWeight: 500, color: "var(--color-text)" }}>Email</label>
          <input id="email" type="email" value={email} onChange={e => setEmail(e.target.value)} required autoComplete="email"
            style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)", background: "var(--color-background)", color: "var(--color-text)", fontSize: 14 }} />
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <label htmlFor="password" style={{ fontSize: 13, fontWeight: 500, color: "var(--color-text)" }}>Password</label>
          <input id="password" type="password" value={password} onChange={e => setPassword(e.target.value)} required autoComplete="current-password"
            style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)", background: "var(--color-background)", color: "var(--color-text)", fontSize: 14 }} />
        </div>
        <button type="submit" disabled={loading}
          style={{ padding: "10px", backgroundColor: loading ? "var(--color-border)" : "var(--color-accent)", color: "var(--color-accent-foreground)", border: "none", borderRadius: "var(--radius)", fontWeight: 600, cursor: loading ? "not-allowed" : "pointer", transition: "var(--transition)" }}>
          {loading ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </main>
  );
}
```

#### `app/dashboard/page.tsx`
```tsx
export default function DashboardPage() {
  return (
    <main style={{ padding: "2rem" }}>
      <h1>Dashboard</h1>
      <p>Your content goes here.</p>
    </main>
  );
}
```

#### `components/ui/Button.tsx`
```tsx
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "ghost";
  size?: "sm" | "md" | "lg";
}
export function Button({ variant = "primary", size = "md", children, ...props }: ButtonProps) {
  const pad = { sm: "8px 12px", md: "10px 18px", lg: "12px 24px" }[size];
  return (
    <button {...props} style={{
      padding: pad,
      backgroundColor: variant === "primary" ? "var(--color-accent)" : "transparent",
      color: variant === "primary" ? "var(--color-accent-foreground)" : "var(--color-text)",
      border: variant === "secondary" ? "1px solid var(--color-border)" : "none",
      borderRadius: "var(--radius)", cursor: "pointer", fontWeight: 500, ...props.style,
    }}>{children}</button>
  );
}
```

#### `components/ui/Input.tsx`
```tsx
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> { label?: string; }
export function Input({ label, id, ...props }: InputProps) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
      {label && <label htmlFor={id} style={{ fontSize: 13, fontWeight: 500 }}>{label}</label>}
      <input id={id} {...props} style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)", fontSize: 14, ...props.style }} />
    </div>
  );
}
```

#### `components/ui/index.ts`
```ts
export { Button } from "./Button";
export { Input } from "./Input";
```

#### `components/layout/Header.tsx`
```tsx
import Link from "next/link";
export function Header() {
  return (
    <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 24px", height: 56, borderBottom: "1px solid var(--color-border)" }}>
      <Link href="/" style={{ fontWeight: 700, textDecoration: "none", color: "var(--color-text)" }}>&lt;APP NAME&gt;</Link>
      <nav style={{ display: "flex", gap: 16 }}>
        <Link href="/dashboard" style={{ fontSize: 14, color: "var(--color-text-muted)", textDecoration: "none" }}>Dashboard</Link>
      </nav>
    </header>
  );
}
```

#### `lib/api.ts`
```ts
const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("access_token");
}

interface FetchOptions extends RequestInit { on401?: () => void; }

async function request<T>(path: string, options: FetchOptions = {}): Promise<T> {
  const token = getToken();
  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}), ...options.headers },
  });
  if (res.status === 401) { options.on401?.(); throw new Error("Unauthorized"); }
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export const api = {
  get: <T>(path: string, opts?: FetchOptions) => request<T>(path, { method: "GET", ...opts }),
  post: <T>(path: string, body?: unknown, opts?: FetchOptions) =>
    request<T>(path, { method: "POST", body: body ? JSON.stringify(body) : undefined, ...opts }),
  delete: <T>(path: string, opts?: FetchOptions) => request<T>(path, { method: "DELETE", ...opts }),
};
```

#### `lib/hooks.ts`
```ts
"use client";
import { useEffect, useState } from "react";

export function useAuth() {
  const [token, setToken] = useState<string | null>(null);
  useEffect(() => { setToken(localStorage.getItem("access_token")); }, []);
  return { token, isLoggedIn: !!token, signOut: () => { localStorage.removeItem("access_token"); setToken(null); } };
}

type Breakpoint = "mobile" | "tablet" | "desktop";
export function useBreakpoint(): Breakpoint {
  const [bp, setBp] = useState<Breakpoint>("desktop");
  useEffect(() => {
    const update = () => setBp(window.innerWidth < 640 ? "mobile" : window.innerWidth < 1024 ? "tablet" : "desktop");
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);
  return bp;
}
```

#### `lib/utils.ts`
```ts
export const cn = (...c: (string | undefined | false | null)[]): string => c.filter(Boolean).join(" ");
export const formatDate = (iso: string): string =>
  new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
```

#### `types/index.ts`
```ts
export interface User { id: string; email: string; role: string; org_id: string; }
export interface ApiError { detail: string; status: number; }
```

#### `.env.example`
```bash
NEXT_PUBLIC_API_URL=http://localhost:8000
```

#### `.eslintrc.json`
Required — `npm run lint` (next lint) fails in CI without a config file.
```json
{ "extends": "next/core-web-vitals" }
```

#### `.gitignore`
```
node_modules/
.next/
out/
.env.local
.env*.local
```

#### `.github/workflows/ci.yml`
```yaml
name: CI
on:
  push:
    branches: [main, master]
  pull_request:
jobs:
  frontend:
    name: Frontend — type-check + build + lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      # npm install (not ci) — no package-lock.json until first commit; switch to npm ci after.
      - run: npm install
      - run: npm run type-check
      - run: npm run build
      - run: npm run lint
```

#### `CLAUDE.md` (Next.js variant)
```markdown
# CLAUDE.md — <APP NAME>

## THIS PROJECT
**Stack:** Next.js 15, React 19, TypeScript, Tailwind CSS v4
**API:** NEXT_PUBLIC_API_URL in .env

## DEV
```bash
npm install && npm run dev   # http://localhost:3000
npm run type-check           # TypeScript without building
```

## COMPONENT STRUCTURE
```
components/ui/       ← primitives — Button, Input, no business logic
components/layout/   ← Header, Footer, Sidebar — app shell
components/features/ ← page-specific business components
lib/api.ts           ← all fetch calls go through api.get / api.post
lib/hooks.ts         ← useAuth, useBreakpoint
lib/utils.ts         ← cn(), formatDate()
```

## RULES
- CSS custom properties only — never raw hex in components
- All API calls use lib/api.ts — never raw fetch() in components
- components/ui/ are pure primitives — no API calls, no router, no auth
- Every input must have a label with htmlFor

## TYPESCRIPT TYPE RULES — SINGLE SOURCE OF TRUTH
1. Any interface used by 2+ files → lives in `types.ts`, never duplicated
2. Feature modules with 2+ sub-components get a `_components/` folder containing:
   - `types.ts`   — all shared interfaces and union types
   - `styles.ts`  — style objects and style helper functions
   - `helpers.ts` — pure utility functions (no JSX)
3. Union types / type aliases → `types.ts` only, never inside `styles.ts` or `helpers.ts`
4. No workaround types (duck types, partial re-definitions) — fix the import graph instead

## DRY RULES
- Any React component used in 2+ files → extract to shared file before copy-pasting
- Small shared UI helpers (ErrorBanner, Spinner, LoadingState) → `components/ui/`, never inlined

## KNOWN FIXES — DO NOT REVERT
(Record discovered bugs and fixed patterns here so they are never accidentally reverted.
Format: what was wrong → what the fix is → which files it applies to.)
```
- localStorage draft for forms with file inputs: File objects cannot be serialized.
  Wrong: saving the entire form state including File refs → silently stores undefined.
  Fix: save only string/number/select fields; on restore show "files not saved" notice
  with a Clear button; call clearDraft() on successful submit.
  Applies to: any multi-field upload form.

- Debounced auto-save with useRef timer: calling localStorage.setItem inside a useEffect
  on every keystroke hammers storage and causes stale-closure bugs.
  Fix: use useRef<ReturnType<typeof setTimeout>|null>(null); clear previous timer in
  effect body, set new timer (800ms), return cleanup that clears it.
  Applies to: any form with auto-save behaviour.
```

---

