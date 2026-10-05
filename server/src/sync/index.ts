import type { FastifyBaseLogger } from "fastify";
import { listAccounts, recordSyncResult, type ConnectedAccount, type Provider } from "../accounts.js";
import { syncCanvas } from "./canvas.js";
import { syncCanvasFeed } from "./canvasFeed.js";

const syncers: Partial<Record<Provider, (account: ConnectedAccount) => Promise<void>>> = {
  canvas: syncCanvas,
  canvas_feed: syncCanvasFeed,
};

export interface SyncResult {
  accountId: string;
  ok: boolean;
  error?: string;
}

// Syncs one account and records the outcome on it, so the app can show
// "last synced" or the error. Never throws.
export async function syncAccount(account: ConnectedAccount): Promise<SyncResult> {
  const syncer = syncers[account.provider];
  if (!syncer) return { accountId: account.id, ok: true };

  let syncError: string | null = null;
  try {
    await syncer(account);
  } catch (err) {
    syncError = err instanceof Error ? err.message : String(err);
  }
  try {
    await recordSyncResult(account.id, syncError);
  } catch (err) {
    syncError ??= err instanceof Error ? err.message : String(err);
  }
  return syncError ? { accountId: account.id, ok: false, error: syncError } : { accountId: account.id, ok: true };
}

export async function syncUser(userId: string): Promise<SyncResult[]> {
  const accounts = await listAccounts(userId);
  return Promise.all(accounts.map(syncAccount));
}

// Background sync for every user's accounts, one account at a time.
export function startSyncLoop(intervalMinutes: number, log: FastifyBaseLogger) {
  let running = false;
  const run = async () => {
    if (running) return;
    running = true;
    try {
      const accounts = await listAccounts();
      for (const account of accounts) {
        const result = await syncAccount(account);
        if (!result.ok) log.warn({ accountId: account.id, provider: account.provider, error: result.error }, "sync failed");
      }
      log.info({ accounts: accounts.length }, "background sync finished");
    } catch (err) {
      log.error(err, "background sync crashed");
    } finally {
      running = false;
    }
  };
  void run();
  return setInterval(run, intervalMinutes * 60 * 1000);
}
