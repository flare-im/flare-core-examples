# Flare Core Web Demo

Requires Node.js 22+ and Python 3.12+.

```sh
python3 scripts/bootstrap.py
npm ci
cp .env.example .env.local
npm run dev
```

Set the Core HTTP base URL, WebSocket URL and tenant in `.env.local` before launching. Sign in with credentials from your Core service. The browser loads the matching public WASM and stores its data in IndexedDB. Use SDK Lab → Connection to apply a new endpoint group at runtime.

Build the static site with `npm run build`. Host `dist/` on a static web server with support for `application/wasm`.
