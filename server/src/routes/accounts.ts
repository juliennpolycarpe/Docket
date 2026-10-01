import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { deleteAccount, saveAccount } from "../accounts.js";
import { CanvasError, getProfile, normalizeBaseUrl } from "../integrations/canvas.js";
import { syncAccount } from "../sync/index.js";

const CanvasConnect = z.object({
  baseUrl: z.string().min(1),
  token: z.string().min(1),
});

export async function accountRoutes(app: FastifyInstance) {
  // Connect Canvas with a personal access token. The token is checked against
  // Canvas before it's saved, then the first sync runs right away.
  app.post("/accounts/canvas", async (request, reply) => {
    const body = CanvasConnect.safeParse(request.body);
    if (!body.success) {
      return reply.code(400).send({ error: "Enter your Canvas address and access token." });
    }

    let baseUrl: string;
    let profile;
    try {
      baseUrl = normalizeBaseUrl(body.data.baseUrl);
      profile = await getProfile(baseUrl, body.data.token.trim());
    } catch (err) {
      if (err instanceof CanvasError) return reply.code(400).send({ error: err.message });
      if (err instanceof TypeError) return reply.code(400).send({ error: "That doesn't look like a Canvas web address." });
      throw err;
    }

    const account = await saveAccount({
      userId: request.userId,
      provider: "canvas",
      displayName: `${profile.name} (${new URL(baseUrl).hostname})`,
      externalUserId: String(profile.id),
      baseUrl,
      credentials: { accessToken: body.data.token.trim(), refreshToken: null, expiresAt: null },
    });
    const sync = await syncAccount(account);
    return reply.code(201).send({ account, sync });
  });

  app.delete<{ Params: { id: string } }>("/accounts/:id", async (request, reply) => {
    const deleted = await deleteAccount(request.userId, request.params.id);
    if (!deleted) return reply.code(404).send({ error: "Account not found." });
    return reply.code(204).send();
  });
}
