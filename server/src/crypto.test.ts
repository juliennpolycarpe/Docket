import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { test } from "node:test";
import { decrypt, encrypt, parseKey } from "./crypto.js";

const key = randomBytes(32);

test("round-trips a token", () => {
  const token = "1234~abcdefGHIJKLmnop";
  assert.equal(decrypt(encrypt(token, key), key), token);
});

test("encrypting the same token twice gives different ciphertext", () => {
  assert.notEqual(encrypt("same", key), encrypt("same", key));
});

test("rejects tampered ciphertext", () => {
  const [iv, tag, ciphertext] = encrypt("secret", key).split(".");
  const flipped = Buffer.from(ciphertext, "base64");
  flipped[0] ^= 1;
  assert.throws(() => decrypt([iv, tag, flipped.toString("base64")].join("."), key));
});

test("rejects the wrong key", () => {
  assert.throws(() => decrypt(encrypt("secret", key), randomBytes(32)));
});

test("parseKey requires exactly 32 bytes", () => {
  assert.equal(parseKey(key.toString("base64")).length, 32);
  assert.throws(() => parseKey(randomBytes(16).toString("base64")));
});
