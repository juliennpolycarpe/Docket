import { z } from "zod";

const Env = z.object({
  PORT: z.coerce.number().int().default(8787),
  SUPABASE_URL: z.url(),
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
