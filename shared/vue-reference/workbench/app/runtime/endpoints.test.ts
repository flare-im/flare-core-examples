import { describe, expect, it } from "vitest";
import { resolveCoreEndpoints } from "./endpoints";

describe("Core deployment endpoints", () => {
  it("requires explicit production addresses", () => {
    expect(() => resolveCoreEndpoints({})).toThrow(/VITE_FLARE_CORE_API_URL/);
    expect(resolveCoreEndpoints({
      VITE_FLARE_CORE_API_URL: "https://core.example",
      VITE_FLARE_WEBSOCKET_URL: "wss://core.example/ws",
    })).toEqual({ baseUrl: "https://core.example", websocketUrl: "wss://core.example/ws" });
  });

  it("uses the local stack on the development server", () => {
    expect(resolveCoreEndpoints({ DEV: true })).toEqual({
      baseUrl: "http://127.0.0.1:50050",
      websocketUrl: "ws://127.0.0.1:60051",
    });
  });
});
