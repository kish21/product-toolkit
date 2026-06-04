# References - React + Vite frontend scaffold

Loaded ONLY when the user picks **Frontend only -> React + Vite**.

---

### FRONTEND ONLY — REACT + VITE

Only create these files when user chose "Frontend only → React + Vite". Skip all Python/backend files entirely.

#### Directory structure

```
<app-name>/
├── src/
│   ├── components/
│   │   ├── ui/
│   │   │   ├── Button.tsx
│   │   │   ├── Input.tsx
│   │   │   └── index.ts
│   │   ├── layout/
│   │   │   └── Header.tsx
│   │   └── features/      ← empty, fill with page-specific components
│   ├── pages/
│   │   ├── HomePage.tsx
│   │   ├── LoginPage.tsx
│   │   ├── DashboardPage.tsx
│   │   └── NotFoundPage.tsx
│   ├── hooks/
│   │   └── useAuth.ts
│   ├── lib/
│   │   ├── api.ts
│   │   └── utils.ts
│   ├── store/
│   │   └── auth.ts
│   ├── types/
│   │   └── index.ts
│   ├── App.tsx
│   ├── main.tsx
│   ├── vite-env.d.ts
│   └── index.css
├── public/
├── index.html
├── vite.config.ts
├── tsconfig.json
├── tsconfig.app.json
├── tsconfig.node.json
├── eslint.config.js
├── package.json
├── .env.example
├── .gitignore
├── .github/workflows/ci.yml
└── CLAUDE.md
```

#### `package.json`
```json
{
  "name": "<app-name>",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "lint": "eslint .",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^6.28.0",
    "zustand": "^5.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.3.0",
    "typescript": "^5.6.2",
    "vite": "^6.0.0",
    "tailwindcss": "^4.0.0",
    "@tailwindcss/vite": "^4.0.0",
    "eslint": "^9.13.0",
    "typescript-eslint": "^8.15.0",
    "@eslint/js": "^9.13.0",
    "globals": "^15.12.0",
    "eslint-plugin-react-hooks": "^5.0.0",
    "eslint-plugin-react-refresh": "^0.4.14"
  }
}
```

#### `eslint.config.js`
eslint 9 uses flat config — without this file `npm run lint` fails.
```js
import js from "@eslint/js";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist"] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    files: ["**/*.{ts,tsx}"],
    languageOptions: { ecmaVersion: 2020, globals: globals.browser },
    plugins: { "react-hooks": reactHooks, "react-refresh": reactRefresh },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }],
    },
  }
);
```

#### `vite.config.ts`
ESM-safe — `__dirname` does not exist in ESM, and `node:path` needs `@types/node`.
```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "node:path";
import { fileURLToPath } from "node:url";

const dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": path.resolve(dirname, "./src") } },
});
```

#### `src/vite-env.d.ts`
Required — without it `import.meta.env` fails type-check (TS2339).
```ts
/// <reference types="vite/client" />
```

#### `tsconfig.json`
```json
{
  "files": [],
  "references": [{ "path": "./tsconfig.app.json" }, { "path": "./tsconfig.node.json" }]
}
```

#### `tsconfig.app.json`
Referenced by tsconfig.json — without it `tsc -b` (the build script) fails.
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "skipLibCheck": true,
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src"]
}
```

#### `tsconfig.node.json`
```json
{
  "compilerOptions": {
    "target": "ES2022", "lib": ["ES2023"], "module": "ESNext",
    "moduleResolution": "bundler", "allowImportingTsExtensions": true,
    "isolatedModules": true, "moduleDetection": "force",
    "noEmit": true, "strict": true, "skipLibCheck": true
  },
  "include": ["vite.config.ts"]
}
```

#### `index.html`
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><APP NAME></title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

#### `src/main.tsx`
```tsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App";
createRoot(document.getElementById("root")!).render(<StrictMode><App /></StrictMode>);
```

#### `src/App.tsx`
```tsx
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { HomePage } from "./pages/HomePage";
import { LoginPage } from "./pages/LoginPage";
import { DashboardPage } from "./pages/DashboardPage";
import { NotFoundPage } from "./pages/NotFoundPage";
import { useAuthStore } from "./store/auth";

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const token = useAuthStore(s => s.token);
  return token ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/dashboard" element={<PrivateRoute><DashboardPage /></PrivateRoute>} />
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </BrowserRouter>
  );
}
```

#### `src/index.css`
```css
@import "tailwindcss";

/* Token names match the toolkit-wide contract (same as Next.js scaffold + theme.ts):
   --color-text / --color-text-muted — never -primary / -secondary. */
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
}

*, *::before, *::after { box-sizing: border-box; }
body { margin: 0; font-family: var(--font-sans); background: var(--color-background); color: var(--color-text); }
```

#### `src/store/auth.ts`
```ts
import { create } from "zustand";
import { persist } from "zustand/middleware";

interface AuthState {
  token: string | null;
  email: string | null;
  setToken: (token: string, email: string) => void;
  signOut: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    set => ({
      token: null, email: null,
      setToken: (token, email) => set({ token, email }),
      signOut: () => set({ token: null, email: null }),
    }),
    { name: "auth-storage" }
  )
);
```

#### `src/lib/api.ts`
```ts
const BASE_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000";

function getToken(): string | null {
  try { return JSON.parse(localStorage.getItem("auth-storage") ?? "{}").state?.token ?? null; }
  catch { return null; }
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

#### `src/lib/utils.ts`
```ts
export const cn = (...c: (string | undefined | false | null)[]): string => c.filter(Boolean).join(" ");
export const formatDate = (iso: string): string =>
  new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
```

#### `src/hooks/useAuth.ts`
```ts
import { useNavigate } from "react-router-dom";
import { useAuthStore } from "@/store/auth";

export function useAuth() {
  const { token, email, setToken, signOut: storeSignOut } = useAuthStore();
  const navigate = useNavigate();
  return { token, email, isLoggedIn: !!token, setToken, signOut: () => { storeSignOut(); navigate("/login"); } };
}
```

#### `src/pages/HomePage.tsx`
```tsx
import { Link } from "react-router-dom";
export function HomePage() {
  return (
    <main style={{ padding: "4rem 2rem", maxWidth: 640, margin: "0 auto" }}>
      <h1 style={{ fontWeight: 800, fontSize: 48, letterSpacing: "-0.03em", marginBottom: 16 }}>&lt;APP NAME&gt;</h1>
      <p style={{ color: "var(--color-text-muted)", fontSize: 16, marginBottom: 32 }}>Your app description here.</p>
      <Link to="/login" style={{ padding: "10px 20px", backgroundColor: "var(--color-accent)", color: "var(--color-accent-foreground)", borderRadius: "var(--radius)", textDecoration: "none", fontWeight: 600 }}>
        Get started →
      </Link>
    </main>
  );
}
```

#### `src/pages/LoginPage.tsx`
```tsx
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "@/hooks/useAuth";
import { api } from "@/lib/api";

export function LoginPage() {
  const navigate = useNavigate();
  const { setToken } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      const res = await api.post<{ access_token: string }>("/auth/login", { email, password });
      setToken(res.access_token, email);
      navigate("/dashboard");
    } catch { setError("Invalid email or password."); }
  }

  return (
    <main style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "100vh" }}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: 12, width: 320 }}>
        <h1 style={{ fontWeight: 700, fontSize: 24, letterSpacing: "-0.02em" }}>Sign in</h1>
        {error && <p role="alert" style={{ color: "var(--color-error, #dc2626)", fontSize: 13 }}>{error}</p>}
        <label htmlFor="email" style={{ fontSize: 13, fontWeight: 500 }}>Email</label>
        <input id="email" type="email" value={email} onChange={e => setEmail(e.target.value)} required
          style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)" }} />
        <label htmlFor="password" style={{ fontSize: 13, fontWeight: 500 }}>Password</label>
        <input id="password" type="password" value={password} onChange={e => setPassword(e.target.value)} required
          style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)" }} />
        <button type="submit" style={{ padding: "10px", backgroundColor: "var(--color-accent)", color: "var(--color-accent-foreground)", border: "none", borderRadius: "var(--radius)", fontWeight: 600, cursor: "pointer" }}>
          Sign in
        </button>
      </form>
    </main>
  );
}
```

#### `src/pages/DashboardPage.tsx`
```tsx
import { useAuth } from "@/hooks/useAuth";
export function DashboardPage() {
  const { email, signOut } = useAuth();
  return (
    <main style={{ padding: "2rem" }}>
      <h1>Dashboard</h1>
      <p>Signed in as {email}</p>
      <button onClick={signOut} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--color-text-muted)" }}>Sign out</button>
    </main>
  );
}
```

#### `src/pages/NotFoundPage.tsx`
```tsx
import { Link } from "react-router-dom";
export function NotFoundPage() {
  return (
    <main style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", minHeight: "100vh", gap: 16 }}>
      <p style={{ fontWeight: 800, fontSize: 64, letterSpacing: "-0.04em", color: "var(--color-text-muted)" }}>404</p>
      <p>This page does not exist.</p>
      <Link to="/">Go home</Link>
    </main>
  );
}
```

#### `src/components/ui/Button.tsx`
```tsx
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "ghost";
  size?: "sm" | "md" | "lg";
}
export function Button({ variant = "primary", size = "md", children, ...props }: ButtonProps) {
  const pad = { sm: "8px 12px", md: "10px 18px", lg: "12px 24px" }[size];
  return (
    <button {...props} style={{
      padding: pad, cursor: "pointer", fontWeight: 500, borderRadius: "var(--radius)",
      backgroundColor: variant === "primary" ? "var(--color-accent)" : "transparent",
      color: variant === "primary" ? "var(--color-accent-foreground)" : "var(--color-text)",
      border: variant === "secondary" ? "1px solid var(--color-border)" : "none",
      ...props.style,
    }}>{children}</button>
  );
}
```

#### `src/components/ui/Input.tsx`
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

#### `src/components/ui/index.ts`
```ts
export { Button } from "./Button";
export { Input } from "./Input";
```

#### `src/components/layout/Header.tsx`
```tsx
import { Link } from "react-router-dom";
import { useAuth } from "@/hooks/useAuth";
export function Header() {
  const { isLoggedIn, signOut } = useAuth();
  return (
    <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 24px", height: 56, borderBottom: "1px solid var(--color-border)" }}>
      <Link to="/" style={{ fontWeight: 700, textDecoration: "none", color: "var(--color-text)" }}>&lt;APP NAME&gt;</Link>
      <nav>
        {isLoggedIn
          ? <button onClick={signOut} style={{ background: "none", border: "none", cursor: "pointer" }}>Sign out</button>
          : <Link to="/login" style={{ textDecoration: "none", color: "var(--color-text-muted)" }}>Sign in</Link>}
      </nav>
    </header>
  );
}
```

#### `src/types/index.ts`
```ts
export interface User { id: string; email: string; role: string; org_id: string; }
export interface ApiError { detail: string; status: number; }
```

#### `.env.example`
```bash
VITE_API_URL=http://localhost:8000
```

#### `.gitignore`
```
node_modules/
dist/
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

#### `CLAUDE.md` (React + Vite variant)
```markdown
# CLAUDE.md — <APP NAME>

## THIS PROJECT
**Stack:** React 19, Vite 6, TypeScript, Tailwind CSS v4, React Router v6, Zustand
**API:** VITE_API