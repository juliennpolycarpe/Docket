import type { FastifyInstance } from "fastify";
import { syncUser } from "../sync/index.js";

export async function syncRoutes(app: FastifyInstance) {
  // Pull-to-refresh: sync all of the current user's accounts now.
  app.post("/sync", async (request) => {
    const results = await syncUser(request.userId);
    return { results };
  });
}
