// Retention purge smoke test (audit H3).
// Run with: npm run test:smoke
//
// The privacy notice promises that attendance records are deleted 12 months
// after the event. runRetentionPurge runs the same code as the daily
// scheduled function.

import assert from "node:assert/strict";
import { before, describe, it } from "node:test";

import { call, errorStatus, getDoc, putDoc, setClaimsAsOwner, signIn } from "./support.mjs";

const DAY = 24 * 60 * 60 * 1000;

describe("retention purge", () => {
  let admin;

  before(async () => {
    const base = { organization_id: "ret-org", title: "Event", created_by: "x", status: "completed", registration_open: false };
    await putDoc("events/ret-old", { ...base, date: new Date(Date.now() - 400 * DAY) });
    await putDoc("events/ret-recent", { ...base, date: new Date(Date.now() - 30 * DAY) });
    for (const [eventId, uid] of [["ret-old", "a"], ["ret-old", "b"], ["ret-recent", "c"]]) {
      await putDoc(`attendance/${eventId}_${uid}`, { event_id: eventId, user_id: uid, organization_id: "ret-org", attendee_name: uid });
      await putDoc(`attendance_secrets/${eventId}_${uid}`, { event_id: eventId, user_id: uid, qr_token: "t" });
    }
    admin = await signIn("ret-admin@guyub.test");
    await setClaimsAsOwner(admin.uid, { role: "admin" });
    admin = await signIn(admin.email);
  });

  it("only admins can run it on demand", async () => {
    const attendee = await signIn("ret-attendee@guyub.test");
    assert.equal(errorStatus(await call("runRetentionPurge", attendee.token, {})), "PERMISSION_DENIED");
  });

  it("deletes attendance and secrets older than 12 months, keeps recent ones and the events", async () => {
    const response = await call("runRetentionPurge", admin.token, {});
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.ok(response.body.result.deleted >= 2);

    assert.equal(await getDoc("attendance/ret-old_a"), null);
    assert.equal(await getDoc("attendance/ret-old_b"), null);
    assert.equal(await getDoc("attendance_secrets/ret-old_a"), null);
    assert.ok(await getDoc("attendance/ret-recent_c"), "recent attendance kept");
    assert.ok(await getDoc("attendance_secrets/ret-recent_c"), "recent secret kept");
    assert.ok(await getDoc("events/ret-old"), "the event itself stays");
  });

  it("is safe to run again", async () => {
    const response = await call("runRetentionPurge", admin.token, {});
    assert.equal(response.status, 200);
    assert.ok(await getDoc("attendance/ret-recent_c"));
  });
});
