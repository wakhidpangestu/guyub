# Handoff — Guyub build state

Read `docs/SPEC.md` first. Its §0 decision log is locked. Setup and run steps are in `README.md`.

## Done

- **M0 foundation:** repo layout, `firebase.json`, `.firebaserc` (default `demo-guyub` for emulators), Firestore and Storage rules, Cloud Functions in TypeScript (Node 22, region `asia-southeast2`).
- **M1 auth and role routing:**
  - Google Sign-In (`signInWithPopup`). Role and `orgId` come from ID token claims. No claim means attendee, in the app and in the rules.
  - `AuthController` watches `users/{uid}.updated_at` and refreshes the token after a server-side role change.
  - `resolveRedirect` (pure function, `lib/routing/redirect.dart`): splash while loading, login when signed out, role home after login, `/forbidden` for another role's area. Deep links survive login. Off-site and transient `from` targets are ignored.
  - Four role areas (`/admin`, `/organizer`, `/committee`, `/attendee`) with "Planned · Mx" cards for unbuilt features.
  - Config via `--dart-define-from-file` (`env/emulator.json` committed; real env files ignored). Missing config shows a setup screen.
  - Functions: `setUserClaims` (admin only, validates org exists), `onUserCreated` (creates attendee profile, never overwrites), shared logic in `src/claims.ts`.
  - `npm run set-role` script bootstraps the first admin and seeds demo roles.
- **Rule fixes in M1:** missing `role` claim no longer denies attendees; Storage certificate path used an invalid partial wildcard; Storage event assets are now checked against the event's org through `firestore.get()`.
- **Tests:** `functions` 7 passing (`npm test`). `apps/dashboard` 51 passing (`flutter test`). `flutter analyze` clean. `flutter build web` passes.

## Not verified yet

- Java is not installed on the dev machine, so the Firestore and Storage emulators have not run. Rules are untested.
- The app has not run end-to-end against the emulators (Google popup, claims, live refresh). Widget tests cover the flow with a fake backend.

## Next, in order (SPEC §7)

1. Install Java 21+ and `firebase-tools`. Run the emulators. Walk the M1 flow by hand. Add rules tests with `@firebase/rules-unit-testing`.
2. **M2:** Admin creates organizations and grants organizer. Organizer event CRUD. Committee assignment writes `events/{id}/committees/{uid}`; a Cloud Function checks the assignee's `orgId`.
3. **M3:** Attendee browse, register (consent toggle, `${eventId}_${uid}` ID), QR ticket.
4. **M4:** Committee scanner. Check-in writes only `is_checked_in`, `checked_in_at`, `checked_in_by`.
5. **M5:** Certificate function and email on check-in. Batch sends (Gmail SMTP caps).
6. **M6:** Twibbon (client-side canvas), Google Sheets export, Next.js landing, deploy.

## Open items

- Real Firebase project not created yet. `.firebaserc` default is `demo-guyub`.
- Demo access for judges: Google-only sign-in means judges sign in as attendees. Organizer and committee demo needs `set-role` on their account, or pre-made demo accounts.
- Retention purge (12 months) is not written.
- Email provider: Trigger Email extension vs Nodemailer. SPEC §0 decision 2 allows either.
- Sheets export auth model: service account vs user OAuth.
- Abstract is handled by a teammate. Do not edit `docs/abstract/` unless asked.

## Conventions

- Code, comments, and docs in English. The handbook requires English for submissions.
- Do not commit `.env`, service account JSON, real `apps/dashboard/env/*.json`, or the Flutter SDK.
- AI assistance is disclosed in `README.md`. Keep it accurate.
