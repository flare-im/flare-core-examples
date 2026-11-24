import type { CoreEndpoints } from '@flare-im/sdk';

declare const __DEV__: boolean;

export function resolveCoreEndpoints(raw: string, development: boolean): CoreEndpoints {
  const supplied = raw.trim();
  if (supplied) {
    const endpoints = JSON.parse(supplied) as CoreEndpoints;
    if (typeof endpoints?.baseUrl === 'string' && typeof endpoints.websocketUrl === 'string') return endpoints;
    throw new Error('FLARE_CORE_ENDPOINTS_JSON requires baseUrl and websocketUrl');
  }
  if (!development) throw new Error('Configure FLARE_CORE_ENDPOINTS_JSON');
  return { baseUrl: 'http://127.0.0.1:50050', websocketUrl: 'ws://127.0.0.1:60051' };
}

export function buildCoreEndpoints(): CoreEndpoints {
  const configuration = (globalThis as { __FLARE_CORE_ENDPOINTS_JSON__?: string }).__FLARE_CORE_ENDPOINTS_JSON__;
  return resolveCoreEndpoints(configuration ?? '', __DEV__);
}
