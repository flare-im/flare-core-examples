import { FlareUpdateController, type FlareUpdateInstaller } from "@flare-im/core-web-update";
import type { FlareImClient } from "@flare-im/sdk/api";
import type { CreateUpdateController } from "../vue-reference/workbench/app/state/update";

export function commercialUpdateController(
  client: Pick<FlareImClient, "update" | "events">,
  installer: (isInputEmpty: () => boolean) => FlareUpdateInstaller,
): CreateUpdateController {
  return (isInputEmpty, onError) => new FlareUpdateController({
    api: client.update,
    subscribe: (listener) => client.events.onUpdateState(listener),
    loginSucceeded: (listener) => client.events.onLoginSucceeded(listener),
    installer: installer(isInputEmpty),
    onError,
  });
}
