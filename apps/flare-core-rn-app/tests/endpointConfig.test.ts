import assert from 'node:assert/strict';
import test from 'node:test';
import { resolveCoreEndpoints } from '../src/config/endpoints';

test('release requires explicit addresses', () => {
  assert.throws(() => resolveCoreEndpoints('', false), /FLARE_CORE_ENDPOINTS_JSON/);
  assert.deepEqual(resolveCoreEndpoints('{"baseUrl":"https://core.example","websocketUrl":"wss://core.example/ws"}', false), {
    baseUrl: 'https://core.example', websocketUrl: 'wss://core.example/ws',
  });
});
