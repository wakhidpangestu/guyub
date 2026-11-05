# Guyub

All-in-one operations platform for community and campus event orchestration.
STACK 2026 (GDGoC ITB), Case 2: Stronger Communities and Everyday Services.

Every role (admin, organizer, committee, attendee) uses one Flutter Web app. The backend is Firebase: Auth, Firestore, Storage, and Cloud Functions.

Design and decisions: [`docs/SPEC.md`](docs/SPEC.md). Current state and next steps: [`docs/HANDOFF.md`](docs/HANDOFF.md).

## Repository layout

```
apps/dashboard/     Flutter Web app for all roles
functions/          Cloud Functions (TypeScript, Node 22)
firestore.rules     Firestore security rules
storage.rules       Storage security rules
firebase.json       Firebase config, emulator ports, hosting
docs/               Spec, handoff notes, abstract drafts
```

## Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| Flutter | 3.47.9 (stable) | Web app |
| Node.js | 22 | Cloud Functions (runtime is `nodejs22`) |
| Firebase CLI | latest (`npm install -g firebase-tools`) | Emulators, deploy |
| Java | 21 or newer | Firestore and Storage emulators |

## Run locally against the emulators

No real Firebase project is needed. The emulators run the `demo-guyub` project.

1. Build the functions:

   ```sh
   cd functions
   npm install
   npm run build
   ```

2. Start the emulators from the repository root:

   ```sh
   firebase emulators:start
   ```

   Emulator UI: http://localhost:4000

3. Start the web app in a second terminal:

   ```sh
   cd apps/dashboard
   flutter run -d chrome --dart-define-from-file=env/emulator.json
   ```

4. Click **Continue with Google**. The Auth emulator shows a test account picker. Create any account. New accounts are attendees.

5. Give the account another role. The open app switches dashboards without signing out:

   ```sh
   cd functions
   npm run set-role -- --emulator --email you@example.com --role admin
   npm run set-role -- --emulator --email you@example.com --role organizer --org himatif
   ```

   `--org` creates the organization if it does not exist. Organizer and committee need an org.

## Tests

```sh
cd functions && npm test          # role validation and claim writes
cd apps/dashboard && flutter test # routing, auth controller, role dashboards
```

## Run against a real Firebase project

1. Create a Firebase project. Enable **Authentication > Google**, Firestore, and Storage.
2. Add a Web app in Project settings. Copy `apps/dashboard/env/example.json` to `apps/dashboard/env/dev.json` and fill in the values. Files in `env/` other than `emulator.json` and `example.json` are git-ignored.
3. Run `firebase use --add` and pick the project.
4. Bootstrap the first admin with a service account key:

   ```sh
   cd functions
   GOOGLE_APPLICATION_CREDENTIALS=path/to/key.json npm run set-role -- --project <project-id> --email you@example.com --role admin
   ```

5. Build and deploy:

   ```sh
   cd apps/dashboard && flutter build web --dart-define-from-file=env/dev.json
   cd ../.. && firebase deploy
   ```

## Status

Implemented:
- Google Sign-In, role from Firebase custom claims, live role refresh.
- Role routing: each role has its own area. Opening another role's area shows a "No access" page.
- Admin-only `setUserClaims` function, `onUserCreated` profile function, `set-role` bootstrap script.
- Firestore and Storage security rules (deny by default, org- and event-scoped).

Not implemented yet (shown as "Planned" cards in the app): events, committee assignment, registration, QR tickets, check-in, certificates, Sheets export, twibbon, landing page. See `docs/SPEC.md` §7.

Known limitations:
- Security rules have not been run against the emulator yet. Rules tests are pending.
- The app has not been run end-to-end against the emulators yet. Unit and widget tests use a fake auth backend.

## AI assistance disclosure

Required by the STACK 2026 handbook. Claude Code (Anthropic) was used to scaffold the repository, write the security rules, Cloud Functions, auth and routing code, tests, and documentation. The team reviews, tests, and is responsible for all code.
