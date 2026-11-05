import assert from "node:assert/strict";
import { describe, it } from "node:test";
import members from "../lib/members.js";
import claims from "../lib/claims.js";

const { decideInvite, decideRemove, parseInviteRequest, normalizeEmail, PermissionError, ConflictError } = members;
const { RoleInputError } = claims;

const admin = { role: "admin" } as const;
const organizer = { role: "organizer", orgId: "himatif" } as const;
const committee = { role: "committee", orgId: "himatif" } as const;
const attendee = { role: "attendee" } as const;

const toCommittee = { email: "a@b.co", role: "committee", orgId: "himatif" } as const;
const toOrganizer = { email: "a@b.co", role: "organizer", orgId: "himatif" } as const;

describe("parseInviteRequest", () => {
  it("normalizes the email", () => {
    assert.equal(normalizeEmail("  Rina@Example.COM "), "rina@example.com");
  });

  it("rejects bad email, role, and org", () => {
    assert.throws(() => parseInviteRequest({ email: "nope", role: "committee", orgId: "o" }), RoleInputError);
    assert.throws(() => parseInviteRequest({ email: "a@b.co", role: "admin", orgId: "o" }), RoleInputError);
    assert.throws(() => parseInviteRequest({ email: "a@b.co", role: "committee" }), RoleInputError);
    assert.throws(() => parseInviteRequest(null), RoleInputError);
  });
});

describe("decideInvite: who may invite", () => {
  it("admin invites organizer or committee to any org", () => {
    assert.equal(decideInvite(admin, toOrganizer, null), "invite");
    assert.equal(decideInvite(admin, { ...toCommittee, orgId: "bem" }, null), "invite");
  });

  it("organizer invites committee to own org only", () => {
    assert.equal(decideInvite(organizer, toCommittee, null), "invite");
    assert.throws(() => decideInvite(organizer, { ...toCommittee, orgId: "bem" }, null), PermissionError);
  });

  it("organizer cannot create organizers", () => {
    assert.throws(() => decideInvite(organizer, toOrganizer, null), PermissionError);
  });

  it("committee and attendee cannot invite", () => {
    assert.throws(() => decideInvite(committee, toCommittee, null), PermissionError);
    assert.throws(() => decideInvite(attendee, toCommittee, null), PermissionError);
  });
});

describe("decideInvite: who may be changed", () => {
  it("grants an existing attendee", () => {
    assert.equal(decideInvite(organizer, toCommittee, attendee), "grant");
  });

  it("re-inviting a member of the same org is a harmless grant", () => {
    assert.equal(decideInvite(organizer, toCommittee, committee), "grant");
  });

  it("admin promotes committee to organizer in the same org", () => {
    assert.equal(decideInvite(admin, toOrganizer, committee), "grant");
  });

  it("never changes an admin", () => {
    assert.throws(() => decideInvite(admin, toOrganizer, admin), ConflictError);
  });

  it("refuses to take a member from another org", () => {
    assert.throws(() => decideInvite(admin, toOrganizer, { role: "committee", orgId: "bem" }), ConflictError);
    assert.throws(() => decideInvite(organizer, toCommittee, { role: "committee", orgId: "bem" }), ConflictError);
  });

  it("organizer cannot demote a fellow organizer", () => {
    assert.throws(() => decideInvite(organizer, toCommittee, organizer), ConflictError);
  });
});

describe("decideRemove", () => {
  it("organizer removes own org's committee", () => {
    assert.doesNotThrow(() => decideRemove(organizer, committee));
  });

  it("organizer cannot remove other org's committee or an organizer", () => {
    assert.throws(() => decideRemove(organizer, { role: "committee", orgId: "bem" }), PermissionError);
    assert.throws(() => decideRemove(organizer, { role: "organizer", orgId: "himatif" }), PermissionError);
  });

  it("admin removes organizers and committee anywhere", () => {
    assert.doesNotThrow(() => decideRemove(admin, organizer));
    assert.doesNotThrow(() => decideRemove(admin, { role: "committee", orgId: "bem" }));
  });

  it("admins and attendees are not removable", () => {
    assert.throws(() => decideRemove(admin, admin), ConflictError);
    assert.throws(() => decideRemove(admin, attendee), ConflictError);
  });

  it("committee cannot remove anyone", () => {
    assert.throws(() => decideRemove(committee, { role: "committee", orgId: "himatif" }), PermissionError);
  });
});
