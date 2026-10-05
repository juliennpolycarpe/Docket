import { config } from "./config.js";
import { decrypt, encrypt, parseKey } from "./crypto.js";
import { db } from "./db.js";

const key = parseKey(config.TOKEN_ENCRYPTION_KEY);

export type Provider = "canvas" | "canvas_feed" | "google" | "microsoft";

export interface ConnectedAccount {
  id: string;
  user_id: string;
  provider: Provider;
  display_name: string;
  external_user_id: string;
  base_url: string | null;
  last_synced_at: string | null;
  last_sync_error: string | null;
  created_at: string;
}

export interface Credentials {
  accessToken: string;
  refreshToken: string | null;
  expiresAt: Date | null;
}

export interface NewAccount {
  userId: string;
  provider: Provider;
  displayName: string;
  externalUserId: string;
  baseUrl?: string;
  credentials: Credentials;
}

// Creates the account, or updates it if the user connects the same one again
// (e.g. with a fresh Canvas token).
export async function saveAccount(input: NewAccount): Promise<ConnectedAccount> {
  const { data: account, error } = await db
    .from("connected_accounts")
    .upsert(
      {
        user_id: input.userId,
        provider: input.provider,
        display_name: input.displayName,
        external_user_id: input.externalUserId,
        base_url: input.baseUrl ?? null,
        last_sync_error: null,
      },
      { onConflict: "user_id,provider,external_user_id,base_url" },
    )
    .select()
    .single<ConnectedAccount>();
  if (error) throw new Error(`Saving account failed: ${error.message}`);

  const { credentials } = input;
  const { error: credentialsError } = await db.from("account_credentials").upsert({
    account_id: account.id,
    access_token: encrypt(credentials.accessToken, key),
    refresh_token: credentials.refreshToken ? encrypt(credentials.refreshToken, key) : null,
    expires_at: credentials.expiresAt?.toISOString() ?? null,
    updated_at: new Date().toISOString(),
  });
  if (credentialsError) throw new Error(`Saving account credentials failed: ${credentialsError.message}`);

  return account;
}

export async function getCredentials(accountId: string): Promise<Credentials> {
  const { data, error } = await db
    .from("account_credentials")
    .select("access_token, refresh_token, expires_at")
    .eq("account_id", accountId)
    .single();
  if (error) throw new Error(`Loading account credentials failed: ${error.message}`);

  return {
    accessToken: decrypt(data.access_token, key),
    refreshToken: data.refresh_token ? decrypt(data.refresh_token, key) : null,
    expiresAt: data.expires_at ? new Date(data.expires_at) : null,
  };
}

// All accounts for one user, or every account when userId is omitted (background sync).
export async function listAccounts(userId?: string): Promise<ConnectedAccount[]> {
  let query = db.from("connected_accounts").select("*");
  if (userId) query = query.eq("user_id", userId);
  const { data, error } = await query.returns<ConnectedAccount[]>();
  if (error) throw new Error(`Loading accounts failed: ${error.message}`);
  return data;
}

// Returns false if the account doesn't exist or belongs to someone else.
// Its credentials, tasks, events and emails are removed by cascade.
export async function deleteAccount(userId: string, accountId: string): Promise<boolean> {
  const { data, error } = await db
    .from("connected_accounts")
    .delete()
    .eq("id", accountId)
    .eq("user_id", userId)
    .select("id");
  if (error) throw new Error(`Removing account failed: ${error.message}`);
  return data.length > 0;
}

export async function recordSyncResult(accountId: string, syncError: string | null) {
  const update = syncError
    ? { last_sync_error: syncError }
    : { last_sync_error: null, last_synced_at: new Date().toISOString() };
  const { error } = await db.from("connected_accounts").update(update).eq("id", accountId);
  if (error) throw new Error(`Recording sync result failed: ${error.message}`);
}
