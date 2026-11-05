// Helpers for smoke tests against the Auth, Firestore, and Functions emulators.
// Uses the emulators' REST APIs, so tests exercise the real deployed code paths.

import assert from "node:assert/strict";
import { emulatorHosts } from "./hosts.mjs";

export const PROJECT = "demo-guyub";
export const REGION = "asia-southeast2";
const hosts = await emulatorHosts();

async function json(url, init) {
  const response = await fetch(url, init);
  const text = await response.text();
  return { status: response.status, body: text ? JSON.parse(text) : null };
}

/** Google sign-in through the Auth emulator's fake IdP. Creates the user on first call. */
export async function signIn(email) {
  const idToken = JSON.stringify({ sub: `google-${email}`, email, email_verified: true, name: email.split("@")[0] });
  const { status, body } = await json(
    `http://${hosts.auth}/identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=demo-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        postBody: `id_token=${encodeURIComponent(idToken)}&providerId=google.com`,
        requestUri: "http://localhost",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(status, 200, JSON.stringify(body));
  return { uid: body.localId, token: body.idToken, email };
}

export const claimsOf = (token) => JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString());

/** Admin SDK equivalent: set claims directly with the emulator's owner credential. */
export async function setClaimsAsOwner(uid, claims) {
  const { status } = await json(
    `http://${hosts.auth}/identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:update`,
    {
      method: "POST",
      headers: { "content-type": "application/json", authorization: "Bearer owner" },
      body: JSON.stringify({ localId: uid, customAttributes: JSON.stringify(claims) }),
    },
  );
  assert.equal(status, 200);
}

const docUrl = (path) => `http://${hosts.firestore}/v1/projects/${PROJECT}/databases/(default)/documents/${path}`;

/** Converts plain values to Firestore REST fields. Strings, numbers, booleans, null only. */
function toFields(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === null) fields[key] = { nullValue: null };
    else if (typeof value === "boolean") fields[key] = { booleanValue: value };
    else if (typeof value === "number") fields[key] = { integerValue: String(value) };
    else fields[key] = { stringValue: String(value) };
  }
  return { fields };
}

/** Writes a document bypassing security rules (seeding only). */
export async function putDoc(path, data) {
  const { status, body } = await json(docUrl(path), {
    method: "PATCH",
    headers: { "content-type": "application/json", authorization: "Bearer owner" },
    body: JSON.stringify(toFields(data)),
  });
  assert.equal(status, 200, JSON.stringify(body));
}

/** Updates only the given fields, bypassing security rules (seeding only). */
export async function patchDoc(path, data) {
  const mask = Object.keys(data).map((key) => `updateMask.fieldPaths=${encodeURIComponent(key)}`).join("&");
  const { status, body } = await json(`${docUrl(path)}?${mask}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", authorization: "Bearer owner" },
    body: JSON.stringify(toFields(data)),
  });
  assert.equal(status, 200, JSON.stringify(body));
}

export async function getDoc(path) {
  const { status, body } = await json(docUrl(path), { headers: { authorization: "Bearer owner" } });
  return status === 200 ? body.fields : null;
}

/** Waits for an async trigger (for example onUserCreated) to write a document. */
export async function waitForDoc(path, predicate = () => true, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const fields = await getDoc(path);
    if (fields && predicate(fields)) return fields;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`Timed out waiting for ${path}`);
}

export async function waitForGone(path, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!(await getDoc(path))) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`Timed out waiting for ${path} to be deleted`);
}

/** Calls an onCall function the way the Firebase SDK does. */
export async function call(name, token, data) {
  return json(`http://${hosts.functions}/${PROJECT}/${REGION}/${name}`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify({ data }),
  });
}

/** Returns the error status of a failed call, for example "PERMISSION_DENIED". */
export const errorStatus = (response) => response.body?.error?.status;
