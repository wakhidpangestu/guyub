// Shared setup for security rules tests.
// Run through `npm run test:rules`, which starts the Firestore and Storage
// emulators and sets FIRESTORE_EMULATOR_HOST / FIREBASE_STORAGE_EMULATOR_HOST.

import { readFileSync } from "node:fs";
import { initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, Timestamp } from "firebase/firestore";

export const PROJECT_ID = "demo-guyub";

const read = (file) => readFileSync(new URL(`../../${file}`, import.meta.url), "utf8");

export async function createEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: read("firestore.rules") },
    storage: { rules: read("storage.rules") },
  });
}

/** Personas. Token options become custom claims on the test ID token. */
export const as = {
  admin: (env) => env.authenticatedContext("admin1", { role: "admin" }),
  organizer: (env) => env.authenticatedContext("org1", { role: "organizer", orgId: "himatif" }),
  otherOrganizer: (env) => env.authenticatedContext("org2", { role: "organizer", orgId: "bem" }),
  committee: (env) => env.authenticatedContext("comA", { role: "committee", orgId: "himatif" }),
  unassignedCommittee: (env) => env.authenticatedContext("comB", { role: "committee", orgId: "himatif" }),
  otherOrgCommittee: (env) => env.authenticatedContext("comX", { role: "committee", orgId: "bem" }),
  // Fresh Google sign-ups have no role claim.
  attendee: (env) => env.authenticatedContext("att1"),
  otherAttendee: (env) => env.authenticatedContext("att2"),
  anonymous: (env) => env.unauthenticatedContext(),
};

/** A complete, valid event document as the Flutter app writes it. */
export function event(orgId, overrides = {}) {
  return {
    organization_id: orgId,
    title: "Tech Talk",
    description: "",
    location: "Aula Barat",
    date: Timestamp.fromDate(new Date("2026-12-01T09:00:00+07:00")),
    capacity: null,
    status: "draft",
    registration_open: false,
    created_by: "org1",
    created_at: Timestamp.now(),
    updated_at: Timestamp.now(),
    ...overrides,
  };
}

export function assignment(uid, orgId, overrides = {}) {
  return {
    uid,
    organization_id: orgId,
    display_name: uid,
    email: `${uid}@example.com`,
    assigned_by: "org1",
    assigned_at: Timestamp.now(),
    ...overrides,
  };
}

/**
 * Two orgs. himatif has an active event (evtA), a draft (evtDraft), a
 * completed event (evtDone), and comA assigned to evtA. comB is a himatif
 * committee member with no assignment. bem has an active event (evtB) and
 * committee member comX. att1 is registered for evtA and evtB.
 */
export async function seed(env) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const now = Timestamp.now();
    const writes = {
      "organizations/himatif": { name: "HIMATIF", slug: "himatif", status: "active" },
      "organizations/bem": { name: "BEM", slug: "bem", status: "active" },
      "users/att1": { role: "attendee", organization_id: null },
      "users/att2": { role: "attendee", organization_id: null },
      "users/comA": { role: "committee", organization_id: "himatif", email: "comA@example.com" },
      "users/comB": { role: "committee", organization_id: "himatif", email: "comB@example.com" },
      "users/comX": { role: "committee", organization_id: "bem", email: "comX@example.com" },
      "users/org1": { role: "organizer", organization_id: "himatif" },
      "events/evtA": event("himatif", { status: "active", registration_open: true }),
      "events/evtDraft": event("himatif", { title: "Draft" }),
      "events/evtDone": event("himatif", { title: "Done", status: "completed" }),
      "events/evtB": event("bem", { title: "BEM Summit", status: "active", registration_open: true, created_by: "org2" }),
      "events/evtA/committees/comA": assignment("comA", "himatif"),
      "invites/pending@example.com": { email: "pending@example.com", role: "committee", organization_id: "himatif" },
      "invites/boss@example.com": { email: "boss@example.com", role: "organizer", organization_id: "himatif" },
      "invites/bem@example.com": { email: "bem@example.com", role: "committee", organization_id: "bem" },
      "attendance/evtA_att1": attendance("evtA", "att1", "himatif", now),
      "attendance/evtB_att1": attendance("evtB", "att1", "bem", now),
    };
    for (const [path, data] of Object.entries(writes)) {
      await setDoc(doc(db, path), data);
    }
  });
}

export function attendance(eventId, uid, orgId, consentAt = Timestamp.now()) {
  return {
    event_id: eventId,
    user_id: uid,
    organization_id: orgId,
    is_checked_in: false,
    certificate_issued: false,
    privacy_consent: true,
    consent_at: consentAt,
  };
}
