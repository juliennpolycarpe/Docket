import Fastify from "fastify";
import { requireUser } from "./auth.js";
import { config } from "./config.js";
import { accountRoutes } from "./routes/accounts.js";
import { syncRoutes } from "./routes/sync.js";
import { startSyncLoop } from "./sync/index.js";

const app = Fastify({ logger: true });
app.decorateRequest("userId", "");

app.get("/health", async () => ({ ok: true }));

// Everything registered in here requires a logged-in user.
await app.register(async (authed) => {
  authed.addHook("preHandler", requireUser);
  await authed.register(accountRoutes);
  await authed.register(syncRoutes);
});

// 0.0.0.0 so a phone on the same Wi-Fi can reach the server during development.
await app.listen({ port: config.PORT, host: "0.0.0.0" });
startSyncLoop(config.SYNC_INTERVAL_MINUTES, app.log);
