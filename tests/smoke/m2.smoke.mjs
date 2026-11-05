// M2 end-to-end smoke test: adding people to organizations by email.
// Run with: npm run test:smoke
//
// Covers inviteMember (existing account and not-yet-registered email),
// invite pickup at first sign-in, cross-org protection, and removeMember.

import assert from "node:assert/strict";
import { before, describe, it } from "node:test";

import {
  call,
  claimsOf,
  errorStatus,
  getDoc,
  putDoc,
  setClaimsAsOwner,
  signIn,
  waitForDoc,
  waitForGone,
} from "./support.mjs";

describe("M2 members and invites", () => {
  let admin;
  let organizer;
  let otherOrganizer;

  before(async () => {
    await putDoc("organizations/m2-himatif", { name: "HIMATIF", slug: "m2-himatif", status: "active" });
    await putDoc("organizations/m2-bem", { name: "BEM", slug: "m2-bem", status: "active" });

    admin = await signIn("m2-admin@guyub.test");
    await setClaimsAsOwner(admin.uid, { role: "admin" });
    admin = await signIn(admin.email);

    organizer = await signIn("m2-organizer@guyub.test");
    otherOrganizer = await signIn("m2-other-organizer@guyub.test");
    await waitForDoc(`users/${organizer.uid}`);
    await waitForDoc(`users/${otherOrganizer.uid}`);
  });

  it("admin makes an existing account an organizer", async () => {
    const response = await call("inviteMember", admin.token, { email: organizer.email, role: "organizer", orgId: "m2-himatif" });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.equal(response.body.result.status, "granted");

    organizer = await signIn(organizer.email);
    assert.equal(claimsOf(organizer.token).role, "organizer");
    assert.equal(claimsOf(organizer.token).orgId, "m2-himatif");

    await call("inviteMember", admin.token, { email: otherOrganizer.email, role: "organizer", orgId: "m2-bem" });
    otherOrganizer = await signIn(otherOrganizer.email);
  });

  it("organizer adds an existing attendee as committee (email is case-insensitive)", async () => {
    const member = await signIn("m2-committee@guyub.test");
    await waitForDoc(`users/${member.uid}`);

    const response = await call("inviteMember", organizer.token, {
      email: "  M2-Committee@Guyub.test ",
      role: "committee",
      orgId: "m2-himatif",
    });
    assert.equal(response.body.result.status, "granted");

    const fields = await waitForDoc(`users/${member.uid}`, (f) => f.role?.stringValue === "committee");
    assert.equal(fields.organization_id.stringValue, "m2-himatif");
  });

  it("invite for an email with no account is applied at first sign-in", async () => {
    const email = "m2-newcomer@guyub.test";
    const response = await call("inviteMember", organizer.token, { email, role: "committee", orgId: "m2-himatif" });
    assert.equal(response.body.result.status, "invited");
    assert.ok(await getDoc(`invites/${email}`), "invite stored");

    const newcomer = await signIn(email);
    await waitForDoc(`users/${newcomer.uid}`, (f) => f.role?.stringValue === "committee");
    await waitForGone(`invites/${email}`);

    const refreshed = await signIn(email);
    assert.equal(claimsOf(refreshed.token).role, "committee");
    assert.equal(claimsOf(refreshed.token).orgId, "m2-himatif");
  });

  it("another org cannot claim an email with a pending invite", async () => {
    const email = "m2-contested@guyub.test";
    await call("inviteMember", organizer.token, { email, role: "committee", orgId: "m2-himatif" });
    const response = await call("inviteMember", otherOrganizer.token, { email, role: "committee", orgId: "m2-bem" });
    assert.equal(errorStatus(response), "FAILED_PRECONDITION");
  });

  it("organizer cannot add to another org, create organizers, or change an admin", async () => {
    const otherOrg = await call("inviteMember", organizer.token, { email: "x@guyub.test", role: "committee", orgId: "m2-bem" });
    assert.equal(errorStatus(otherOrg), "PERMISSION_DENIED");

    const makeOrganizer = await call("inviteMember", organizer.token, { email: "x@guyub.test", role: "organizer", orgId: "m2-himatif" });
    assert.equal(errorStatus(makeOrganizer), "PERMISSION_DENIED");

    const changeAdmin = await call("inviteMember", organizer.token, { email: admin.email, role: "committee", orgId: "m2-himatif" });
    assert.equal(errorStatus(changeAdmin), "FAILED_PRECONDITION");
  });

  it("a member of one org cannot be pulled into another", async () => {
    const response = await call("inviteMember", otherOrganizer.token, {
      email: "m2-committee@guyub.test",
      role: "committee",
      orgId: "m2-bem",
    });
    assert.equal(errorStatus(response), "FAILED_PRECONDITION");
  });

  it("attendees cannot invite", async () => {
    const attendee = await signIn("m2-attendee@guyub.test");
    const response = await call("inviteMember", attendee.token, { email: "y@guyub.test", role: "committee", orgId: "m2-himatif" });
    assert.equal(errorStatus(response), "PERMISSION_DENIED");
  });

  it("removing a committee member resets the role and deletes assignments", async () => {
    const member = await signIn("m2-committee@guyub.test");
    await putDoc(`events/m2-evt/committees/${member.uid}`, { uid: member.uid, organization_id: "m2-himatif" });

    const denied = await call("removeMember", otherOrganizer.token, { uid: member.uid });
    assert.equal(errorStatus(denied), "PERMISSION_DENIED");

    const response = await call("removeMember", organizer.token, { uid: member.uid });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.equal(response.body.result.removedAssignments, 1);

    assert.equal(await getDoc(`events/m2-evt/committees/${member.uid}`), null);
    const refreshed = await signIn(member.email);
    assert.equal(claimsOf(refreshed.token).role, "attendee");
    assert.equal(claimsOf(refreshed.token).orgId, undefined);
  });
});
