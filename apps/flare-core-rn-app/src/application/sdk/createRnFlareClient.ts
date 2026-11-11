import type { FlareImClient } from '@flare-im/sdk/api';
import { FlareCoreSdk } from '@flare-im/sdk/react-native';

export function createRnFlareClient(): FlareImClient {
  return FlareCoreSdk.createClient();
}
