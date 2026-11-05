// M1 end-to-end smoke test against the Auth, Firestore, and Functions emulators.
// Run with: npm run test:smoke
//
// Covers the backend half of M1: Google sign-in creates an attendee profile,
// only an admin can grant roles, granted roles appear in the ID token, and the
// profile's updated_at changes so the app knows to refresh.

import assert from "node:assert/strict";
import { before, describe, it } from "node:test";

const PROJECT = "demo-guyub";
const REGION = "asia-southeast2";
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

async function json(url, init) {
  const response = await fetch(url, init);
  return { status: response.status, body: await response.json() };
}

/** Google sign-in through the Auth emulator's fake IdP. Returns uid and ID token. */
async function signIn(email) {
  const idToken = JSON.stringify({ sub: `google-${email}`, email, email_verified: true, name: email });
  const { status, body } = await json(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=demo-api-key`,
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
  return { uid: body.localId, token: body.idToken };
}

const claimsOf = (token) => JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString());

/** Admin SDK equivalent: set claims directly with the emulator's owner credential. */
async function setClaimsAsOwner(uid, claims) {
  const { status } = await json(`http://${AUTH}/identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:update`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer owner" },
    body: JSON.stringify({ localId: uid, customAttributes: JSON.stringify(claims) }),
  });
  assert.equal(status, 200);
}

const docUrl = (path) => `http://${FIRESTORE}/v1/projects/${PROJECT}/databases/(default)/documents/${path}`;

async function getDoc(path) {
  const { status, body } = await json(docUrl(path), { headers: { authorization: "Bearer owner" } });
  return status === 200 ? body.fields : null;
}

/** onUserCreated runs asynchronously in the Functions emulator. */
async function waitForDoc(path, predicate = () => true, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const fields = await getDoc(path);
    if (fields && predicate(fields)) return fields;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`Timed out waiting for ${path}`);
}

async function callSetUserClaims(token, data) {
  return json(`http://${FUNCTIONS}/${PROJECT}/${REGION}/setUserClaims`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify({ data }),
  });
}

describe("M1 auth and roles", () => {
  let admin;
  let organizer;
  let attendee;

  before(async () => {
    await fetch(docUrl("organizations/himatif"), {
      method: "PATCH",
      headers: { "content-type": "application/json", authorization: "Bearer owner" },
      body: JSON.stringify({ fields: { name: { stringValue: "HIMATIF" }, status: { stringValue: "active" } } }),
    });
    admin = await signIn("smoke-admin@guyub.test");
    organizer = await signIn("smoke-organizer@guyub.test");
    attendee = await signIn("smoke-attendee@guyub.test");
    await setClaimsAsOwner(admin.uid, { role: "admin" });
    admin = await signIn("smoke-admin@guyub.test");
  });

  it("first Google sign-in creates an attendee profile", async () => {
    const fields = await waitForDoc(`users/${attendee.uid}`);
    assert.equal(fields.role.stringValue, "attendee");
    assert.equal(fields.email.stringValue, "smoke-attendee@guyub.test");
  });

  it("a fresh account has no role claim (treated as attendee)", () => {
    assert.equal(claimsOf(attendee.token).role, undefined);
  });

  it("non-admin cannot grant roles", async () => {
    const { status, body } = await callSetUserClaims(attendee.token, { uid: attendee.uid, role: "admin" });
    assert.equal(status, 403);
    assert.equal(body.error.status, "PERMISSION_DENIED");
  });

  it("admin cannot grant a role in an organization that does not exist", async () => {
    const { status, body } = await callSetUserClaims(admin.token, { uid: organizer.uid, role: "organizer", orgId: "ghost" });
    assert.equal(status, 400);
    assert.equal(body.error.status, "INVALID_ARGUMENT");
  });

  it("admin grants organizer; claims reach the next ID token", async () => {
    const { status, body } = await callSetUserClaims(admin.token, { uid: organizer.uid, role: "organizer", orgId: "himatif" });
    assert.equal(status, 200, JSON.stringify(body));
    assert.deepEqual(body.result, { ok: true });

    const refreshed = await signIn("smoke-organizer@guyub.test");
    const claims = claimsOf(refreshed.token);
    assert.equal(claims.role, "organizer");
    assert.equal(claims.orgId, "himatif");
  });

  it("profile mirrors the role and sets updated_at for the app to refresh", async () => {
    const fields = await waitForDoc(`users/${organizer.uid}`, (f) => f.role?.stringValue === "organizer");
    assert.equal(fields.organization_id.stringValue, "himatif");
    assert.ok(fields.updated_at?.timestampValue, "updated_at must be set");
  });
});
