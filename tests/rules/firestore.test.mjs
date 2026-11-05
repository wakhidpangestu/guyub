import { after, before, beforeEach, describe, it } from "node:test";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

import { as, assignment, attendance, createEnv, event, seed } from "./helpers.mjs";

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

  it("organizer lists own org's members, not other orgs' or attendees", async () => {
    const members = query(collection(db(as.organizer), "users"), where("organization_id", "==", "himatif"));
    await assertSucceeds(getDocs(members));
    await assertSucceeds(getDoc(doc(db(as.organizer), "users/comA")));
    await assertFails(getDoc(doc(db(as.organizer), "users/comX")));
    await assertFails(getDoc(doc(db(as.organizer), "users/att1")));
  });

  it("committee cannot list org members", async () => {
    const members = query(collection(db(as.committee), "users"), where("organization_id", "==", "himatif"));
    await assertFails(getDocs(members));
  });
});

describe("organizations", () => {
  const org = (overrides = {}) => ({ name: "New Org", slug: "new-org", status: "active", created_by: "admin1", ...overrides });

  it("organizer reads own org only", async () => {
    await assertSucceeds(getDoc(doc(db(as.organizer), "organizations/himatif")));
    await assertFails(getDoc(doc(db(as.organizer), "organizations/bem")));
  });

  it("only admin creates organizations", async () => {
    await assertSucceeds(setDoc(doc(db(as.admin), "organizations/new-org"), org()));
    await assertFails(setDoc(doc(db(as.organizer), "organizations/new-org"), org({ created_by: "org1" })));
  });

  it("document ID must be the slug and a valid slug", async () => {
    await assertFails(setDoc(doc(db(as.admin), "organizations/other"), org()));
    await assertFails(setDoc(doc(db(as.admin), "organizations/Bad Slug"), org({ slug: "Bad Slug" })));
  });

  it("rejects too-short names and extra fields", async () => {
    await assertFails(setDoc(doc(db(as.admin), "organizations/new-org"), org({ name: "X" })));
    await assertFails(setDoc(doc(db(as.admin), "organizations/new-org"), { ...org(), plan: "pro" }));
  });

  it("organizations are never deleted from the client", async () => {
    await assertFails(deleteDoc(doc(db(as.admin), "organizations/himatif")));
  });
});

describe("invites", () => {
  it("organizer reads own org's invites only", async () => {
    await assertSucceeds(getDoc(doc(db(as.organizer), "invites/pending@example.com")));
    await assertFails(getDoc(doc(db(as.organizer), "invites/bem@example.com")));
    await assertSucceeds(getDocs(query(collection(db(as.organizer), "invites"), where("organization_id", "==", "himatif"))));
  });

  it("organizer cancels committee invites but not organizer invites", async () => {
    await assertSucceeds(deleteDoc(doc(db(as.organizer), "invites/pending@example.com")));
    await assertFails(deleteDoc(doc(db(as.organizer), "invites/boss@example.com")));
    await assertSucceeds(deleteDoc(doc(db(as.admin), "invites/boss@example.com")));
  });

  it("nobody writes invites from the client", async () => {
    const invite = { email: "x@example.com", role: "committee", organization_id: "himatif" };
    await assertFails(setDoc(doc(db(as.organizer), "invites/x@example.com"), invite));
    await assertFails(setDoc(doc(db(as.admin), "invites/x@example.com"), invite));
  });

  it("attendees and committee cannot read invites", async () => {
    await assertFails(getDoc(doc(db(as.attendee), "invites/pending@example.com")));
    await assertFails(getDoc(doc(db(as.committee), "invites/pending@example.com")));
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
    await assertSucceeds(setDoc(doc(db(as.organizer), "events/evtNew"), event("himatif")));
    await assertFails(setDoc(doc(db(as.organizer), "events/evtNew2"), event("bem")));
    await assertFails(setDoc(doc(db(as.attendee), "events/evtNew3"), event("himatif", { created_by: "att1" })));
  });

  it("organizer cannot edit another org's event or move an event to another org", async () => {
    await assertSucceeds(updateDoc(doc(db(as.organizer), "events/evtA"), { title: "Renamed" }));
    await assertFails(updateDoc(doc(db(as.organizer), "events/evtA"), { organization_id: "bem" }));
    await assertFails(updateDoc(doc(db(as.otherOrganizer), "events/evtA"), { title: "Hijacked" }));
  });
});

describe("events: validation", () => {
  const create = (data) => setDoc(doc(db(as.organizer), "events/evtNew"), data);

  it("new events must start as drafts with registration closed", async () => {
    await assertFails(create(event("himatif", { status: "active" })));
    await assertFails(create(event("himatif", { registration_open: true })));
  });

  it("created_by must be the caller", async () => {
    await assertFails(create(event("himatif", { created_by: "someone-else" })));
  });

  it("rejects missing or oversized title", async () => {
    await assertFails(create(event("himatif", { title: "" })));
    await assertFails(create(event("himatif", { title: "x".repeat(121) })));
    const { title, ...noTitle } = event("himatif");
    await assertFails(create(noTitle));
  });

  it("rejects a bad date, status, capacity, or unknown field", async () => {
    await assertFails(create(event("himatif", { date: "tomorrow" })));
    await assertFails(create(event("himatif", { status: "archived" })));
    await assertFails(create(event("himatif", { capacity: 0 })));
    await assertFails(create(event("himatif", { capacity: 1.5 })));
    await assertFails(create(event("himatif", { price: 10000 })));
  });

  it("accepts a capacity", async () => {
    await assertSucceeds(create(event("himatif", { capacity: 150 })));
  });
});

describe("events: status transitions", () => {
  const setStatus = (id, status, registration_open = false) =>
    updateDoc(doc(db(as.organizer), `events/${id}`), { status, registration_open });

  it("draft publishes to active", async () => {
    await assertSucceeds(setStatus("evtDraft", "active"));
  });

  it("active goes back to draft or forward to completed", async () => {
    await assertSucceeds(setStatus("evtA", "draft"));
    await assertSucceeds(setStatus("evtA", "active", true));
    await assertSucceeds(setStatus("evtA", "completed"));
  });

  it("draft cannot skip to completed", async () => {
    await assertFails(setStatus("evtDraft", "completed"));
  });

  it("completed is final", async () => {
    await assertFails(setStatus("evtDone", "active"));
    await assertFails(setStatus("evtDone", "draft"));
    await assertSucceeds(updateDoc(doc(db(as.organizer), "events/evtDone"), { title: "Done (typo fixed)" }));
  });

  it("registration opens only on active events", async () => {
    await assertFails(setStatus("evtDraft", "draft", true));
    await assertFails(updateDoc(doc(db(as.organizer), "events/evtA"), { status: "completed", registration_open: true }));
  });

  it("only drafts are deleted", async () => {
    await assertSucceeds(deleteDoc(doc(db(as.organizer), "events/evtDraft")));
    await assertFails(deleteDoc(doc(db(as.organizer), "events/evtA")));
    await assertFails(deleteDoc(doc(db(as.organizer), "events/evtDone")));
  });
});

describe("committee assignment", () => {
  const assign = (persona, eventId, uid, overrides) =>
    setDoc(doc(db(persona), `events/${eventId}/committees/${uid}`), assignment(uid, "himatif", overrides));

  it("organizer assigns own org's committee member to own org's event", async () => {
    await assertSucceeds(assign(as.organizer, "evtA", "comB"));
  });

  it("assignee must be a committee member of the event's org", async () => {
    await assertFails(assign(as.organizer, "evtA", "att2"));
    await assertFails(assign(as.organizer, "evtA", "org1"));
    await assertFails(
      setDoc(doc(db(as.organizer), "events/evtA/committees/comX"), assignment("comX", "bem")),
    );
  });

  it("uid field must match the document ID, assigned_by must be the caller", async () => {
    await assertFails(assign(as.organizer, "evtA", "comB", { uid: "comA" }));
    await assertFails(assign(as.organizer, "evtA", "comB", { assigned_by: "someone" }));
  });

  it("other org's organizer cannot assign", async () => {
    await assertFails(
      setDoc(doc(db(as.otherOrganizer), "events/evtA/committees/comX"), assignment("comX", "bem", { assigned_by: "org2" })),
    );
  });

  it("committee cannot assign itself", async () => {
    await assertFails(assign(as.unassignedCommittee, "evtA", "comB", { assigned_by: "comB" }));
  });

  it("organizer removes an assignment", async () => {
    await assertSucceeds(deleteDoc(doc(db(as.organizer), "events/evtA/committees/comA")));
    await assertFails(deleteDoc(doc(db(as.otherOrganizer), "events/evtA/committees/comA")));
  });

  it("committee lists only its own assignments across events", async () => {
    const mine = query(collectionGroup(db(as.committee), "committees"), where("uid", "==", "comA"));
    await assertSucceeds(getDocs(mine));
    const theirs = query(collectionGroup(db(as.committee), "committees"), where("uid", "==", "comB"));
    await assertFails(getDocs(theirs));
  });

  it("assigned committee reads the event; unassigned committee cannot read a draft", async () => {
    await assertSucceeds(getDoc(doc(db(as.committee), "events/evtA")));
    await assertFails(getDoc(doc(db(as.unassignedCommittee), "events/evtDraft")));
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
