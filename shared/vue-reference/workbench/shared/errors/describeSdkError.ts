import { translateFlare } from "@flare-im/vue-ui/i18n";

/**
 * 把 SDK 抛出的错误变成能给用户看的一句话。
 *
 * SDK 失败是 `FlareSdkException`：`reason` 是核心给出的 i18n **key**（`FlareError::localized`，
 * 例如 `sdk.message.card.avatar.invalid_url`），等客户端翻译；`message` 只给人看，不解析。
 * kit 的语言表里没有 `sdk.message.*` 这一族，所以这里按「字段 + 原因」拼出可读文案；
 * 任何一步失败都退回到一句人话——绝不把裸 key 交给用户。
 */

const KEY_PATTERN = /^sdk(?:\.[a-z0-9_]+)+$/i;

/** SDK 失败的 i18n key（`FlareSdkException.reason`）；不是 key 时返回 undefined。 */
function reasonKey(error: unknown): string | undefined {
  const reason = error && typeof error === "object" ? (error as { reason?: unknown }).reason : undefined;
  return typeof reason === "string" && KEY_PATTERN.test(reason) ? reason : undefined;
}

/** `sdk.message.card.avatar.invalid_url` -> { field: "card.avatar", reason: "invalid_url" } */
function splitKey(key: string): { field: string; reason: string } | null {
  const parts = key.split(".");
  if (parts.length < 4) return null;
  const reason = parts[parts.length - 1];
  const field = parts.slice(2, -1).join(".");
  return field ? { field, reason } : null;
}

function translated(key: string): string | null {
  const hit = translateFlare(key);
  // 查不到时 resolveFlareMessage 会把 key 原样返回
  return hit && hit !== key ? hit : null;
}

export function describeSdkError(error: unknown, fallback?: string): string {
  const generic = fallback ?? translateFlare("error.operationFailed");
  const key = reasonKey(error);
  if (!key) {
    // 不是带 key 的 SDK 失败（应用自己的错误、桥接失败）：用它自己的说明。
    const raw = error instanceof Error ? error.message : String(error ?? "");
    return raw.trim() || generic;
  }

  const whole = translated(key);
  if (whole) return whole;

  const split = splitKey(key);
  if (split) {
    // 字段没有文案时用「该字段」兜底，不能把 `link_card.thumbnail_url` 这种
    // 内部路径拼进给用户的句子里——那和直接甩 key 没有本质区别。
    const fieldName = translated(`sdkError.field.${split.field}`)
      ?? translated("sdkError.field.unknown")
      ?? "";
    const reason = translated(`sdkError.reason.${split.reason}`);
    if (reason) return reason.replace("{field}", fieldName);
  }

  return generic;
}
