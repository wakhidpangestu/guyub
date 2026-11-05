import assert from "node:assert/strict";
import { describe, it } from "node:test";
import checkin from "../lib/checkin.js";
import members from "../lib/members.js";
import claims from "../lib/claims.js";

const { parseCheckInRequest, authorizeCheckIn, classifyScan, decideCheckIn } = checkin;
const { PermissionError } = members;
const { RoleInputError } = claims;

const organizer = { role: "organizer", orgId: "himatif" } as const;
const committee = { role: "committee", orgId: "himatif" } as const;

describe("parseCheckInRequest", () => {
  it("accepts a scanned code or an attendance ID, not both", () => {
    assert.deepEqual(parseCheckInRequest({ eventId: "e", payload: "G1.x" }), { eventId: "e", mode: "scan", payload: "G1.x" });
    assert.deepEqual(parseCheckInRequest({ eventId: "e", attendanceId: "e_u" }), { eventId: "e", mode: "manual", attendanceId: "e_u" });
    assert.throws(() => parseCheckInRequest({ eventId: "e", payload: "G1.x", attendanceId: "e_u" }), RoleInputError);
    assert.throws(() => parseCheckInRequest({ eventId: "e" }), RoleInputError);
    assert.throws(() => parseCheckInRequest({ payload: "G1.x" }), RoleInputError);
    assert.throws(() => parseCheckInRequest({ eventId: "e", payload: "x".repeat(301) }), RoleInputError);
  });
});

describe("authorizeCheckIn", () => {
  it("assigned committee may scan, not check in manually", () => {
    assert.doesNotThrow(() => authorizeCheckIn(committee, "himatif", true, false));
    assert.throws(() => authorizeCheckIn(committee, "himatif", true, true), PermissionError);
  });

  it("unassigned committee may not check in, even in the same org", () => {
    assert.throws(() => authorizeCheckIn(committee, "himatif", false, false), PermissionError);
  });

  it("organizer of the event's org may scan or check in manually", () => {
    assert.doesNotThrow(() => authorizeCheckIn(organizer, "himatif", false, false));
    assert.doesNotThrow(() => authorizeCheckIn(organizer, "himatif", false, true));
    assert.throws(() => authorizeCheckIn(organizer, "bem", false, true), PermissionError);
  });

  it("attendees and admins do not check people in", () => {
    assert.throws(() => authorizeCheckIn({ role: "attendee" }, "himatif", false, false), PermissionError);
    assert.throws(() => authorizeCheckIn({ role: "admin" }, "himatif", false, false), PermissionError);
  });

  it("a missing event is bad input", () => {
    assert.throws(() => authorizeCheckIn(organizer, null, false, false), RoleInputError);
  });
});

describe("classifyScan", () => {
  it("rejects non-Guyub codes and tickets for other events before any read", () => {
    assert.deepEqual(classifyScan("talk", null), { result: "invalid" });
    assert.deepEqual(classifyScan("talk", { attendanceId: "summit_u1", window: 1, signature: "0".repeat(16) }), { result: "wrong_event" });
    assert.deepEqual(classifyScan("talk", { attendanceId: "talk_u1", window: 1, signature: "0".repeat(16) }), { attendanceId: "talk_u1" });
  });
});

describe("decideCheckIn", () => {
  const fresh = { eventId: "talk", isCheckedIn: false };
  const inside = { eventId: "talk", isCheckedIn: true };

  it("checks in a valid ticket once", () => {
    assert.equal(decideCheckIn("active", fresh, "talk", "valid"), "checked_in");
    assert.equal(decideCheckIn("active", inside, "talk", "valid"), "already_checked_in");
  });

  it("manual check-in skips the code check only", () => {
    assert.equal(decideCheckIn("active", fresh, "talk", "manual"), "checked_in");
    assert.equal(decideCheckIn("active", null, "talk", "manual"), "not_registered");
  });

  it("refuses expired and invalid codes, even for someone already inside", () => {
    assert.equal(decideCheckIn("active", fresh, "talk", "expired"), "expired");
    assert.equal(decideCheckIn("active", inside, "talk", "expired"), "expired");
    assert.equal(decideCheckIn("active", fresh, "talk", "invalid"), "invalid");
  });

  it("closed events, cancelled tickets, and other events' tickets", () => {
    assert.equal(decideCheckIn("completed", fresh, "talk", "valid"), "closed");
    assert.equal(decideCheckIn("draft", fresh, "talk", "valid"), "closed");
    assert.equal(decideCheckIn("active", null, "talk", "valid"), "not_registered");
    assert.equal(decideCheckIn("active", { eventId: "summit", isCheckedIn: false }, "talk", "manual"), "wrong_event");
  });
});
