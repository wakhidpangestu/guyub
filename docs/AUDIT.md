# Guyub — Security and Correctness Audit (M0–M3)

Scope: everything committed up to `c5b98a3` (M3). Reviewed by reading the code and by running targeted rules probes against the Firestore emulator.

Audited files:

- `firestore.rules`, `storage.rules`, `firestore.indexes.json`
- `functions/src/` (`index.ts`, `claims.ts`, `members.ts`, `registration.ts`, `tickets.ts`, `config.ts`)
- `apps/dashboard/lib/` (auth, routing, data layer, feature pages, QR code)
- `scripts/dev.ps1`, `firebase.json`, `.firebaserc`, `.gitignore`

Method:

1. Read rules against the threat model in `docs/SPEC.md` (roles, per-event committee scope, server-only writes).
2. Read every Cloud Function path for authorization, transaction safety, and error handling.
3. Read the client for data exposure and state handling.
4. Ran five probes against the rules emulator (`firebase.test.json`, separate ports). The probe file was deleted afterwards. The results are recorded in §4.

Current baseline before this audit: functions 39, rules 64, smoke 22, Flutter 101 — all passing. No code was changed by this audit.

---

## 1. Summary

| ID | Severity | Title | Verified |
|---|---|---|---|
| H1 | High | Committee can check in attendees without a QR scan | Yes (probe F2) |
| H2 | High | Organizers and committee can read every attendee's secret `qr_token` | Yes (probe F1, F1b) |
| H3 | High | Privacy notice promises 12-month deletion; no deletion exists | Code review |
| M1 | Medium | Committee sees attendee email, not just what check-in needs | Code review |
| M2 | Medium | Invite response reveals whether an email has an account | Code review |
| M3 | Medium | No abuse controls on callable functions (no App Check, no quotas) | Code review |
| M4 | Medium | Real `.firebaserc` is still the demo project placeholder | Code review |
| L1 | Low | Committee event list items are not clickable | Code review |
| L2 | Low | `removeMember` maps every Auth error to "No account with this uid" | Code review |
| L3 | Low | Capacity and registration races are untested under real concurrency | Code review |
| L4 | Low | Moving an active event back to draft silently blocks check-in for registrants | Code review |
| L5 | Low | `upcoming events` window uses the device's local day, not the event's timezone | Code review |
| L6 | Low | Event banner and template files in Storage are public | Code review |
| I1 | Info | Duplicate concepts on client (`EventTile` vs `_AttendeeEventTile`, `Member` vs `Assignment`) | Code review |

Fix order recommendation: H2 and H1 first, because they belong to M4 anyway and the M4 work is the cheapest place to close them. Then H3 (either build the purge or stop promising it). Then M1 and M2. The rest can go into the M6 hardening pass.

### Remediation status

| ID | Status | How |
|---|---|---|
| H1 | Fixed in M4 | See the M4 commit: check-in only through the `checkIn` callable; the client update rule is closed. |
| H2 | Fixed | QR key moved to `attendance_secrets/{id}`, owner-read-only. Rules tests: organizer, committee, admin, other attendee, and anonymous reads fail; `attendance` has no `qr_token`. SPEC §5 and HANDOFF corrected. |
| H3 | Fixed | `retentionPurge` runs daily at 03:00 WIB; `runRetentionPurge` (admin only) runs it on demand. Both delete attendance and secrets of events older than 365 days and keep the events. Smoke-tested. The notice now says "deleted automatically 12 months after the event". |
| M1 | Fixed | `attendee_email` is no longer written to attendance (and no email fallback in `attendee_name`). The privacy notice says the name is shared and the email is not. |
| M2 | Risk accepted | Making the response uniform does not help: the members list and the pending-invite list update in real time, so the organizer sees the difference anyway. Hiding it would need a separate acceptance step for existing accounts. What leaks is only "this email has signed in to Guyub", visible only to organizers that an admin appointed. Revisit if organizer accounts become self-service. |
| M3 | Deferred to deploy | App Check needs a real Firebase project and a reCAPTCHA Enterprise key, so it cannot be enforced against the emulators. Pre-deploy checklist item: register the web app in App Check, add `firebase_app_check` to the dashboard, set `enforceAppCheck: true` on every `onCall`, and use the debug provider for local runs. |
| M4 | Deferred to deploy | Same checklist: create the project, `npx firebase use --add`, keep `demo-guyub` for `--project` on emulator scripts only. README "Run against a real Firebase project" covers the steps. |
| L1 | Fixed in M4 | Committee event tiles open the scanner. |
| L2 | Fixed | `removeMember` maps only `auth/user-not-found` to "No account with this uid" and rethrows other Auth errors. |
| L3 | Fixed | Smoke test: 8 parallel registrations against capacity 3 give exactly 3 tickets and 5 "full" refusals; `registered_count` ends at 3. |
| L4 | Fixed | The move-to-draft dialog says how many people hold tickets and that nobody can check in until the event is published again. |
| L5 | Fixed | `startOfTodayWib` sets the "upcoming" boundary at WIB midnight for every viewer; unit-tested across the WIB/UTC day change and independent of the device time zone. |
| L6 | Fixed | `events/{eventId}/certificate-template.pdf` is readable only by the event's organizers (and the Admin SDK). Banners stay public. Storage rules test added. |
| I1 | Open | Cleanup for the M6 pass. |

---

## 2. High severity

### H1 — Committee can check in attendees without a QR scan

**Where:** `firestore.rules`, `match /attendance/{attendanceId}`, `allow update`.

**What:** The rule lets an assigned committee member change `is_checked_in`, `checked_in_at`, and `checked_in_by` directly. Nothing verifies a ticket.

```
allow update: if isAssignedCommittee(resource.data.event_id)
  && ... .hasOnly(['is_checked_in', 'checked_in_at', 'checked_in_by'])
  && request.resource.data.is_checked_in == true
  && request.resource.data.checked_in_by == request.auth.uid;
```

**Impact:** Any committee member can mark any registered attendee as present, including no-shows, and can do it without seeing a ticket. Attendance counts and certificate issuance (M5) would be wrong.

**Verified:** Probe F2. An assigned committee member's direct update succeeded with no QR involved.

**Fix:** Planned for M4. Remove the client update path for check-in. Add a `checkIn` callable that:

1. parses the payload with `parseTicketPayload`,
2. confirms the caller is in `events/{eventId}/committees/{uid}`,
3. reads `qr_token` server-side and runs `verifyTicket`,
4. writes the three check-in fields in a transaction.

Add rules tests that assert direct client updates fail.

### H2 — Organizers and committee can read every attendee's secret `qr_token`

**Where:** `firestore.rules`, `match /attendance/{attendanceId}`, `allow read`. The rule has no field restrictions. The `qr_token` field sits in the same document.

**What:** Assigned committee members and organizers of the event's org can read the whole attendance document, including `qr_token`.

**Why it matters:** The QR signature is HMAC-SHA256 keyed by `qr_token`. Whoever holds the token can compute a valid signature for any window. A committee member can therefore produce valid, rotating tickets for anyone registered for their event, print them, or hand them to a friend. The check-in function (once H1 is fixed) still accepts them, because the signature is correct.

**Verified:** Probe F1 (committee) and F1b (organizer) both read `qr_token` in plain text.

**Also a documentation error:** the HANDOFF and SPEC §5 I wrote in M3 say the token is readable by "the attendee, their org's organizers, and the event's committee". That contradicts the threat model and must be corrected when this is fixed.

**Fix:**

1. Move the token out of `attendance` into `attendance_secrets/{attendanceId}`, readable only by its owner (`user_id == request.auth.uid`) and by Admin SDK code. Keep it write-once, set by `registerForEvent`.
2. The ticket page reads its own secret document. Committee and organizers never read it.
3. The `checkIn` callable (H1) reads the secret with the Admin SDK.
4. Add a probe-style rules test: committee and organizer reads of `attendance_secrets` fail; owner reads succeed.

### H3 — Privacy notice promises 12-month deletion; no deletion exists

**Where:** `apps/dashboard/lib/features/attendee/privacy_consent_dialog.dart` says "Attendance records are kept for 12 months, then deleted." `docs/SPEC.md` §0 decision 6 requires a scheduled purge. The purge is not written (HANDOFF open items).

**Impact:** Attendees consent to a retention period the system does not enforce. This is a misleading statement inside a consent flow, which is a UU PDP (Indonesian data-protection law) issue, not just a backlog item.

**Fix (pick one before the M3 release):**

- Build the purge: a scheduled function deleting `attendance` and attendance secrets whose event ended more than 12 months ago, plus the `users` profiles of accounts inactive for that long if the notice covers them.
- Or change the notice to what is actually true today ("kept until the organizer deletes the event") and track the purge as a blocker for public launch.

---

## 3. Medium severity

### M1 — Committee sees attendee email, not just what check-in needs

**Where:** `registerForEvent` writes `attendee_name` and `attendee_email` into `attendance`. Committee members read the whole document (H2).

**Impact:** A committee member sees the email of every registrant of their event. The privacy notice says the name and email are shared with the org "to run this event". Check-in only needs the name and the ticket state, so the email is more than the purpose requires.

**Fix:** Drop `attendee_email` from `attendance`. Organizers who need contact details read them from `users` (already allowed for same-org profiles). Committee-facing data becomes name plus check-in state.

### M2 — Invite response reveals whether an email has an account

**Where:** `functions/src/index.ts`, `inviteMember` returns `{ status: "granted", uid }` when the account exists and `{ status: "invited" }` when it does not.

**Impact:** Any organizer can probe whether an email has signed in to Guyub. The organizer role is granted to organizers, not to the public, but organizers are a broad group (one per org, many orgs).

**Fix:** Return the same response shape for both cases ("invite saved; the person gets access at their next sign-in") and let the UI show the same message. Accept the small UX cost of not telling an organizer that a grant was instant.

### M3 — No abuse controls on callable functions

**Where:** every `onCall` in `functions/src/index.ts`. `inviteMember`, `registerForEvent`, and `cancelRegistration` each do Auth and Firestore reads per call. Nothing limits how often a signed-in user can call them.

**Impact:** A signed-in attacker, including a bot that creates Google accounts, can spam invite writes, registrations, or cost-generating reads.

**Fix:** Enable Firebase App Check on the web app and enforce it on callables. Add a per-user quota or a short cooldown for `inviteMember` and `registerForEvent`. Document the quota in the README.

### M4 — `.firebaserc` still targets the demo project

**Where:** `.firebaserc` sets `"default": "demo-guyub"`.

**Impact:** `firebase deploy` would target a project that does not exist in production, or fail. A later edit to point it at the real project could be done without reviewing the emulator-only config (`firebase.json` has emulator ports and `singleProjectMode`).

**Fix:** Before first deploy, create the real project, set the alias, and keep `demo-guyub` only for emulator runs via `--project` (already how `npm run emulators` works).

---

## 4. Verification probes

Run against the Firestore emulator on the test ports, with the seed from `tests/rules/helpers.mjs` plus one attendance document containing a `qr_token`.

| Probe | Expectation | Result | Meaning |
|---|---|---|---|
| F1 committee reads attendance with `qr_token` | should fail | succeeded, token returned | H2 confirmed |
| F1b organizer reads attendance with `qr_token` | should fail | succeeded, token returned | H2 confirmed |
| F2 committee client-side check-in with no QR | should fail | succeeded | H1 confirmed |
| F3 organizer reads profile of an attendee outside the org | should fail | failed (denied) | Rules correct; probe expectation was wrong |
| F4 other attendee reads ticket with secret | should fail | failed (denied) | Correct |

The probe file was deleted after the run. Its cases are not in the permanent suite: H1 and H2 should become permanent assertions in the M4 fix, flipping the expected result.

---

## 5. Low severity

### L1 — Committee event list items are not clickable

`apps/dashboard/lib/features/committee/committee_home_page.dart` builds `EventTile(event: event)` without `onTap`. Committee members see their events but cannot open one. The M4 scanner page resolves this. Until then the list is read-only, which is consistent with the UI, so the only gap is the missing path to the scanner.

### L2 — `removeMember` maps every Auth error to "No account with this uid"

`functions/src/index.ts` `auth.getUser(uid).catch(() => throw RoleInputError("No account with this uid."))`. A transient Auth outage would surface as "no such account", which hides the real problem. Catch `auth/user-not-found` only and rethrow everything else.

### L3 — Capacity and registration races are untested under real concurrency

`registerForEvent` uses a transaction that reads the event and attendance first, then creates and increments. The logic is correct by inspection: Firestore transactions retry on contention, so two registrations for the last spot cannot both succeed. The smoke test is sequential and does not prove it. Add a concurrent smoke test (for example, ten parallel calls against capacity 3, expecting exactly three `registered`).

### L4 — Moving an active event back to draft silently blocks check-in

`firestore.rules` attendance update requires `get(event).status == 'active'`. An organizer who moves a published event back to draft (allowed by `isValidTransition`) stops check-in for everyone already registered, with no warning. Either refuse the move while registrations exist, or show a warning in the confirm dialog. The current dialog says only "Attendees will no longer see this event, and registration closes."

### L5 — "Upcoming" window uses the device's local day

`FirebaseBackend.watchUpcomingEvents` computes start of today from the viewer's clock. Viewers in other time zones see a different list around midnight. Indonesia spans three time zones (WIB, WITA, WIT). Compute the boundary in WIB, the event's timezone, or document the simplification.

### L6 — Event banner and template files are publicly readable

`storage.rules` allows any reader for `events/{eventId}/*`. Banners are meant to be public. The certificate template is stored under the same path, so it is public too. If a template ever contains a signature or other sensitive content, move it to a private path.

---

## 6. Informational

- **I1 — Duplicated client concepts.** `EventTile` (organizer and committee) and `_AttendeeEventTile` (attendee) do almost the same job; `Member` and `Assignment` overlap. Consolidate in the M6 pass. No behavior risk.
- **Positive findings worth keeping:**
  - Deny-by-default in both rules files, with a test that unknown collections are closed.
  - Role and organization come only from ID-token claims. Clients cannot write `users/{uid}.role`.
  - Authorization decisions (invite, remove, registration, cancellation) are pure functions with unit tests, separate from I/O.
  - The QR implementation is cross-checked: Dart and Node produce the same signature for the same vector, and a QR from the release build verified against the server code.
  - Secrets (`.env`, service account JSON, real `env/*.json`) are git-ignored.

---

## 7. Known gaps not in scope of this audit

- Browser-level XSS and CSP: the web build is served by Firebase Hosting with default headers. Add a CSP before public launch.
- Dependency vulnerabilities: `npm audit` and `flutter pub outdated` were not run as part of this review.
- Penetration testing against a deployed project: not possible until the real Firebase project exists.
