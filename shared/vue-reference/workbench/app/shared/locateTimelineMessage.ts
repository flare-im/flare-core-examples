/** Bounded presentation navigation. The SDK owns history data and request ordering. */
export async function locateTimelineMessage(options: {
  isCurrent: () => boolean;
  scroll: () => Promise<boolean>;
  hasOlder: () => boolean;
  loadOlder: () => Promise<unknown>;
  maxLoads: number;
}): Promise<'found' | 'missing' | 'cancelled'> {
  for (let loaded = 0; ; loaded += 1) {
    if (!options.isCurrent()) return 'cancelled';
    const found = await options.scroll();
    if (!options.isCurrent()) return 'cancelled';
    if (found) return 'found';
    if (loaded >= options.maxLoads || !options.hasOlder()) return 'missing';
    try { await options.loadOlder(); }
    catch (error) {
      if (!options.isCurrent()) return 'cancelled';
      throw error;
    }
  }
}
