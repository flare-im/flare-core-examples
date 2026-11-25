# Flare Core Desktop Demo

The application connects to a Flare Core server using the public SDK. It includes sign-in, conversations, messaging, media, and SDK diagnostics.

Requires Node.js 22+, Python 3.12+, and network access to public dependencies.

```sh
python3 scripts/bootstrap.py
npm ci
cp .env.example .env.local
npm run dev
```

Set the Core HTTP base URL, WebSocket URL and tenant in `.env.local` before launching. Use credentials issued by the server that owns the tenant. A self-hosted development gateway may issue local development credentials when configured for that purpose.

`npm run build` builds the frontend and, for Electron, the desktop main process. Electron packaging also supports `npm run package:dir`.
