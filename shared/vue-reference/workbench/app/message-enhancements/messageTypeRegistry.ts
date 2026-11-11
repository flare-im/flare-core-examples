import { MessageBuildOp, MessageContentType } from "@flare-im/sdk/web";
import { translateFlare } from "@flare-im/vue-ui/i18n";
import type { Message } from "@flare-im/sdk/web";
import type {
  CapabilityContext,
  ComposerPayloadRequest,
  EnhancedMessageKind,
  MessageCapabilities,
  OperationAvailability,
} from "./types";
import { messageIsPinned, messageStableId } from "./types";

export type ComposerActionDefinition = {
  kind: EnhancedMessageKind;
  op: string;
  label: string;
  description: string;
  acceptsFiles?: boolean;
  multipleFiles?: boolean;
  maxFileBytes?: number;
  defaultParams: () => Record<string, unknown>;
  buildRequest: (params: Record<string, unknown>, files?: File[]) => ComposerPayloadRequest;
};

const MB = 1024 * 1024;

function payload(kind: EnhancedMessageKind, fields: Record<string, unknown>): Record<string, unknown> {
  return {
    kind,
    payloadVersion: 1,
    ...fields,
    ext: {
      source: "flare-core-web-app",
      ...(fields.ext && typeof fields.ext === "object" ? fields.ext as Record<string, unknown> : {}),
    },
  };
}

type ImageSourceParam = {
  imageId: string;
  fileName?: string;
  mimeType?: string;
  size?: number;
  width?: number;
  height?: number;
};

type ContentPayloadRequest = {
  op: MessageBuildOp.CreateWithContent;
  kind: EnhancedMessageKind;
  previewText: string;
  params: {
    contentType: MessageContentType;
    data: Record<string, unknown>;
  };
};

function mediaContentRequest(
  kind: EnhancedMessageKind,
  contentType: MessageContentType,
  data: Record<string, unknown>,
  previewText: string,
): ContentPayloadRequest {
  return {
    op: MessageBuildOp.CreateWithContent,
    kind,
    previewText,
    params: { contentType, data },
  };
}

function mediaSize(params: Record<string, unknown>): number {
  return optionalNumberParam(params, "fileSize") || optionalNumberParam(params, "size");
}

function firstSelectedFile(files: File[]): File | undefined {
  return files.find((file) =>
    typeof File === "undefined" ? Boolean(file?.name) : file instanceof File,
  );
}

function basenameFromPath(value: string): string {
  const raw = value.trim();
  if (!raw) return "";
  const normalized = raw.replace(/\\/g, "/");
  const name = normalized.split("/").filter(Boolean).pop() ?? "";
  try {
    return decodeURIComponent(name);
  } catch {
    return name;
  }
}

function mediaFileName(
  params: Record<string, unknown>,
  files: File[],
  sourcePath: string,
  fallback: string,
): string {
  return (
    textParam(params, "fileName") ||
    firstSelectedFile(files)?.name.trim() ||
    basenameFromPath(sourcePath) ||
    fallback
  );
}

function mediaMimeType(params: Record<string, unknown>, files: File[], fallback: string): string {
  return textParam(params, "mimeType") || firstSelectedFile(files)?.type || fallback;
}

function mediaFileSize(params: Record<string, unknown>, files: File[]): number {
  return mediaSize(params) || firstSelectedFile(files)?.size || 0;
}

function imageInfo(source: {
  sourcePath: string;
  fileName?: string;
  mimeType: string;
  size: number;
  width?: number;
  height?: number;
}): Record<string, unknown> {
  return {
    uuid: source.sourcePath,
    imageId: source.sourcePath,
    url: source.sourcePath,
    ...(source.fileName ? { fileName: source.fileName } : {}),
    mimeType: source.mimeType || "image/jpeg",
    size: source.size || 0,
    width: source.width ?? 0,
    height: source.height ?? 0,
  };
}

function mediaMeta(params: Record<string, unknown>): Record<string, unknown> {
  const fileName = textParam(params, "fileName");
  const mimeType = textParam(params, "mimeType");
  const fileSize = optionalNumberParam(params, "fileSize") || optionalNumberParam(params, "size");
  return {
    ...(fileName ? { fileName } : {}),
    ...(mimeType ? { mimeType } : {}),
    ...(fileSize > 0 ? { fileSize, size: fileSize } : {}),
  };
}

function textParam(params: Record<string, unknown>, key: string): string {
  return String(params[key] ?? "").trim();
}

function requireTextParam(params: Record<string, unknown>, key: string, label: string): string {
  const value = textParam(params, key);
  if (!value) throw new Error(`${label} is required`);
  return value;
}

function requireFileOrTextParam(
  params: Record<string, unknown>,
  key: string,
  label: string,
): string {
  const value = textParam(params, key);
  const sourcePath = textParam(params, "sourcePath");
  if (!value && !sourcePath) throw new Error(translateFlare("composeType.error.needRealFileOr", { label }));
  return sourcePath || value;
}

function optionalNumberParam(params: Record<string, unknown>, key: string): number {
  const raw = params[key];
  if (raw === "" || raw === undefined || raw === null) return 0;
  const value = Number(raw);
  if (!Number.isFinite(value)) throw new Error(`${key} must be a finite number`);
  return value;
}

function generatedId(prefix: string): string {
  return `${prefix}-${Date.now()}`;
}

function scheduleTimeMs(params: Record<string, unknown>): number {
  const raw = textParam(params, "time");
  if (!raw) throw new Error(translateFlare("composeType.error.scheduleTimeRequired"));
  const numeric = Number(raw);
  if (Number.isFinite(numeric) && numeric > 0) {
    return numeric > 10_000_000_000 ? Math.trunc(numeric) : Math.trunc(numeric * 1000);
  }
  const parsed = Date.parse(raw);
  if (!Number.isFinite(parsed)) throw new Error(translateFlare("composeType.error.scheduleTimeInvalid"));
  return parsed;
}

export const composerActions: ComposerActionDefinition[] = [
  {
    kind: "file",
    op: "create_file",
    label: translateFlare("composeType.file.label"),
    description: translateFlare("composeType.file.description"),
    acceptsFiles: true,
    maxFileBytes: 100 * MB,
    defaultParams: () => ({ sourcePath: "", fileId: "", fileName: "", mimeType: "", fileSize: 0 }),
    buildRequest: (params, files = []) => {
      const sourcePath = requireFileOrTextParam(params, "fileId", "fileId");
      const fileName = mediaFileName(params, files, sourcePath, translateFlare("composeType.file.label"));
      const mimeType = mediaMimeType(params, files, "application/octet-stream");
      const fileSize = mediaFileSize(params, files);
      return mediaContentRequest(
        "file",
        MessageContentType.File,
        {
          fileId: sourcePath,
          fileName,
          mimeType,
          fileSize,
          url: sourcePath,
          description: String(params.description ?? ""),
        },
        fileName,
      );
    },
  },
  {
    kind: "image",
    op: "create_image",
    label: translateFlare("composeType.image.label"),
    description: translateFlare("composeType.image.description"),
    acceptsFiles: true,
    maxFileBytes: 30 * MB,
    defaultParams: () => ({ sourcePath: "", imageId: "", description: "", url: "", mimeType: "", width: 0, height: 0 }),
    buildRequest: (params, files = []) => {
      const sourcePath = requireFileOrTextParam(params, "imageId", "imageId");
      const mimeType = mediaMimeType(params, files, "image/jpeg");
      const fileName = mediaFileName(params, files, sourcePath, "");
      const source = imageInfo({
        sourcePath,
        fileName,
        mimeType,
        size: mediaFileSize(params, files),
        width: optionalNumberParam(params, "width"),
        height: optionalNumberParam(params, "height"),
      });
      return mediaContentRequest(
        "image",
        MessageContentType.Image,
        {
          source,
          thumbnail: source,
          description: String(params.description ?? ""),
        },
        String(params.description || translateFlare("composer.image")),
      );
    },
  },
  {
    kind: "video",
    op: "create_video",
    label: translateFlare("composeType.video.label"),
    description: translateFlare("composeType.video.description"),
    acceptsFiles: true,
    maxFileBytes: 500 * MB,
    defaultParams: () => ({ sourcePath: "", videoId: "", description: "", durationMs: 0, mimeType: "" }),
    buildRequest: (params, files = []) => {
      const sourcePath = requireFileOrTextParam(params, "videoId", "videoId");
      const mimeType = mediaMimeType(params, files, "video/mp4");
      const fileName = mediaFileName(params, files, sourcePath, translateFlare("composeType.video.label"));
      const description = textParam(params, "description") || fileName;
      const durationMs = optionalNumberParam(params, "durationMs");
      return mediaContentRequest(
        "video",
        MessageContentType.Video,
        {
          videoId: sourcePath,
          source: {
            uuid: sourcePath,
            url: sourcePath,
            fileName,
            mimeType,
            size: mediaFileSize(params, files),
            durationMs,
            width: optionalNumberParam(params, "width"),
            height: optionalNumberParam(params, "height"),
          },
          cover: null,
          fileName,
          title: fileName,
          description,
        },
        description,
      );
    },
  },
  {
    kind: "audio",
    op: "create_audio",
    label: translateFlare("composeType.audio.label"),
    description: translateFlare("composeType.audio.description"),
    acceptsFiles: true,
    maxFileBytes: 50 * MB,
    defaultParams: () => ({ sourcePath: "", audioId: "", sourceUrl: "", description: "", durationMs: 0, mimeType: "" }),
    buildRequest: (params, files = []) => {
      void files;
      const fallbackSource = requireFileOrTextParam(params, "audioId", "audioId");
      const audioId = textParam(params, "audioId") || fallbackSource;
      const sourceUrl = textParam(params, "sourceUrl") || textParam(params, "mediaUrl") || textParam(params, "downloadUrl") || textParam(params, "url") || fallbackSource;
      const mimeType = textParam(params, "mimeType") || "audio/webm";
      return mediaContentRequest(
        "audio",
        MessageContentType.Audio,
        {
          audioId,
          source: {
            uuid: audioId,
            url: sourceUrl,
            ...(textParam(params, "fileName") ? { fileName: textParam(params, "fileName") } : {}),
            mimeType,
            size: mediaSize(params),
            durationMs: optionalNumberParam(params, "durationMs"),
          },
          description: String(params.description ?? ""),
        },
        String(params.description || translateFlare("composeType.audio.label")),
      );
    },
  },
  {
    kind: "location",
    op: "create_location",
    label: translateFlare("composeType.location.label"),
    description: translateFlare("composeType.location.description"),
    defaultParams: () => ({ title: "", address: "", latitude: "", longitude: "" }),
    buildRequest: (params) => ({
      op: "create_location",
      kind: "location",
      previewText: requireTextParam(params, "title", translateFlare("composeType.field.locationName")),
      params: {
        latitude: requireTextParam(params, "latitude", translateFlare("composeType.field.latitude")),
        longitude: requireTextParam(params, "longitude", translateFlare("composeType.field.longitude")),
        title: requireTextParam(params, "title", translateFlare("composeType.field.locationName")),
        address: textParam(params, "address"),
      },
    }),
  },
  {
    kind: "card",
    op: "create_card",
    label: translateFlare("composeType.card.label"),
    description: translateFlare("composeType.card.description"),
    defaultParams: () => ({ id: "", cardType: "user", title: "", subtitle: "", avatar: "" }),
    buildRequest: (params) => ({
      op: "create_card",
      kind: "card",
      previewText: requireTextParam(params, "title", translateFlare("composeType.field.cardTitle")),
      params: {
        id: requireTextParam(params, "id", translateFlare("composeType.field.cardId")),
        cardType: textParam(params, "cardType") || "user",
        title: requireTextParam(params, "title", translateFlare("composeType.field.cardTitle")),
        subtitle: textParam(params, "subtitle"),
        avatar: textParam(params, "avatar"),
      },
    }),
  },
  {
    kind: "schedule",
    op: "create_schedule",
    label: translateFlare("composeType.schedule.label"),
    description: translateFlare("composeType.schedule.description"),
    defaultParams: () => ({ scheduleId: generatedId("schedule"), title: "", time: "", location: "", participantUserIds: [] }),
    buildRequest: (params) => {
      const startTimeMs = scheduleTimeMs(params);
      return {
        op: "create_schedule",
        kind: "schedule",
        previewText: requireTextParam(params, "title", translateFlare("composeType.field.scheduleTitle")),
        params: {
          scheduleId: textParam(params, "scheduleId") || generatedId("schedule"),
          title: requireTextParam(params, "title", translateFlare("composeType.field.scheduleTitle")),
          startTimeMs,
          endTimeMs: startTimeMs + 60 * 60 * 1000,
          participantUserIds: Array.isArray(params.participantUserIds) ? params.participantUserIds : [],
          location: textParam(params, "location"),
        },
      };
    },
  },
  {
    kind: "task",
    op: "create_task",
    label: translateFlare("composeType.task.label"),
    description: translateFlare("composeType.task.description"),
    defaultParams: () => ({ taskId: generatedId("task"), title: "", assignee: "", dueTime: "", status: "todo", participantUserIds: [] }),
    buildRequest: (params) => ({
      op: "create_task",
      kind: "task",
        previewText: requireTextParam(params, "title", translateFlare("composeType.field.taskTitle")),
        params: {
        taskId: textParam(params, "taskId") || generatedId("task"),
        title: requireTextParam(params, "title", translateFlare("composeType.field.taskTitle")),
        status: textParam(params, "status") || "todo",
        participantUserIds: Array.isArray(params.participantUserIds) ? params.participantUserIds : [],
      },
    }),
  },
  {
    kind: "linkCard",
    op: "create_link_card",
    label: translateFlare("composeType.link.label"),
    description: translateFlare("composeType.link.description"),
    defaultParams: () => ({ url: "", title: "", description: "", domain: "" }),
    buildRequest: (params) => ({
      op: "create_link_card",
      kind: "linkCard",
      previewText: textParam(params, "title") || requireTextParam(params, "url", translateFlare("composeType.field.linkUrl")),
      params: {
        url: requireTextParam(params, "url", translateFlare("composeType.field.linkUrl")),
        title: textParam(params, "title"),
        description: textParam(params, "description"),
        thumbnailUrl: textParam(params, "thumbnailUrl"),
        siteName: textParam(params, "domain") || textParam(params, "siteName"),
      },
    }),
  },
  {
    kind: "richText",
    op: "create_rich_doc",
    label: translateFlare("composeType.richText.label"),
    description: translateFlare("composeType.richText.description"),
    defaultParams: () => ({ title: "", markdown: "" }),
    buildRequest: (params) => ({
      op: "create_rich_doc",
      kind: "richText",
      previewText: requireTextParam(params, "title", translateFlare("composeType.field.richTitle")),
      params: {
        markdown: requireTextParam(params, "markdown", translateFlare("composeType.field.richMarkdown")),
        title: requireTextParam(params, "title", translateFlare("composeType.field.richTitle")),
      },
    }),
  },
  {
    kind: "imageGroup",
    op: "create_image_group",
    label: translateFlare("composeType.imageGroup.label"),
    description: translateFlare("composeType.imageGroup.description"),
    acceptsFiles: true,
    multipleFiles: true,
    maxFileBytes: 80 * MB,
    defaultParams: () => ({ description: "", imageSources: [] }),
    buildRequest: (params, files = []) => {
      void files;
      const imageSources = Array.isArray(params.imageSources)
        ? params.imageSources as ImageSourceParam[]
        : [];
      if (!imageSources.length) throw new Error(translateFlare("composeType.error.needRealImages"));
      const description = String(params.description ?? "");
      return mediaContentRequest(
        "imageGroup",
        MessageContentType.ImageGroup,
        {
          images: imageSources.map((item) => imageInfo({
            sourcePath: item.imageId,
            fileName: item.fileName,
            mimeType: item.mimeType || "image/jpeg",
            size: item.size ?? 0,
            width: item.width ?? 0,
            height: item.height ?? 0,
          })),
          description,
          metadata: {
            source: "flare-core-web-app",
            imageCount: String(imageSources.length),
          },
        },
        description || imageSources.map((item) => item.fileName || translateFlare("composer.image")).join(translateFlare("title.memberSeparator")),
      );
    },
  },
  {
    kind: "miniProgram",
    op: "create_mini_program",
    label: translateFlare("composeType.miniProgram.label"),
    description: translateFlare("composeType.miniProgram.description"),
    defaultParams: () => ({ appId: "", appName: "", pagePath: "", title: "", description: "", thumbnailUrl: "" }),
    buildRequest: (params) => ({
      op: "create_mini_program",
      kind: "miniProgram",
      previewText: requireTextParam(params, "title", translateFlare("composeType.field.miniTitle")),
      params: {
        appId: requireTextParam(params, "appId", translateFlare("composeType.field.miniAppId")),
        pagePath: textParam(params, "pagePath"),
        title: requireTextParam(params, "title", translateFlare("composeType.field.miniTitle")),
        thumbnailUrl: textParam(params, "thumbnailUrl"),
        extra: {
          appName: textParam(params, "appName"),
          description: textParam(params, "description"),
        },
      },
    }),
  },
  {
    kind: "vote",
    op: "create_vote",
    label: translateFlare("composeType.vote.label"),
    description: translateFlare("composeType.vote.description"),
    defaultParams: () => ({ voteId: generatedId("vote"), title: "", options: [], multiple: false, anonymous: false, deadline: "", participantUserIds: [] }),
    buildRequest: (params) => {
      if (!Array.isArray(params.options) || params.options.length === 0) {
        throw new Error(translateFlare("composeType.error.voteOptionsRequired"));
      }
      return {
        op: "create_vote",
          kind: "vote",
          previewText: requireTextParam(params, "title", translateFlare("composeType.field.voteTitle")),
          params: {
          voteId: textParam(params, "voteId") || generatedId("vote"),
          title: requireTextParam(params, "title", translateFlare("composeType.field.voteTitle")),
          options: params.options,
          participantUserIds: Array.isArray(params.participantUserIds) ? params.participantUserIds : [],
        },
      };
    },
  },
  {
    kind: "thread",
    op: "create_thread_reply",
    label: translateFlare("composeType.thread.label"),
    description: translateFlare("composeType.thread.description"),
    defaultParams: () => ({ threadId: "", text: "", title: "", summary: "" }),
    buildRequest: (params) => {
      const text =
        textParam(params, "text") ||
        textParam(params, "title") ||
        textParam(params, "summary");
      if (!text) throw new Error(translateFlare("composeType.error.threadReplyRequired"));
      return {
        op: "create_thread_reply",
        kind: "thread",
        previewText: text,
        params: {
          threadId: requireTextParam(params, "threadId", "Thread ID"),
          text,
        },
      };
    },
  },
  {
    kind: "notification",
    op: "create_notification",
    label: translateFlare("composeType.notification.label"),
    description: translateFlare("composeType.notification.description"),
    defaultParams: () => ({ title: "", text: "" }),
    buildRequest: (params) => ({
      op: "create_notification",
      kind: "notification",
      previewText: requireTextParam(params, "text", translateFlare("composeType.field.notificationBody")),
      params: {
        title: textParam(params, "title") || translateFlare("composeType.notification.label"),
        body: requireTextParam(params, "text", translateFlare("composeType.field.notificationBody")),
      },
    }),
  },
  {
    kind: "announcement",
    op: "create_announcement",
    label: translateFlare("composeType.announcement.label"),
    description: translateFlare("composeType.announcement.description"),
    defaultParams: () => ({ title: "", text: "" }),
    buildRequest: (params) => ({
      op: "create_announcement",
      kind: "announcement",
      previewText: textParam(params, "title") || requireTextParam(params, "text", translateFlare("composeType.field.announcementBody")),
      params: {
        title: textParam(params, "title") || translateFlare("composeType.announcement.label"),
        body: requireTextParam(params, "text", translateFlare("composeType.field.announcementBody")),
      },
    }),
  },
];

export function resolveComposerAction(op: string): ComposerActionDefinition | undefined {
  return composerActions.find((action) => action.op === op);
}

function available(enabled: boolean, reason?: string): OperationAvailability {
  return enabled ? { enabled: true } : { enabled: false, reason };
}

function hasAuthoritativeIdentity(message: Message): boolean {
  return message.conversationSeq > 0 || message.serverId.trim().length > 0;
}

function isLocalSending(message: Message): boolean {
  return Boolean(message.localState?.sending) && !hasAuthoritativeIdentity(message);
}

function isLocalFailed(message: Message): boolean {
  return Boolean(message.localState?.failed) && !hasAuthoritativeIdentity(message);
}

export function resolveMessageCapabilities(message: Message, context: CapabilityContext): MessageCapabilities {
  const id = messageStableId(message);
  const recalled = Boolean(message.isRecalled);
  const sending = isLocalSending(message);
  const failed = isLocalFailed(message);
  const deleted = !id;
  const offlineReason = context.connected ? undefined : translateFlare("availability.offline");
  const active = context.connected && !recalled && !deleted;
  const self = message.senderId === context.currentUserId;

  return {
    canReact: available(active && !sending, sending ? translateFlare("availability.sending") : offlineReason || translateFlare("availability.cannotReact")),
    canReply: available(!context.multiSelectMode && !recalled && !deleted, translateFlare("availability.cannotReply")),
    canForward: available(!recalled && !deleted && !sending, translateFlare("availability.cannotForward")),
    canCopy: available(!recalled && !deleted, translateFlare("availability.cannotCopy")),
    canEdit: available(!context.multiSelectMode && self && active && !sending && !failed, translateFlare("availability.cannotEdit")),
    canDelete: available(active, offlineReason || translateFlare("availability.cannotDelete")),
    canRecall: available(!context.multiSelectMode && self && active && !failed, translateFlare("availability.cannotRecall")),
    canPin: available(active && !sending, sending ? translateFlare("availability.sending") : offlineReason || translateFlare("availability.cannotPin")),
    canMultiSelect: available(!recalled && !deleted, translateFlare("availability.cannotMultiSelect")),
  };
}

export function messagePinnedLabel(message: Message): string {
  return translateFlare(messageIsPinned(message) ? "messageMenu.unpin" : "messageMenu.pin");
}

export function resolveMessageMenuActions(
  message: Message,
  context: CapabilityContext,
): Record<string, boolean> {
  const capabilities = resolveMessageCapabilities(message, context);
  const self = message.senderId === context.currentUserId;
  const failed = isLocalFailed(message);
  const pinned = messageIsPinned(message);
  return {
    reply: capabilities.canReply.enabled,
    forward: capabilities.canForward.enabled,
    multiSelect: capabilities.canMultiSelect.enabled,
    edit: capabilities.canEdit.enabled,
    recall: capabilities.canRecall.enabled,
    resend: context.connected && self && failed,
    pin: capabilities.canPin.enabled && !pinned,
    unpin: capabilities.canPin.enabled && pinned,
    preview: !message.isRecalled,
    copy: capabilities.canCopy.enabled,
    mark: context.connected && !message.isRecalled,
    delete: capabilities.canDelete.enabled,
  };
}
