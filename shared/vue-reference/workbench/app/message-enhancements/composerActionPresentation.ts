import type { Component } from "vue";
import type { FlareComposerAttachAction, FlareComposerActionTone } from "@flare-im/vue-ui/components";
import {
  AppsOutline,
  CalendarOutline,
  ChatbubbleEllipsesOutline,
  CheckboxOutline,
  DocumentOutline,
  ImageOutline,
  LinkOutline,
  LocationOutline,
  MegaphoneOutline,
  MicOutline,
  NotificationsOutline,
  PersonOutline,
  ReaderOutline,
  VideocamOutline,
} from "@flare-im/vue-ui/icon-glyphs";
import type { ComposerActionDefinition } from "./messageTypeRegistry";
import type { EnhancedMessageKind } from "./types";

type ComposerActionVisual = {
  icon: Component;
  tone: FlareComposerActionTone;
};

type ComposerActionI18nKey =
  | "file" | "image" | "video" | "location" | "card" | "schedule" | "task"
  | "link" | "richText" | "imageGroup" | "miniProgram" | "vote" | "thread"
  | "notification" | "announcement";

const ACTION_VISUALS: Record<EnhancedMessageKind, ComposerActionVisual> = {
  file: { icon: DocumentOutline, tone: "indigo" },
  image: { icon: ImageOutline, tone: "violet" },
  video: { icon: VideocamOutline, tone: "rose" },
  audio: { icon: MicOutline, tone: "cyan" },
  location: { icon: LocationOutline, tone: "green" },
  card: { icon: PersonOutline, tone: "sky" },
  schedule: { icon: CalendarOutline, tone: "amber" },
  task: { icon: CheckboxOutline, tone: "emerald" },
  linkCard: { icon: LinkOutline, tone: "cyan" },
  richText: { icon: ReaderOutline, tone: "indigo" },
  imageGroup: { icon: ImageOutline, tone: "fuchsia" },
  miniProgram: { icon: AppsOutline, tone: "violet" },
  vote: { icon: CheckboxOutline, tone: "lime" },
  thread: { icon: ChatbubbleEllipsesOutline, tone: "sky" },
  notification: { icon: NotificationsOutline, tone: "yellow" },
  announcement: { icon: MegaphoneOutline, tone: "red" },
};

const ACTION_I18N_KEYS: Record<Exclude<EnhancedMessageKind, "audio">, ComposerActionI18nKey> = {
  file: "file",
  image: "image",
  video: "video",
  location: "location",
  card: "card",
  schedule: "schedule",
  task: "task",
  linkCard: "link",
  richText: "richText",
  imageGroup: "imageGroup",
  miniProgram: "miniProgram",
  vote: "vote",
  thread: "thread",
  notification: "notification",
  announcement: "announcement",
};

/** Maps the example's SDK message builders onto the design kit's action contract. */
export function createComposerAttachActions(
  definitions: readonly ComposerActionDefinition[],
  translate: (key: string) => string,
): FlareComposerAttachAction[] {
  const recordingAction: FlareComposerAttachAction = {
    id: "voice",
    intent: "voice",
    label: translate("composer.voice"),
    icon: MicOutline,
    tone: "cyan",
    order: 0,
  };
  const messageActions = definitions
    .filter((action) => action.kind !== "audio")
    .map<FlareComposerAttachAction>((action, index) => {
      const key = ACTION_I18N_KEYS[action.kind as Exclude<EnhancedMessageKind, "audio">];
      return {
        id: action.kind,
        intent: action.op,
        label: translate(`composeType.${key}.label`),
        hint: translate(`composeType.${key}.description`),
        icon: ACTION_VISUALS[action.kind].icon,
        tone: ACTION_VISUALS[action.kind].tone,
        order: index + 1,
      };
    });
  return [recordingAction, ...messageActions];
}
