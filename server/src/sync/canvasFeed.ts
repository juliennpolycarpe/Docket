import { getCredentials, type ConnectedAccount } from "../accounts.js";
import { db } from "../db.js";
import { feedEventToItem, fetchFeed, normalizeFeedUrl } from "../integrations/canvasFeed.js";

const DAY_MS = 24 * 60 * 60 * 1000;

// Assignments due from two weeks ago onward go to To Do; course events that
// haven't ended (or ended within the last day) go to Upcoming. Anything the
// feed no longer lists (deleted in Canvas, or now too old) is removed. The
// user's own checkmarks and priorities aren't part of the upsert, so they stick.
export async function syncCanvasFeed(account: ConnectedAccount) {
  const { accessToken: feedUrl } = await getCredentials(account.id);
  const items = (await fetchFeed(normalizeFeedUrl(feedUrl))).map(feedEventToItem);
  const now = Date.now();
  const owner = { user_id: account.user_id, account_id: account.id };

  // Keyed by external_id: an upsert fails if the same row appears twice.
  const tasks = new Map<string, Record<string, unknown>>();
  const events = new Map<string, Record<string, unknown>>();
  for (const item of items) {
    if (item.kind === "task") {
      if (Date.parse(item.task.due_at) >= now - 14 * DAY_MS) {
        tasks.set(item.task.external_id, { ...item.task, ...owner, source: "canvas" });
      }
    } else if (Date.parse(item.event.ends_at ?? item.event.starts_at) >= now - DAY_MS) {
      events.set(item.event.external_id, { ...item.event, ...owner });
    }
  }

  await upsertAndPrune("tasks", account.id, [...tasks.values()]);
  await upsertAndPrune("events", account.id, [...events.values()]);
}

async function upsertAndPrune(table: "tasks" | "events", accountId: string, rows: Record<string, unknown>[]) {
  if (rows.length > 0) {
    const { error } = await db.from(table).upsert(rows, { onConflict: "account_id,external_id" });
    if (error) throw new Error(`Saving Canvas ${table} failed: ${error.message}`);
  }

  const { data: existing, error } = await db.from(table).select("id, external_id").eq("account_id", accountId);
  if (error) throw new Error(`Checking Canvas ${table} failed: ${error.message}`);
  const keep = new Set(rows.map((row) => row.external_id));
  const stale = existing.filter((row) => !keep.has(row.external_id)).map((row) => row.id as string);

  for (let i = 0; i < stale.length; i += 100) {
    const { error: deleteError } = await db.from(table).delete().in("id", stale.slice(i, i + 100));
    if (deleteError) throw new Error(`Removing old Canvas ${table} failed: ${deleteError.message}`);
  }
}
