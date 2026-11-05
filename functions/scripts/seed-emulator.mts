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

for (const persona of personas) {
  const uid = await googleSignIn(persona.email, persona.name);
  const input = claims.validateRoleInput({ uid, role: persona.role, orgId: "orgId" in persona ? persona.orgId : undefined });
  await claims.applyRole({ auth, db }, input);
  console.log(`${persona.role.padEnd(9)} ${persona.email}`);
}

console.log("\nDone. In the app, click Continue with Google and pick one of these accounts.");
