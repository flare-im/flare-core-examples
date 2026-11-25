# Flare Core Tauri Demo

This demo runs the native Core engine in a Tauri 2 desktop app. It supports message history, media, endpoint configuration, SQLite persistence and optional QUIC.

Install Node.js 22+, Python 3.12+, Rust (with the minimum version in the pinned Engine manifest), `protoc`, and the [Tauri system prerequisites](https://v2.tauri.app/start/prerequisites/).

```sh
python3 scripts/bootstrap.py
npm ci
cp .env.example .env.local
npm run dev
```

Set the HTTP base URL, WebSocket URL and tenant in `.env.local` before launching. Set `VITE_FLARE_QUIC_URL` to enable the optional QUIC endpoint. For a private CA, set `VITE_FLARE_TLS_CA_CERT_PATH` to your local PEM file.

Use `npm run tauri:build` to compile and package the desktop application.
