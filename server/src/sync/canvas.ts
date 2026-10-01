import { getCredentials, type ConnectedAccount } from "../accounts.js";
import { db } from "../db.js";
import { getPlannerItems, plannerItemToTask } from "../integrations/canvas.js";

const DAY_MS = 24 * 60 * 60 * 1000;

// Pulls assignments due from two weeks ago (so overdue work still shows) to
// three months ahead, and upserts them into tasks. The user's own `completed`
// checkmark is never overwritten, since it isn't part of the upsert.
export async function syncCanvas(account: ConnectedAccount) {
  if (!account.base_url) throw new Error("Canvas account is missing its address");
  const { accessToken } = await getCredentials(account.id);

  const now = Date.now();
  const items = await getPlannerItems(account.base_url, accessToken, new Date(now - 14 * DAY_MS), new Date(now + 90 * DAY_MS));

  const rows = items.flatMap((item) => {
    const task = plannerItemToTask(item, account.base_url!);
    return task ? [{ ...task, user_id: account.user_id, account_id: account.id, source: "canvas" as const }] : [];
  });
  if (rows.length === 0) return;

  const { error } = await db.from("tasks").upsert(rows, { onConflict: "account_id,external_id" });
  if (error) throw new Error(`Saving Canvas tasks failed: ${error.message}`);
}
