import assert from "node:assert/strict";
import { describe, it } from "node:test";
import claims from "../lib/claims.js";

const { validateRoleInput, applyRole, RoleInputError } = claims;

describe("validateRoleInput", () => {
  it("accepts attendee and admin without orgId", () => {
    assert.deepEqual(validateRoleInput({ uid: "u1", role: "attendee" }), { uid: "u1", role: "attendee" });
    assert.deepEqual(validateRoleInput({ uid: "u1", role: "admin" }), { uid: "u1", role: "admin" });
  });

  it("drops orgId for admin and attendee", () => {
    assert.deepEqual(validateRoleInput({ uid: "u1", role: "admin", orgId: "o1" }), { uid: "u1", role: "admin" });
  });

  it("requires orgId for organizer and committee", () => {
    assert.throws(() => validateRoleInput({ uid: "u1", role: "organizer" }), RoleInputError);
    assert.throws(() => validateRoleInput({ uid: "u1", role: "committee", orgId: "" }), RoleInputError);
    assert.deepEqual(validateRoleInput({ uid: "u1", role: "committee", orgId: "o1" }), {
      uid: "u1",
      role: "committee",
      orgId: "o1",
    });
  });

  it("rejects unknown roles and missing uid", () => {
    assert.throws(() => validateRoleInput({ uid: "u1", role: "superuser" as never }), RoleInputError);
    assert.throws(() => validateRoleInput({ role: "admin" }), RoleInputError);
  });
});

/** Minimal fakes for the two Admin SDK calls applyRole makes. */
function fakes(existingOrgs: string[] = []) {
  const claimsSet: Array<[string, object]> = [];
  const docsSet: Array<[string, Record<string, unknown>]> = [];
  const auth = {
    setCustomUserClaims: async (uid: string, value: object) => {
      claimsSet.push([uid, value]);
    },
  };
  const db = {
    collection: (name: string) => ({
      doc: (id: string) => ({
        get: async () => ({ exists: name === "organizations" && existingOrgs.includes(id) }),
        set: async (data: Record<string, unknown>) => {
          docsSet.push([`${name}/${id}`, data]);
        },
      }),
    }),
  };
  return { auth: auth as never, db: db as never, claimsSet, docsSet };
}

describe("applyRole", () => {
  it("sets claims and mirrors them to users/{uid}", async () => {
    const f = fakes(["o1"]);
    await applyRole(f, { uid: "u1", role: "organizer", orgId: "o1" });
    assert.deepEqual(f.claimsSet, [["u1", { role: "organizer", orgId: "o1" }]]);
    assert.equal(f.docsSet[0][0], "users/u1");
    assert.equal(f.docsSet[0][1].role, "organizer");
    assert.equal(f.docsSet[0][1].organization_id, "o1");
    assert.ok("updated_at" in f.docsSet[0][1]);
  });

  it("refuses an organization that does not exist", async () => {
    const f = fakes([]);
    await assert.rejects(applyRole(f, { uid: "u1", role: "committee", orgId: "ghost" }), RoleInputError);
    assert.equal(f.claimsSet.length, 0);
  });

  it("writes null organization for attendee", async () => {
    const f = fakes();
    await applyRole(f, { uid: "u2", role: "attendee" });
    assert.deepEqual(f.claimsSet, [["u2", { role: "attendee" }]]);
    assert.equal(f.docsSet[0][1].organization_id, null);
  });
});
