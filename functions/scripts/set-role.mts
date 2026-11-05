// Assigns a Guyub role to an existing user by email.
// Use it to bootstrap the first admin and to seed demo accounts.
//
// Emulator (sign in once through the app first, so the user exists):
//   npm run set-role -- --emulator --email you@example.com --role admin
//   npm run set-role -- --emulator --email org@example.com --role organizer --org himatif
//
// Real project (needs GOOGLE_APPLICATION_CREDENTIALS pointing to a service account key):
//   npm run set-role -- --project <project-id> --email you@example.com --role admin
//
// --org creates organizations/{orgId} if it does not exist yet.

import { parseArgs } from "node:util";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import claims from "../lib/claims.js";

const { values } = parseArgs({
  options: {
    email: { type: "string" },
    role: { type: "string" },
    org: { type: "string" },
    project: { type: "string" },
    emulator: { type: "boolean", default: false },
  },
});

if (!values.email || !values.role) {
  console.error("Usage: npm run set-role -- [--emulator | --project <id>] --email <email> --role <role> [--org <orgId>]");
  process.exit(1);
}

if (values.emulator) {
  // Must be set before initializeApp so the Admin SDK talks to the emulators.
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "localhost:9099";
  process.env.FIRESTORE_EMULATOR_HOST ??= "localhost:8080";
}

const projectId = values.project ?? (values.emulator ? "demo-guyub" : undefined);
if (!projectId) {
  console.error("Pass --emulator or --project <project-id>.");
  process.exit(1);
}

initializeApp({ projectId });
const auth = getAuth();
const db = getFirestore();

try {
  const user = await auth.getUserByEmail(values.email);

  if (values.org) {
    const orgRef = db.collection("organizations").doc(values.org);
    if (!(await orgRef.get()).exists) {
      await orgRef.set({
        name: values.org,
        slug: values.org,
        status: "active",
        created_at: FieldValue.serverTimestamp(),
      });
      console.log(`Created organizations/${values.org}`);
    }
  }

  const input = claims.validateRoleInput({ uid: user.uid, role: values.role as never, orgId: values.org });
  await claims.applyRole({ auth, db }, input);
  console.log(`Set role "${input.role}"${input.orgId ? ` in org "${input.orgId}"` : ""} for ${values.email} (${user.uid}).`);
  console.log("The signed-in app refreshes its token automatically.");
} catch (error) {
  console.error((error as Error).message);
  process.exit(1);
}
