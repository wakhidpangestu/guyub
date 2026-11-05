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
  // Fresh Google sign-ups have no role claim.
  attendee: (env) => env.authenticatedContext("att1"),
  otherAttendee: (env) => env.authenticatedContext("att2"),
  anonymous: (env) => env.unauthenticatedContext(),
};

/**
 * Two orgs. himatif has an active event (evtA), a draft (evtDraft), and comA
 * assigned to evtA. bem has an active event (evtB). att1 is registered for both.
 */
export async function seed(env) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const now = Timestamp.now();
    const writes = {
      "organizations/himatif": { name: "HIMATIF", status: "active" },
      "organizations/bem": { name: "BEM", status: "active" },
      "users/att1": { role: "attendee", organization_id: null },
      "events/evtA": { organization_id: "himatif", title: "Tech Talk", status: "active", registration_open: true },
      "events/evtDraft": { organization_id: "himatif", title: "Draft", status: "draft", registration_open: false },
      "events/evtB": { organization_id: "bem", title: "BEM Summit", status: "active", registration_open: true },
      "events/evtA/committees/comA": { organization_id: "himatif", assigned_by: "org1" },
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
