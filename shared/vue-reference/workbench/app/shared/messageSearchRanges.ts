import type { FlareSearchTimeRange } from '@flare-im/vue-ui/contracts';
export type MessageSearchRangePreset = 'any' | 'today' | 'week' | 'month';
/** Today follows the device calendar; rolling ranges are elapsed 24-hour days. */
export function messageSearchRange(preset: MessageSearchRangePreset, now = Date.now()): FlareSearchTimeRange {
  if (preset === 'any') return {};
  if (!Number.isSafeInteger(now) || now < 0) throw new Error('Invalid search clock');
  const start = preset === 'today' ? new Date(now).setHours(0, 0, 0, 0)
    : now - (preset === 'week' ? 7 : 30) * 24 * 60 * 60 * 1000;
  return { fromTime: Math.max(0, start), toTime: now };
}
export function messageSearchRangeLabels(locale: string): Record<MessageSearchRangePreset, string> {
  return locale.startsWith('en') ? { any: 'Any time', today: 'Today', week: 'Last 7 days', month: 'Last 30 days' }
    : { any: '不限时间', today: '今天', week: '最近 7 天', month: '最近 30 天' };
}
