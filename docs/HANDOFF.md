# Handoff — Guyub build state

Read `docs/SPEC.md` first. Its §0 decision log is locked. Setup and run steps are in `README.md`.

## Done

- **M0 foundation:** repo layout, `firebase.json`, `.firebaserc` (default `demo-guyub` for emulators), Firestore and Storage rules, Cloud Functions in TypeScript (Node 22, region `asia-southeast2`).
- **M1 auth and role routing:**
  - Google Sign-In (`signInWithPopup`). Role and `orgId` come from ID token claims. No claim means attendee, in the app and in the rules.
  - `resolveRedirect` (pure function, `lib/routing/redirect.dart`): splash while loading, login when signed out, role home after login, `/forbidden` for another role's area. Deep links survive login. Off-site and transient `from` targets are ignored.
  - Live role change: `AuthController` compares the role mirrored in `users/{uid}` with the token's claims and refreshes the token when they differ. The app then moves to the new dashboard.
  - Functions: `setUserClaims` (admin only), `onUserCreated` (creates the attendee profile, never overwrites), shared logic in `src/claims.ts`.
- **M2 organizations, events, committee:**
  - Admin: create organizations (ID = slug, transaction refuses duplicates), add organizers by email.
  - Organizer: event list, create (always a draft), edit, publish, open/close registration, move back to draft, mark completed (final), delete drafts (assignments deleted in the same batch).
  - Organizer: committee members by email, remove, cancel pending invites, assign/unassign per event.
  - Committee: "Your events" via a collection-group query on `committees` filtered by `uid`.
  - Functions: `inviteMember` (grant now, or store `invites/{email}` for first sign-in), `removeMember` (back to attendee, deletes assignments). Decisions are pure functions in `src/members.ts`.
  - `onUserCreated` applies a pending invite for a verified email.
  - Rules: event shape and status transitions validated; registration only while published; committee assignees must be committee members of the event's org (checked against `users/{uid}`); organizers read their org's member profiles and invites.
  - Data layer: `Backend` interface (`lib/data/backend.dart`), `FirebaseBackend`, in-memory `FakeBackend` for widget tests.
- **Bugs found and fixed in M2:**
  - Invite applied before the app subscribed (first sign-in) was missed, leaving the user as attendee for up to an hour. Fixed by comparing values instead of reacting to changes.
  - `StreamView` treated a null value ("not found") as "still loading" and spun forever.
  - Deleting a draft left its committee assignments behind.
- **M3 attendee registration and tickets:**
  - Browse upcoming published events from all orgs (query `status == active`, `date >= today`; composite index `status, date`). Org names come from `organizations`, now readable by any signed-in user.
  - Event page with registration state (open, spots left, full, closed, registered), privacy consent dialog, register, cancel.
  - `registerForEvent` / `cancelRegistration` callables: one transaction for consent, role, status, open registration, capacity, `registered_count`, the ticket, and its secret. Idempotent. Pure decisions in `src/registration.ts`.
  - The QR key lives in `attendance_secrets/{id}`, readable only by the ticket owner (audit H2). Attendance carries the attendee name only, no email (audit M1).
  - Daily `retentionPurge` (03:00 WIB) and admin-only `runRetentionPurge` delete attendance and secrets 12 months after the event (audit H3).
  - Rules: clients can no longer create attendance; organizers cannot touch `registered_count`; drafts with registrations cannot be deleted; a registered attendee keeps reading the event after it leaves active.
  - Dynamic QR (`src/tickets.ts` and `lib/data/ticket_code.dart`): HMAC of a per-ticket token and a 30-second window. `verifyTicket` (valid, expired, invalid) is ready for M4.
  - My tickets list and ticket page (rotating QR with countdown, checked-in and completed states).
  - Seed: `attendee@guyub.test` holds a ticket for the Tech Talk.
- **M4 check-in:**
  - `checkIn` callable: authorization (`authorizeCheckIn`), early code checks (`classifyScan`), and the final decision (`decideCheckIn`) are pure functions in `src/checkin.ts`. One transaction reads event, attendance, and secret, so two doors scanning one ticket record one check-in.
  - Rules: attendance `allow update: if false` (audit H1). Committee lists its assigned event's attendance; organizers list attendance with a query that names their org.
  - Door screen (`lib/features/checkin/scan_page.dart`) for committee (`/committee/events/:id`) and organizers (`/organizer/events/:id/scan`): camera via `mobile_scanner` (BarcodeDetector or zxing-wasm on the web), a code field that also takes USB scanners, a result card per outcome, a live counter, recent check-ins.
  - Organizer attendance page (`/organizer/events/:id/attendance`): live list, search, filter, manual check-in.
  - Committee event tiles open the door screen (audit L1).
- **Dev tooling:** root dev deps (`npx firebase`), `npm run emulators` with saved data, `npm run seed` (demo accounts, events, assignment, ticket), `scripts/dev.ps1`. Tests run on separate ports (`firebase.test.json`) so they never touch dev data.
- **Tests:** functions 51, Flutter 118, rules 71, smoke 36. All passing. `flutter analyze` clean.

## Verified end-to-end (emulators, headless Chrome, release build)

- M1: deep link, Google popup, role dashboards, live role change.
- M2, through the real UI and real rules:
  - Organizer creates an event in the form; the document has the right shape (integer capacity, UTC date, draft).
  - Publish, open registration, and assign a committee member from the dropdown.
  - Committee member sees the assigned event and is blocked from organizer pages.
  - Admin creates an organization in the dialog and invites an organizer by email.
  - A brand-new account with that email signs in for the first time and lands on the Organizer dashboard within 4 seconds.
- M3, through the real UI and real rules:
  - Attendee browses (org names, Registered and spots-left badges), registers with the consent checkbox, lands on the ticket; `registered_count` goes up.
  - The QR decoded from a screenshot of the release build verifies with the server's `verifyTicket`: valid at that time, expired two minutes later, invalid with another token. This proves the dart2js HMAC matches Node.

- M4, through the real UI, real rules, and a real camera path:
  - Headless Chrome with a fake webcam (an MJPEG of a live ticket QR): `mobile_scanner` decoded it and the attendee was checked in (`check_in_method: scan`). The green result stays while the person stands in front of the camera.
  - Pasting a code into the field checks in; a non-ticket shows "Not a valid ticket".
  - Organizer attendance page shows live state; manual check-in records `check_in_method: manual`.

## Next, in order (SPEC §7)

1. **M5:** Certificate function and email on check-in. Batch sends (Gmail SMTP caps). Certificate template stays private (audit L6).
2. **M6:** Twibbon (client-side canvas), Google Sheets export, platform metrics, Next.js landing, deploy.

Every new collection or rule change needs a case in `tests/rules/`. Every new callable needs a smoke test in `tests/smoke/`. Every new page needs a widget test with `FakeBackend`.

## Open items

- Real Firebase project not created yet. `.firebaserc` default is `demo-guyub`. Deploying needs `firestore.indexes.json` (includes the collection-group index on `committees.uid`).
- Invites are not emailed. Could reuse the M5 email pipeline.
- Organizations cannot be disabled. Enforcing a disabled org in rules costs one extra read per request; decide before adding.
- Event banner upload is not in the UI yet (Storage rules are ready).
- Only attendee accounts register. Letting organizer and committee accounts attend other orgs' events needs a decision on the one-role-per-account model.
- Organizers cannot see the list of registrants yet (count only). Planned with M4 attendance view.
- Demo access for judges: Google-only sign-in means judges sign in as attendees. Organizer and committee demo needs `set-role` on their account, or pre-made demo accounts.
- Retention purge (12 months) is not written.
- Email provider: Trigger Email extension vs Nodemailer. SPEC §0 decision 2 allows either.
- Sheets export auth model: service account vs user OAuth.
- Abstract is handled by a teammate. Do not edit `docs/abstract/` unless asked.

## Conventions

- Code, comments, and docs in English. The handbook requires English for submissions.
- Do not commit `.env`, service account JSON, real `apps/dashboard/env/*.json`, or the Flutter SDK.
- AI assistance is disclosed in `README.md`. Keep it accurate.
