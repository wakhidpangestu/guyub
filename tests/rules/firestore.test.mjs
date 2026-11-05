import { after, before, beforeEach, describe, it } from "node:test";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc } from "firebase/firestore";

import { as, attendance, createEnv, seed } from "./helpers.mjs";

let env;
const db = (persona) => persona(env).firestore();

before(async () => {
  env = await createEnv();
});

beforeEach(async () => {
  await env.clearFirestore();
  await seed(env);
});

after(async () => {
  await env.cleanup();
});

describe("users", () => {
  it("a user reads own profile", async () => {
    await assertSucceeds(getDoc(doc(db(as.attendee), "users/att1")));
  });

  it("a user cannot read another profile", async () => {
    await assertFails(getDoc(doc(db(as.otherAttendee), "users/att1")));
  });

  it("admin reads any profile", async () => {
    await assertSucceeds(getDoc(doc(db(as.admin), "users/att1")));
  });

  it("nobody promotes themselves from the client", async () => {
    await assertFails(setDoc(doc(db(as.attendee), "users/att1"), { role: "admin" }));
    await assertFails(setDoc(doc(db(as.admin), "users/att1"), { role: "admin" }));
  });
});

describe("organizations", () => {
  it("organizer reads own org only", async () => {
    await assertSucceeds(getDoc(doc(db(as.organizer), "organizations/himatif")));
    await assertFails(getDoc(doc(db(as.organizer), "organizations/bem")));
  });

  it("only admin creates organizations", async () => {
    await assertSucceeds(setDoc(doc(db(as.admin), "organizations/new"), { name: "New" }));
    await assertFails(setDoc(doc(db(as.organizer), "organizations/new2"), { name: "New" }));
  });
});

describe("events", () => {
  it("signed-in attendee without a role claim browses active events", async () => {
    await assertSucceeds(getDoc(doc(db(as.attendee), "events/evtA")));
  });

  it("anonymous visitors cannot read events", async () => {
    await assertFails(getDoc(doc(db(as.anonymous), "events/evtA")));
  });

  it("drafts are visible only to the org's organizers", async () => {
    await assertFails(getDoc(doc(db(as.attendee), "events/evtDraft")));
    await assertSucceeds(getDoc(doc(db(as.organizer), "events/evtDraft")));
    await assertFails(getDoc(doc(db(as.otherOrganizer), "events/evtDraft")));
    // Same org, but committee scope is per event.
    await assertFails(getDoc(doc(db(as.unassignedCommittee), "events/evtDraft")));
  });

  it("organizer creates events only in own org", async () => {
    await assertSucceeds(setDoc(doc(db(as.organizer), "events/evtNew"), { organization_id: "himatif", status: "draft" }));
    await assertFails(setDoc(doc(db(as.organizer), "events/evtNew2"), { organization_id: "bem", status: "draft" }));
    await assertFails(setDoc(doc(db(as.attendee), "events/evtNew3"), { organization_id: "himatif", status: "draft" }));
  });

  it("organizer cannot edit another org's event or move an event to another org", async () => {
    await assertSucceeds(updateDoc(doc(db(as.organizer), "events/evtA"), { title: "Renamed" }));
    await assertFails(updateDoc(doc(db(as.organizer), "events/evtA"), { organization_id: "bem" }));
    await assertFails(updateDoc(doc(db(as.otherOrganizer), "events/evtA"), { title: "Hijacked" }));
  });
});

describe("committee assignment", () => {
  it("organizer assigns committee to own org's event", async () => {
    await assertSucceeds(
      setDoc(doc(db(as.organizer), "events/evtA/committees/comB"), { organization_id: "himatif", assigned_by: "org1" }),
    );
  });

  it("other org's organizer cannot assign", async () => {
    await assertFails(
      setDoc(doc(db(as.otherOrganizer), "events/evtA/committees/comX"), { organization_id: "bem", assigned_by: "org2" }),
    );
  });

  it("committee cannot assign itself", async () => {
    await assertFails(
      setDoc(doc(db(as.unassignedCommittee), "events/evtA/committees/comB"), { organization_id: "himatif" }),
    );
  });
});

describe("attendance: registration", () => {
  const register = (persona, id, data) => setDoc(doc(db(persona), `attendance/${id}`), data);

  it("attendee registers for an active, open event with consent", async () => {
    await assertSucceeds(register(as.otherAttendee, "evtA_att2", attendance("evtA", "att2", "himatif")));
  });

  it("rejects registration without privacy consent", async () => {
    const data = { ...attendance("evtA", "att2", "himatif"), privacy_consent: false };
    await assertFails(register(as.otherAttendee, "evtA_att2", data));
  });

  it("rejects a document ID that is not eventId_uid", async () => {
    await assertFails(register(as.otherAttendee, "evtA_someoneElse", attendance("evtA", "att2", "himatif")));
  });

  it("rejects registering someone else", async () => {
    await assertFails(register(as.otherAttendee, "evtA_att3", attendance("evtA", "att3", "himatif")));
  });

  it("rejects registration for a draft event", async () => {
    await assertFails(register(as.otherAttendee, "evtDraft_att2", attendance("evtDraft", "att2", "himatif")));
  });

  it("rejects a pre-checked-in or pre-certified registration", async () => {
    await assertFails(register(as.otherAttendee, "evtA_att2", { ...attendance("evtA", "att2", "himatif"), is_checked_in: true }));
    await assertFails(register(as.otherAttendee, "evtA_att2", { ...attendance("evtA", "att2", "himatif"), certificate_issued: true }));
  });

  it("rejects a mismatched organization_id", async () => {
    await assertFails(register(as.otherAttendee, "evtA_att2", attendance("evtA", "att2", "bem")));
  });

  it("organizers and committee cannot register as attendees", async () => {
    await assertFails(register(as.organizer, "evtA_org1", attendance("evtA", "org1", "himatif")));
    await assertFails(register(as.committee, "evtA_comA", attendance("evtA", "comA", "himatif")));
  });
});

describe("attendance: reading", () => {
  it("attendee reads own record, not others'", async () => {
    await assertSucceeds(getDoc(doc(db(as.attendee), "attendance/evtA_att1")));
    await assertFails(getDoc(doc(db(as.otherAttendee), "attendance/evtA_att1")));
  });

  it("assigned committee reads its event's records only", async () => {
    await assertSucceeds(getDoc(doc(db(as.committee), "attendance/evtA_att1")));
    await assertFails(getDoc(doc(db(as.committee), "attendance/evtB_att1")));
    await assertFails(getDoc(doc(db(as.unassignedCommittee), "attendance/evtA_att1")));
  });

  it("organizer reads own org's records only", async () => {
    await assertSucceeds(getDoc(doc(db(as.organizer), "attendance/evtA_att1")));
    await assertFails(getDoc(doc(db(as.organizer), "attendance/evtB_att1")));
  });
});

describe("attendance: check-in", () => {
  const checkIn = (persona, by) =>
    updateDoc(doc(db(persona), "attendance/evtA_att1"), {
      is_checked_in: true,
      checked_in_at: serverTimestamp(),
      checked_in_by: by,
    });

  it("assigned committee checks an attendee in", async () => {
    await assertSucceeds(checkIn(as.committee, "comA"));
  });

  it("unassigned committee cannot check in", async () => {
    await assertFails(checkIn(as.unassignedCommittee, "comB"));
  });

  it("committee cannot record someone else as the scanner", async () => {
    await assertFails(checkIn(as.committee, "comB"));
  });

  it("committee cannot touch certificate fields", async () => {
    await assertFails(
      updateDoc(doc(db(as.committee), "attendance/evtA_att1"), {
        is_checked_in: true,
        checked_in_at: serverTimestamp(),
        checked_in_by: "comA",
        certificate_issued: true,
      }),
    );
  });

  it("attendee cannot check in themselves", async () => {
    await assertFails(checkIn(as.attendee, "att1"));
  });

  it("nobody deletes attendance from the client", async () => {
    await assertFails(deleteDoc(doc(db(as.admin), "attendance/evtA_att1")));
    await assertFails(deleteDoc(doc(db(as.attendee), "attendance/evtA_att1")));
  });
});

describe("default deny", () => {
  it("unknown collections are closed", async () => {
    await assertFails(getDoc(doc(db(as.admin), "secrets/x")));
    await assertFails(setDoc(doc(db(as.admin), "secrets/x"), { a: 1 }));
  });
});
