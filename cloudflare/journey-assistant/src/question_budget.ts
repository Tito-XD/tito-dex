import { DurableObject } from 'cloudflare:workers';

export const DAILY_QUESTION_LIMIT = 1000;
export const MINUTE_QUESTION_LIMIT = 60;
type Counters = { day: number; daily: number; minute: number; burst: number };

// A single named object coordinates all edge locations. Failed requests are
// not refunded. This bounds admitted pipelines, not exact dollar spending.
export class QuestionBudget extends DurableObject<Env> {
  async admit(): Promise<boolean> {
    return this.ctx.storage.transaction(async (storage) => {
      const now = Date.now();
      const day = Math.floor(now / 86_400_000);
      const minute = Math.floor(now / 60_000);
      const previous = await storage.get<Counters>('counters');
      const daily = previous?.day === day ? previous.daily : 0;
      const burst = previous?.minute === minute ? previous.burst : 0;
      if (daily >= DAILY_QUESTION_LIMIT || burst >= MINUTE_QUESTION_LIMIT) return false;
      await storage.put('counters', { day, daily: daily + 1, minute, burst: burst + 1 });
      return true;
    });
  }
}
