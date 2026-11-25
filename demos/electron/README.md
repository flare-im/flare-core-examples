# Flare Core Electron Demo

Requires Node.js 22+ and Python 3.12+.

```sh
python3 scripts/bootstrap.py
npm ci
cp .env.example .env.local
npm run dev
```

Set the Core HTTP base URL, WebSocket URL and tenant in `.env.local` before launching. Sign in with credentials from your Core service. The renderer loads the public WASM. The desktop host uses SQLite/OPFS for persistence.

`npm run build` builds the renderer and Electron main process. `npm run package:dir` produces a runnable desktop distribution.
