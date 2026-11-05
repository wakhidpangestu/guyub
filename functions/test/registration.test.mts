import assert from "node:assert/strict";
import { describe, it } from "node:test";
import registration from "../lib/registration.js";
import tickets from "../lib/tickets.js";
import members from "../lib/members.js";
import claims from "../lib/claims.js";

const { decideRegistration, decideCancellation, parseRegistrationRequest, attendanceIdFor } = registration;
const { ticketPayload, ticketSignature, parseTicketPayload, verifyTicket, windowAt, newQrToken, WINDOW_SECONDS } = tickets;
const { PermissionError, ConflictError } = members;
const { RoleInputError } = claims;

const attendee = { role: "attendee" } as const;
const open = { status: "active", registrationOpen: true, capacity: null, registeredCount: 0 };

describe("parseRegistrationRequest", () => {
  it("requires an event and explicit consent", () => {
    assert.deepEqual(parseRegistrationRequest({ eventId: "e1", privacyConsent: true }), { eventId: "e1" });
    assert.throws(() => parseRegistrationRequest({ eventId: "e1" }), RoleInputError);
    assert.throws(() => parseRegistrationRequest({ eventId: "e1", privacyConsent: "yes" }), RoleInputError);
    assert.throws(() => parseRegistrationRequest({ privacyConsent: true }), RoleInputError);
  });

  it("attendance ID is eventId_uid", () => {
    assert.equal(attendanceIdFor("evt", "u1"), "evt_u1");
  });
});

describe("decideRegistration", () => {
  it("registers an attendee for an open event", () => {
    assert.equal(decideRegistration(attendee, open, false), "register");
  });

  it("is idempotent for an existing registration", () => {
    assert.equal(decideRegistration(attendee, { ...open, registrationOpen: false }, true), "existing");
  });

  it("only attendees register", () => {
    assert.throws(() => decideRegistration({ role: "committee", orgId: "o" }, open, false), PermissionError);
    assert.throws(() => decideRegistration({ role: "organizer", orgId: "o" }, open, false), PermissionError);
  });

  it("refuses missing, unpublished, or closed events", () => {
    assert.throws(() => decideRegistration(attendee, null, false), ConflictError);
    assert.throws(() => decideRegistration(attendee, { ...open, status: "draft" }, false), ConflictError);
    assert.throws(() => decideRegistration(attendee, { ...open, status: "completed" }, false), ConflictError);
    assert.throws(() => decideRegistration(attendee, { ...open, registrationOpen: false }, false), ConflictError);
  });

  it("enforces capacity", () => {
    assert.equal(decideRegistration(attendee, { ...open, capacity: 2, registeredCount: 1 }, false), "register");
    assert.throws(() => decideRegistration(attendee, { ...open, capacity: 2, registeredCount: 2 }, false), /full/);
  });
});

describe("decideCancellation", () => {
  it("allows cancelling before check-in", () => {
    assert.doesNotThrow(() => decideCancellation({ isCheckedIn: false }, "active"));
  });

  it("refuses after check-in, for completed events, or without a registration", () => {
    assert.throws(() => decideCancellation({ isCheckedIn: true }, "active"), ConflictError);
    assert.throws(() => decideCancellation({ isCheckedIn: false }, "completed"), ConflictError);
    assert.throws(() => decideCancellation(null, "active"), ConflictError);
  });
});

describe("dynamic QR tickets", () => {
  // Shared with apps/dashboard/test/data/ticket_code_test.dart. Change both together.
  const VECTOR = { token: "test-token-123", attendanceId: "evt_u1", window: 59000000, signature: "" };
  VECTOR.signature = ticketSignature(VECTOR.token, VECTOR.attendanceId, VECTOR.window);

  it("matches the shared test vector", () => {
    assert.equal(VECTOR.signature, "dd5bbd670685b044");
    assert.equal(ticketPayload(VECTOR.token, VECTOR.attendanceId, VECTOR.window), `G1.evt_u1.59000000.${VECTOR.signature}`);
  });

  it("round-trips through parse and verify", () => {
    const token = newQrToken();
    const now = 1_770_000_000;
    const parsed = parseTicketPayload(ticketPayload(token, "demo-tech-talk_abc", windowAt(now)));
    assert.deepEqual(parsed?.attendanceId, "demo-tech-talk_abc");
    assert.equal(verifyTicket(parsed!, token, now), "valid");
  });

  it("accepts small clock drift and rejects old screenshots", () => {
    const token = newQrToken();
    const now = 1_770_000_000;
    const at = (offsetWindows: number) => parseTicketPayload(ticketPayload(token, "e_u", windowAt(now) + offsetWindows))!;
    assert.equal(verifyTicket(at(-2), token, now), "valid");
    assert.equal(verifyTicket(at(2), token, now), "valid");
    assert.equal(verifyTicket(at(-3), token, now), "expired");
    assert.equal(verifyTicket(at(3), token, now + 3 * WINDOW_SECONDS), "valid");
  });

  it("rejects a forged or mismatched signature", () => {
    const now = 1_770_000_000;
    const real = parseTicketPayload(ticketPayload(newQrToken(), "e_u", windowAt(now)))!;
    assert.equal(verifyTicket(real, newQrToken(), now), "invalid");
    assert.equal(verifyTicket({ ...real, attendanceId: "e_other" }, "x", now), "invalid");
  });

  it("rejects malformed payloads", () => {
    for (const bad of ["", "G2.e_u.1.0123456789abcdef", "G1.e_u.x.0123456789abcdef", "G1.e_u.1.short", "G1..1"]) {
      assert.equal(parseTicketPayload(bad), null, bad);
    }
  });

  it("new tokens are unique and URL-safe", () => {
    const a = newQrToken();
    assert.match(a, /^[A-Za-z0-9_-]{22}$/);
    assert.notEqual(a, newQrToken());
  });
});

describe("retention", async () => {
  const retention = (await import("../lib/retention.js")).default;

  it("cutoff is 365 days before now", () => {
    const now = new Date("2027-12-01T00:00:00Z");
    assert.equal(retention.retentionCutoff(now).toISOString(), "2026-12-01T00:00:00.000Z");
    assert.equal(retention.RETENTION_DAYS, 365);
  });
});
