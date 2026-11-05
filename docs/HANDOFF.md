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
- **Live role change:** the app follows a server-side role change to the new dashboard (no "No access" detour).
- **Dev tooling:** `firebase-tools` and the rules test kit are root dev dependencies (`npx firebase`, no global install). `npm run emulators` keeps data in `.emulator-data/`. `npm run seed` creates one Google demo account per role. `scripts/dev.ps1` starts the whole stack on Windows.
- **Rules fix found by tests:** committee members read every attendance record and draft event of their org through the `sameOrg` branch. That branch is now organizer-only.
- **Tests:** functions 7, Flutter 52, rules 40, M1 smoke 6. All passing. `flutter analyze` clean.

## Verified end-to-end (emulators, headless Chrome)

- Deep link `/organizer` while signed out, then login page, Google popup, `organizer@guyub.test`, and the Organizer dashboard. Checked in the release build (Hosting emulator) and in debug `flutter run` on port 8090.
- Signed in as attendee, then `set-role --role committee`. The open app switched to the Committee dashboard within about 6 seconds.

## Next, in order (SPEC §7)

1. **M2:** Admin creates organizations and grants organizer. Organizer event CRUD. Committee assignment writes `events/{id}/committees/{uid}`; a Cloud Function checks the assignee's `orgId`.
2. **M3:** Attendee browse, register (consent toggle, `${eventId}_${uid}` ID), QR ticket.
3. **M4:** Committee scanner. Check-in writes only `is_checked_in`, `checked_in_at`, `checked_in_by`.
4. **M5:** Certificate function and email on check-in. Batch sends (Gmail SMTP caps).
5. **M6:** Twibbon (client-side canvas), Google Sheets export, Next.js landing, deploy.

Every new collection or rule change needs a case in `tests/rules/`. Every new callable needs a smoke test in `tests/smoke/`.

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
