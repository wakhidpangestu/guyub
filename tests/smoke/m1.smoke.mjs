// M1 end-to-end smoke test against the Auth, Firestore, and Functions emulators.
// Run with: npm run test:smoke
//
// Covers the backend half of M1: Google sign-in creates an attendee profile,
// only an admin can grant roles, granted roles appear in the ID token, and the
// profile mirrors the role so the app knows to refresh.

import assert from "node:assert/strict";
import { before, describe, it } from "node:test";

import { call, claimsOf, errorStatus, putDoc, setClaimsAsOwner, signIn, waitForDoc } from "./support.mjs";

describe("M1 auth and roles", () => {
  let admin;
  let organizer;
  let attendee;

  before(async () => {
    await putDoc("organizations/himatif", { name: "HIMATIF", slug: "himatif", status: "active" });
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
    const response = await call("setUserClaims", attendee.token, { uid: attendee.uid, role: "admin" });
    assert.equal(response.status, 403);
    assert.equal(errorStatus(response), "PERMISSION_DENIED");
  });

  it("admin cannot grant a role in an organization that does not exist", async () => {
    const response = await call("setUserClaims", admin.token, { uid: organizer.uid, role: "organizer", orgId: "ghost" });
    assert.equal(response.status, 400);
    assert.equal(errorStatus(response), "INVALID_ARGUMENT");
  });

  it("admin grants organizer; claims reach the next ID token", async () => {
    const response = await call("setUserClaims", admin.token, { uid: organizer.uid, role: "organizer", orgId: "himatif" });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.deepEqual(response.body.result, { ok: true });

    const refreshed = await signIn("smoke-organizer@guyub.test");
    const claims = claimsOf(refreshed.token);
    assert.equal(claims.role, "organizer");
    assert.equal(claims.orgId, "himatif");
  });

  it("profile mirrors the role and sets updated_at", async () => {
    const fields = await waitForDoc(`users/${organizer.uid}`, (f) => f.role?.stringValue === "organizer");
    assert.equal(fields.organization_id.stringValue, "himatif");
    assert.ok(fields.updated_at?.timestampValue, "updated_at must be set");
  });
});
