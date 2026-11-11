#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const appRoot = path.resolve(__dirname, '..');
const configPath = path.join(
  appRoot,
  'node_modules',
  '@ant-design',
  'icons-react-native',
  'react-native.config.js',
);

const patchedConfig = `module.exports = {
  dependency: {
    platforms: {
      ios: null,
      android: null,
    },
  },
};
`;

try {
  if (!fs.existsSync(configPath)) {
    process.exit(0);
  }

  const currentConfig = fs.readFileSync(configPath, 'utf8');
  if (currentConfig === patchedConfig) {
    process.exit(0);
  }

  fs.writeFileSync(configPath, patchedConfig);
  console.log(
    '[flare-core-rn-app] patched @ant-design/icons-react-native React Native CLI config',
  );
} catch (error) {
  console.warn(
    `[flare-core-rn-app] could not patch @ant-design/icons-react-native config: ${error.message}`,
  );
}
