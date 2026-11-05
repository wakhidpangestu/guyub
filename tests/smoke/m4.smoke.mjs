// M4 end-to-end smoke test: check-in with the rotating QR.
// Run with: npm run test:smoke
//
// Codes are produced with the same tickets module the ticket screen mirrors,
// from the key the attendee can read. Covers valid, repeated, expired,
// forged, wrong-event, cancelled, and closed cases, who may check in, manual
// check-in, and two doors scanning the same ticket at once.

import assert from "node:assert/strict";
import { before, describe, it } from "node:test";
import tickets from "../../functions/lib/tickets.js";

import { call, errorStatus, getDoc, putDoc, setClaimsAsOwner, signIn } from "./support.mjs";

const register = (who, eventId) => call("registerForEvent", who.token, { eventId, privacyConsent: true });
const scan = (who, eventId, payload) => call("checkIn", who.token, { eventId, payload });
const manual = (who, eventId, attendanceId) => call("checkIn", who.token, { eventId, attendanceId });

/** The code the attendee's screen shows now (or `windowOffset` windows away). */
async function codeFor(eventId, attendee, windowOffset = 0) {
  const attendanceId = `${eventId}_${attendee.uid}`;
  const secret = await getDoc(`attendance_secrets/${attendanceId}`);
  const window = tickets.windowAt(Date.now() / 1000) + windowOffset;
  return tickets.ticketPayload(secret.qr_token.stringValue, attendanceId, window);
}

async function withClaims(email, claims) {
  const user = await signIn(email);
  await setClaimsAsOwner(user.uid, claims);
  return signIn(email);
}

describe("M4 check-in", () => {
  let organizer;
  let door;
  let unassigned;
  const people = {};

  before(async () => {
    await putDoc("organizations/m4-org", { name: "M4 Org", slug: "m4-org", status: "active" });
    const base = { organization_id: "m4-org", title: "Event", created_by: "x", registered_count: 0, capacity: null };
    await putDoc("events/m4-talk", { ...base, status: "active", registration_open: true });
    await putDoc("events/m4-other", { ...base, status: "active", registration_open: true });
    await putDoc("events/m4-done", { ...base, status: "active", registration_open: true });

    organizer = await withClaims("m4-organizer@guyub.test", { role: "organizer", orgId: "m4-org" });
    door = await withClaims("m4-door@guyub.test", { role: "committee", orgId: "m4-org" });
    unassigned = await withClaims("m4-idle@guyub.test", { role: "committee", orgId: "m4-org" });
    await putDoc(`events/m4-talk/committees/${door.uid}`, { uid: door.uid, organization_id: "m4-org" });

    for (const name of ["alice", "bob", "carol", "dave", "erin", "fay"]) {
      people[name] = await signIn(`m4-${name}@guyub.test`);
    }
    for (const name of ["alice", "bob", "dave", "erin"]) {
      assert.equal((await register(people[name], "m4-talk")).body.result.status, "registered");
    }
    await register(people.carol, "m4-other");
    await register(people.fay, "m4-done");
    await putDoc("events/m4-done", { ...base, status: "completed", registration_open: false, registered_count: 1 });
  });

  it("assigned committee scans a valid code: checked in, by them, by scan", async () => {
    const response = await scan(door, "m4-talk", await codeFor("m4-talk", people.alice));
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.equal(response.body.result.result, "checked_in");
    assert.equal(response.body.result.attendeeName, "m4-alice");

    const record = await getDoc(`attendance/m4-talk_${people.alice.uid}`);
    assert.equal(record.is_checked_in.booleanValue, true);
    assert.equal(record.checked_in_by.stringValue, door.uid);
    assert.equal(record.check_in_method.stringValue, "scan");
    assert.ok(record.checked_in_at.timestampValue);
  });

  it("scanning again says already checked in, with the time", async () => {
    const response = await scan(door, "m4-talk", await codeFor("m4-talk", people.alice));
    assert.equal(response.body.result.result, "already_checked_in");
    assert.ok(response.body.result.checkedInAt);
  });

  it("an old code (screenshot) is expired and checks nobody in", async () => {
    const response = await scan(door, "m4-talk", await codeFor("m4-talk", people.bob, -5));
    assert.equal(response.body.result.result, "expired");
    assert.equal((await getDoc(`attendance/m4-talk_${people.bob.uid}`)).is_checked_in.booleanValue, false);
  });

  it("a forged or foreign code is invalid", async () => {
    const real = await codeFor("m4-talk", people.bob);
    const forged = real.slice(0, -16) + "0123456789abcdef";
    assert.equal((await scan(door, "m4-talk", forged)).body.result.result, "invalid");
    assert.equal((await scan(door, "m4-talk", "https://example.com/not-a-ticket")).body.result.result, "invalid");
  });

  it("a ticket for another event is refused without revealing who it is", async () => {
    const response = await scan(door, "m4-talk", await codeFor("m4-other", people.carol));
    assert.equal(response.body.result.result, "wrong_event");
    assert.equal(response.body.result.attendeeName, null);
  });

  it("a cancelled ticket is not registered", async () => {
    const oldCode = await codeFor("m4-talk", people.dave);
    await call("cancelRegistration", people.dave.token, { eventId: "m4-talk" });
    assert.equal((await scan(door, "m4-talk", oldCode)).body.result.result, "not_registered");
  });

  it("only assigned committee and the org's organizers may check in", async () => {
    const code = await codeFor("m4-talk", people.bob);
    assert.equal(errorStatus(await scan(unassigned, "m4-talk", code)), "PERMISSION_DENIED");
    assert.equal(errorStatus(await scan(people.erin, "m4-talk", code)), "PERMISSION_DENIED");
    assert.equal((await getDoc(`attendance/m4-talk_${people.bob.uid}`)).is_checked_in.booleanValue, false);
  });

  it("committee must scan; only organizers check in manually", async () => {
    const attendanceId = `m4-talk_${people.bob.uid}`;
    assert.equal(errorStatus(await manual(door, "m4-talk", attendanceId)), "PERMISSION_DENIED");

    const response = await manual(organizer, "m4-talk", attendanceId);
    assert.equal(response.body.result.result, "checked_in");
    assert.equal((await getDoc(`attendance/${attendanceId}`)).check_in_method.stringValue, "manual");
  });

  it("a completed event is closed for check-in", async () => {
    const response = await manual(organizer, "m4-done", `m4-done_${people.fay.uid}`);
    assert.equal(response.body.result.result, "closed");
  });

  it("two doors scanning the same ticket at once record one check-in", async () => {
    const code = await codeFor("m4-talk", people.erin);
    const [a, b] = await Promise.all([scan(door, "m4-talk", code), scan(organizer, "m4-talk", code)]);
    const results = [a.body.result.result, b.body.result.result].sort();
    assert.deepEqual(results, ["already_checked_in", "checked_in"]);
  });
});
