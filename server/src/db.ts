import { createClient } from "@supabase/supabase-js";
import { config } from "./config.js";

// Server-side Supabase client. The secret key bypasses row-level security,
// so every query made with it must filter by user_id itself.
export const db = createClient(config.SUPABASE_URL, config.SUPABASE_SECRET_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
