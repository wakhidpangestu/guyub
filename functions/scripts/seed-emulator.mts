// Seeds the local emulators with one demo account per role.
// Run while `npm run emulators` is up:  npm run seed   (from the repo root)
//
// Accounts are created as Google sign-ins, so they appear in the emulator's
// Google account picker. Pick one to open that role's dashboard.
//
// Emulator only. Refuses to run without the emulator host variables.

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import claims from "../lib/claims.js";
import tickets from "../lib/tickets.js";

const AUTH_HOST = (process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "localhost:9099");
process.env.FIRESTORE_EMULATOR_HOST ??= "localhost:8080";
const PROJECT_ID = "demo-guyub";
const ORG_ID = "himatif";

const personas = [
  { email: "admin@guyub.test", name: "Ayu Admin", role: "admin" },
  { email: "organizer@guyub.test", name: "Rina Organizer", role: "organizer", orgId: ORG_ID },
  { email: "committee@guyub.test", name: "Budi Committee", role: "committee", orgId: ORG_ID },
  { email: "attendee@guyub.test", name: "Sari Attendee", role: "attendee" },
] as const;

/** Signs in through the Auth emulator's fake Google IdP. Creates the user on first call. */
async function googleSignIn(email: string, name: string): Promise<string> {
  const idToken = JSON.stringify({ sub: `google-${email}`, email, email_verified: true, name });
  const response = await fetch(
    `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=demo-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        postBody: `id_token=${encodeURIComponent(idToken)}&providerId=google.com`,
        requestUri: "http://localhost",
        returnSecureToken: true,
      }),
    },
  );
  if (!response.ok) throw new Error(`Auth emulator sign-in failed for ${email}: ${await response.text()}`);
  const body = (await response.json()) as { localId: string };
  return body.localId;
}

try {
  await fetch(`http://${AUTH_HOST}/`);
} catch {
  console.error(`Auth emulator is not reachable at ${AUTH_HOST}. Start it first: npm run emulators`);
  process.exit(1);
}

initializeApp({ projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore();

await db.collection("organizations").doc(ORG_ID).set(
  { name: "HIMATIF (demo)", slug: ORG_ID, status: "active", created_at: FieldValue.serverTimestamp() },
  { merge: true },
);
console.log(`organizations/${ORG_ID} ready`);

const uids: Record<string, string> = {};
for (const persona of personas) {
  const uid = await googleSignIn(persona.email, persona.name);
  const input = claims.validateRoleInput({ uid, role: persona.role, orgId: "orgId" in persona ? persona.orgId : undefined });
  await claims.applyRole({ auth, db }, input);
  // The profile is normally written by onUserCreated; write it here too in
  // case the Functions emulator is still loading.
  await db.collection("users").doc(uid).set({ email: persona.email, display_name: persona.name }, { merge: true });
  uids[persona.role] = uid;
  console.log(`${persona.role.padEnd(9)} ${persona.email}`);
}

// Demo events for HIMATIF: one published, one draft, one finished.
const day = 24 * 60 * 60 * 1000;
const at = (offsetDays: number, hour: number) => {
  const date = new Date(Date.now() + offsetDays * day);
  date.setHours(hour, 0, 0, 0);
  return date;
};
const events = [
  {
    id: "demo-tech-talk",
    title: "Tech Talk: Building with Firebase",
    description: "An evening talk on shipping campus apps with Firebase and Flutter.",
    location: "Aula Timur ITB",
    date: at(7, 19),
    capacity: 150,
    status: "active",
    registration_open: true,
  },
  {
    id: "demo-workshop",
    title: "Flutter Web Workshop",
    description: "Hands-on session. Bring a laptop.",
    location: "Lab Komputer Labtek V",
    date: at(21, 9),
    capacity: 40,
    status: "draft",
    registration_open: false,
  },
  {
    id: "demo-orientation",
    title: "New Member Orientation",
    description: "",
    location: "Sekre HIMATIF",
    date: at(-14, 13),
    capacity: null,
    status: "completed",
    registration_open: false,
  },
];
for (const { id, ...data } of events) {
  await db.collection("events").doc(id).set({
    ...data,
    organization_id: ORG_ID,
    created_by: uids.organizer,
    registered_count: id === "demo-tech-talk" ? 1 : 0,
    created_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  });
}
await db.collection("events").doc("demo-tech-talk").collection("committees").doc(uids.committee).set({
  uid: uids.committee,
  organization_id: ORG_ID,
  display_name: "Budi Committee",
  email: "committee@guyub.test",
  assigned_by: uids.organizer,
  assigned_at: FieldValue.serverTimestamp(),
});
// attendee@guyub.test already holds a ticket for the Tech Talk.
await db.collection("attendance").doc(`demo-tech-talk_${uids.attendee}`).set({
  event_id: "demo-tech-talk",
  user_id: uids.attendee,
  organization_id: ORG_ID,
  attendee_name: "Sari Attendee",
  is_checked_in: false,
  certificate_issued: false,
  privacy_consent: true,
  consent_at: FieldValue.serverTimestamp(),
  registered_at: FieldValue.serverTimestamp(),
});
// The QR key lives apart from attendance, readable only by the attendee.
await db.collection("attendance_secrets").doc(`demo-tech-talk_${uids.attendee}`).set({
  user_id: uids.attendee,
  event_id: "demo-tech-talk",
  qr_token: tickets.newQrToken(),
  created_at: FieldValue.serverTimestamp(),
});
console.log(`${events.length} demo events; committee@guyub.test assigned to "Tech Talk"; attendee@guyub.test registered for it`);

console.log("\nDone. In the app, click Continue with Google and pick one of these accounts.");
