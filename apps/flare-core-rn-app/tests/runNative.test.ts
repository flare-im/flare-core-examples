import * as assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { test } from 'node:test';

const require = createRequire(import.meta.url);
const { validateAndroidProject, validateIosProject } = require('../scripts/run-native.js') as {
  validateAndroidProject(appRoot: string): string[];
  validateIosProject(appRoot: string): string[];
};

test('native project validators accept generated iOS and Android project skeletons', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'flare-rn-native-'));

  try {
    mkdirSync(path.join(root, 'ios', 'FlareCoreRnApp.xcodeproj'), { recursive: true });
    writeFileSync(path.join(root, 'ios', 'Podfile'), '');
    mkdirSync(path.join(root, 'android', 'app'), { recursive: true });
    writeFileSync(path.join(root, 'android', 'settings.gradle'), '');
    writeFileSync(path.join(root, 'android', 'app', 'build.gradle'), '');

    assert.deepEqual(validateIosProject(root), []);
    assert.deepEqual(validateAndroidProject(root), []);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
