import { z } from "zod";

const Env = z.object({
  PORT: z.coerce.number().int().default(8787),
  // Supabase shows the URL with /rest/v1/ in some places; the client adds that itself.
  SUPABASE_URL: z.url().transform((url) => new URL(url).origin),
  SUPABASE_SECRET_KEY: z.string().min(1),
  TOKEN_ENCRYPTION_KEY: z.string().min(1),
  SYNC_INTERVAL_MINUTES: z.coerce.number().positive().default(15),
});

function loadConfig() {
  const parsed = Env.safeParse(process.env);
  if (!parsed.success) {
    console.error("Missing or invalid settings in server/.env (see .env.example):");
    for (const issue of parsed.error.issues) {
      console.error(`  ${issue.path.join(".")}: ${issue.message}`);
    }
    process.exit(1);
  }
  return parsed.data;
}

export const config = loadConfig();
