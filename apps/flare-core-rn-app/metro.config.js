const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('node:path');

const config = {
  resolver: {
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
  },
  watchFolders: [
    path.resolve(__dirname, '../../../flare-core-sdk/packages/flare-core-typescript-sdk'),
  ],
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
