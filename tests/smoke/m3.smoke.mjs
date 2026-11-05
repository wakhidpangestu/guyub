// M3 end-to-end smoke test: attendee registration and QR tickets.
// Run with: npm run test:smoke
//
// Covers registerForEvent (consent, open/closed, capacity under the
// transaction, idempotency, role check) and cancelRegistration.

import assert from "node:assert/strict";
import { before, describe, it } from "node:test";

import { call, errorStatus, getDoc, patchDoc, putDoc, setClaimsAsOwner, signIn } from "./support.mjs";

const count = async (eventId) => Number((await getDoc(`events/${eventId}`)).registered_count?.integerValue ?? 0);
const register = (who, eventId, privacyConsent = true) => call("registerForEvent", who.token, { eventId, privacyConsent });

describe("M3 registration and tickets", () => {
  let alice;
  let bob;
  let carol;

  before(async () => {
    await putDoc("organizations/m3-org", { name: "M3 Org", slug: "m3-org", status: "active" });
    const base = { organization_id: "m3-org", title: "Event", created_by: "x", registered_count: 0 };
    await putDoc("events/m3-open", { ...base, status: "active", registration_open: true, capacity: 2 });
    await putDoc("events/m3-closed", { ...base, status: "active", registration_open: false, capacity: null });
    await putDoc("events/m3-draft", { ...base, status: "draft", registration_open: false, capacity: null });
    alice = await signIn("m3-alice@guyub.test");
    bob = await signIn("m3-bob@guyub.test");
    carol = await signIn("m3-carol@guyub.test");
  });

  it("registers an attendee and issues a secret QR token", async () => {
    const response = await register(alice, "m3-open");
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.deepEqual(response.body.result, { status: "registered", attendanceId: `m3-open_${alice.uid}` });

    const ticket = await getDoc(`attendance/m3-open_${alice.uid}`);
    assert.match(ticket.qr_token.stringValue, /^[A-Za-z0-9_-]{22}$/);
    assert.equal(ticket.privacy_consent.booleanValue, true);
    assert.ok(ticket.consent_at.timestampValue);
    assert.equal(ticket.is_checked_in.booleanValue, false);
    assert.equal(ticket.attendee_email.stringValue, alice.email);
    assert.equal(await count("m3-open"), 1);
  });

  it("registering twice returns the same ticket and does not double count", async () => {
    const before = (await getDoc(`attendance/m3-open_${alice.uid}`)).qr_token.stringValue;
    const response = await register(alice, "m3-open");
    assert.equal(response.body.result.status, "existing");
    assert.equal((await getDoc(`attendance/m3-open_${alice.uid}`)).qr_token.stringValue, before);
    assert.equal(await count("m3-open"), 1);
  });

  it("requires privacy consent", async () => {
    assert.equal(errorStatus(await register(bob, "m3-open", false)), "INVALID_ARGUMENT");
  });

  it("refuses closed registration, drafts, and unknown events", async () => {
    assert.equal(errorStatus(await register(bob, "m3-closed")), "FAILED_PRECONDITION");
    assert.equal(errorStatus(await register(bob, "m3-draft")), "FAILED_PRECONDITION");
    assert.equal(errorStatus(await register(bob, "m3-nope")), "FAILED_PRECONDITION");
  });

  it("enforces capacity", async () => {
    assert.equal((await register(bob, "m3-open")).body.result.status, "registered");
    const full = await register(carol, "m3-open");
    assert.equal(errorStatus(full), "FAILED_PRECONDITION");
    assert.match(full.body.error.message, /full/);
    assert.equal(await count("m3-open"), 2);
  });

  it("only attendee accounts register", async () => {
    const organizer = await signIn("m3-organizer@guyub.test");
    await setClaimsAsOwner(organizer.uid, { role: "organizer", orgId: "m3-org" });
    const refreshed = await signIn(organizer.email);
    assert.equal(errorStatus(await register(refreshed, "m3-closed")), "PERMISSION_DENIED");
  });

  it("cancelling frees the spot for someone else", async () => {
    const response = await call("cancelRegistration", alice.token, { eventId: "m3-open" });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.equal(await getDoc(`attendance/m3-open_${alice.uid}`), null);
    assert.equal(await count("m3-open"), 1);

    assert.equal((await register(carol, "m3-open")).body.result.status, "registered");
    assert.equal(await count("m3-open"), 2);
  });

  it("cannot cancel after check-in or without a registration", async () => {
    await patchDoc(`attendance/m3-open_${bob.uid}`, { is_checked_in: true });
    assert.equal(errorStatus(await call("cancelRegistration", bob.token, { eventId: "m3-open" })), "FAILED_PRECONDITION");
    assert.equal(errorStatus(await call("cancelRegistration", alice.token, { eventId: "m3-open" })), "FAILED_PRECONDITION");
    assert.equal(await count("m3-open"), 2);
  });
});
