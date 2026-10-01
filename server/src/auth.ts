import type { FastifyReply, FastifyRequest } from "fastify";
import { db } from "./db.js";

declare module "fastify" {
  interface FastifyRequest {
    userId: string;
  }
}

// The app sends the user's Supabase session token as `Authorization: Bearer <token>`.
// Supabase verifies it and tells us which user it belongs to.
export async function requireUser(request: FastifyRequest, reply: FastifyReply) {
  const header = request.headers.authorization;
  const token = header?.startsWith("Bearer ") ? header.slice("Bearer ".length) : undefined;
  if (!token) {
    return reply.code(401).send({ error: "Not logged in" });
  }

  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user) {
    return reply.code(401).send({ error: "Your session has expired. Log in again." });
  }
  request.userId = data.user.id;
}
