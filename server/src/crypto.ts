import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

// Tokens for connected accounts are encrypted with AES-256-GCM before they
// reach the database, so a database leak alone doesn't expose anyone's
// Canvas, Google or Microsoft access.
//
// Stored format: base64(iv).base64(authTag).base64(ciphertext)

export function parseKey(base64Key: string): Buffer {
  const key = Buffer.from(base64Key, "base64");
  if (key.length !== 32) {
    throw new Error("TOKEN_ENCRYPTION_KEY must be 32 random bytes, base64-encoded (generate one with `npm run gen-key`)");
  }
  return key;
}

export function encrypt(plaintext: string, key: Buffer): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  return [iv, cipher.getAuthTag(), ciphertext].map((part) => part.toString("base64")).join(".");
}

export function decrypt(payload: string, key: Buffer): string {
  const parts = payload.split(".");
  if (parts.length !== 3) throw new Error("Malformed encrypted token");
  const [iv, tag, ciphertext] = parts.map((part) => Buffer.from(part, "base64"));
  const decipher = createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString("utf8");
}
