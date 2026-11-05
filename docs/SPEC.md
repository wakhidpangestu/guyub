# Guyub — Engineering Spec (working draft)

Source of truth for the build. Derived from:
- `Guyub Full Project Proposal & Architecture Document.pdf`
- `Guyub Hackathon Abstract Submission.pdf`
- `Handbook STACK 2026.pdf`

Items marked **DECIDE** need an owner decision. Each has a recommended default so work can continue.

## 0. Decision log (locked)

| # | Topic | Decision | Implication |
|---|---|---|---|
| 1 | Twibbon | Client-side Canvas composite: event PNG overlay on top of the user's photo, exported as PNG/JPEG. No server storage, no Cloud Function. | Overlay asset lives in `events/{eventId}/` in Storage. The attendee's photo is never uploaded. |
| 2 | Google ecosystem | Google Sign-In via Firebase Auth (1-tap). Email via Firebase "Trigger Email" extension (SMTP) or Nodemailer in Cloud Functions. Export registrations and attendance to Google Sheets from the Organizer dashboard. | Gmail SMTP is rate-limited, so QR and certificate emails need batching. Sheets export needs a Google OAuth scope; choose service account vs user OAuth at implementation time. |
| 3 | Committee scope | Per event. Enforced by `events/{eventId}/committees/{uid}`. | A committee member cannot scan events they are not assigned to. |
| 4 | Payments | Phase 1 is free events only. | No payment gateway. IDR 149k and commission tiers are deferred. |
| 5 | Check-in mode | Online only, through Firestore realtime listeners. | Venue network is a demo risk. List it in the proposal risks. |
| 6 | Privacy (UU PDP) | Privacy notice and consent toggle on the registration form (`privacy_consent`, `consent_at`). 12-month retention. | Scheduled purge of attendance older than 12 months after event end (**TODO**). |
| 7 | Development period | 1-week core MVP sprint covers M0–M4. Time until 16 Dec goes to UI polish (glassmorphism), testing, and demo video. | §7 milestones follow this split. |
| 8 | Abstract | Finalize and lock by 10 Nov 2026, 23:59 WIB. Align with decisions 1 and 2. | Abstract PDF needs a revision (**TODO**). |
| 9 | Node runtime | Cloud Functions runtime is Node 22, matching `firebase.json`. `engines` stays `22`. Local Node 24 only produces an EBADENGINE warning. | Install Node 22 locally (nvm) to silence the warning. |

---

## 1. Scope (phase 1)

- Web-only. Every role uses the Flutter Web app (`apps/dashboard`).
- Public landing page (`apps/landing`, Next.js) is built last.
- Mobile builds are out of scope until phase 2.
- Integrated with the Google ecosystem (see §8).

## 2. Roles and permissions

| Role | Created by | Scope | Can do |
|---|---|---|---|
| `admin` | Bootstrap script (first admin, see §9) | Platform | Create organizations, create/disable organizer accounts, view platform metrics |
| `organizer` | Admin | One `orgId` | Create/edit/publish events, invite committees, set certificate template, view attendance |
| `committee` | Organizer (of same org) | One `orgId`, assigned to specific events | Log in, scan attendee QR, flip `is_checked_in`. Nothing else |
| `attendee` | Self sign-up | Global | Browse active events, register, view own QR ticket and certificates |

Rules:
- Claims are the only source of role. Firestore and Storage rules read `request.auth.token.role` and `orgId`.
- A user without a `role` claim is an attendee. Rules use `token.get('role', 'attendee')`; the app uses `UserRole.fromClaim`.
- After a role change, `applyRole` mirrors the role into `users/{uid}`. The app compares that with the ID token's claims and refreshes the token when they differ, so the new dashboard opens without signing out. Comparing values also catches a role applied before the app subscribed (an invite at first sign-in).
- Clients never write claims or `users/{uid}.role`. Only Cloud Functions (Admin SDK) do.
- A committee account belongs to exactly one org. It can scan only events it is assigned to (locked, §0 decision 3).

## 3. Data model (v2)

Changes from proposal v1 are marked **NEW** or **CHANGED**.

```
organizations/{orgId}                  NEW  (document ID = slug, never changes)
  name, slug, status ("active"), created_by, created_at

users/{uid}                            written only by Cloud Functions
  role, organization_id, display_name, email, created_at, updated_at
  (mirrors the custom claims; rules read it to check committee assignees)

invites/{email}                        NEW (M2)  written only by inviteMember
  email (lowercase), role ("organizer"|"committee"), organization_id,
  invited_by, created_at
  (one pending invite per email; consumed by onUserCreated at first sign-in)

events/{eventId}
  organization_id                      NEW (required for rules)
  title, description, date (timestamp), location
  status: "draft" | "active" | "completed"
  banner_url                           NEW
  certificate_template_url
  registration_open: boolean           NEW
  capacity: number | null              NEW
  registered_count: number             NEW (M3) written only by Cloud Functions
  created_by, created_at, updated_at

events/{eventId}/committees/{uid}      NEW  (committee assignment)
  uid (for collection-group queries), organization_id,
  display_name, email (denormalized for lists), assigned_by, assigned_at

attendance/{attendanceId}              (ID = `${eventId}_${uid}`)  CHANGED: deterministic ID
  event_id, user_id, organization_id   NEW
  attendee_name                        NEW (M3) name only; no email (audit M1)

attendance_secrets/{attendanceId}      NEW (M3, audit H2) owner-read-only, Cloud Functions write
  user_id, event_id, qr_token (random secret that signs the rotating QR, see §5), created_at
  is_checked_in, checked_in_at, checked_in_by   NEW
  certificate_issued, certificate_url  NEW
  registered_at                        NEW
  privacy_consent: boolean             NEW (must be true to register)
  consent_at: timestamp                NEW

certificates/{eventId}/{uid}           (Storage path, not Firestore)
```

Notes:
- Deterministic attendance ID makes double registration impossible.
- `organization_id` is duplicated on attendance so rules do not need an extra `get()` on every read.

## 4. Key flows

**Adding people by email (M2)** — same flow for admin to organizer and organizer to committee
1. Admin creates the org (`organizations/{slug}`) from the dashboard.
2. Admin (organizer) enters a Google account email. The app calls `inviteMember`.
3. If an account exists, the role applies now (`granted`). Otherwise `invites/{email}` is stored (`invited`).
4. At first sign-in, `onUserCreated` applies the invite and deletes it. The app sees the profile role differ from the token and refreshes it, so the person lands on the right dashboard without signing in again.
5. Guards (`decideInvite`): organizers add committee to their own org only; nobody changes an admin; a member of another org must be removed there first; an organizer cannot demote a fellow organizer.
6. `removeMember` returns the person to attendee and deletes all their committee assignments.

Not built: invite emails. The inviter tells the person to sign in.

**Event lifecycle**
`draft` → `active` (published, visible to attendees) → `completed` (after event date; locks check-in).

**Attendee registration (M3)**
1. Attendee signs in with Google and browses published events from today on (all orgs).
2. On an event, the attendee clicks Register. A privacy notice (what is shared with whom, 12-month retention, cancellation) must be accepted with a checkbox.
3. The app calls `registerForEvent({eventId, privacyConsent: true})`. In one transaction the function checks consent, attendee role, status, open registration, and capacity; creates `attendance/{eventId}_{uid}` with a random `qr_token`; and increments `registered_count`. Registering twice returns the existing ticket.
4. The ticket page shows the rotating QR (§5).
5. `cancelRegistration` deletes the ticket and frees the spot, until check-in and while the event is not completed.

Clients cannot create attendance at all (rules: `allow create: if false`). Only attendee accounts register. An organizer or committee member cannot attend another org's event with the same account (known limitation).

**Check-in (committee)**
1. Committee scans QR. The app sends the payload to a `checkIn` callable (M4), which runs `verifyTicket` against the stored `qr_token` and the committee member's assignment.
2. The function sets `is_checked_in = true`, `checked_in_at`, `checked_in_by`. M4 removes the current client-side update rule, so check-in cannot skip the QR check.
3. Cloud Function `onAttendanceCheckedIn` (phase 1 milestone) issues certificate and emails it.

**Certificate**
Generated from `certificate_template_url` with the attendee's name. Stored at `certificates/{eventId}/{uid}.pdf`. Only the owner can read it.

## 5. QR design

Dynamic QR, built in M3 (`functions/src/tickets.ts`, `apps/dashboard/lib/data/ticket_code.dart`):

- Each registration has a random 128-bit `qr_token`, created by `registerForEvent` in `attendance_secrets/{attendanceId}`. Only the ticket owner can read it. Organizers and committee read `attendance` but never the key, so they cannot mint tickets (audit H2).
- The QR shows `G1.{attendanceId}.{window}.{signature}`, where `window = floor(unix seconds / 30)` and `signature` = first 16 hex chars of HMAC-SHA256(key = `qr_token`, message = `{attendanceId}.{window}`).
- The code changes every 30 seconds. Check-in accepts windows within ±2 of the server clock, so a screenshot stops working after about a minute.
- Dart and Node implementations are tested against the same vector (cross-checked with `openssl`). A QR decoded from the release web build was verified by the server code: valid at the time, expired two minutes later, invalid with another token.
- No server secret is needed: the per-ticket token is the key, and only its owner and Cloud Functions can read it.
- Check-in is online only (locked, §0 decision 5).

## 6. Security checklist

- [ ] Firestore rules deny by default (done in `firestore.rules`).
- [ ] Storage rules deny by default and enforce size and content type (done in `storage.rules`).
- [ ] Claims set only by Admin-gated callable (done in `functions/src/index.ts`).
- [ ] No secrets committed. `.gitignore` covers `.env`, service accounts.
- [ ] Rules unit tests with Firebase emulator (**TODO**).
- [ ] Privacy notice and data retention for attendee personal data (**TODO**, see §10.6).

## 7. Milestones (from proposal, adjusted)

M0–M4 is the 1-week core MVP sprint. M5–M6, polish, and the demo video run until 16 Dec (§0 decision 7).

Status: M0 to M3 done and verified end-to-end on the emulators (`npm run test:smoke`, plus browser runs of every write path). Next: M4.

| Milestone | Content | Exit criterion |
|---|---|---|
| M0 | Repo, Firebase project, emulators, rules, functions skeleton | `firebase emulators:start` runs; rules tests pass |
| M1 | Flutter Web shell: auth, role routing, empty dashboards | Each role lands on its own screen; wrong role is blocked |
| M2 | Organizer: org/event CRUD, committee assignment | Event created and published from UI |
| M3 | Attendee: browse, register, QR ticket | Attendee sees QR for registered event |
| M4 | Committee: QR scanner, check-in | Check-in updates attendance in realtime on a second device |
| M5 | Certificate function + email | Check-in triggers certificate email |
| M6 | Landing page (Next.js), deploy | Public site and dashboards reachable |

## 8. Google ecosystem integration

Locked in §0 decision 2. Details:

- **Sign-in**: Firebase Auth, Google Sign-In as the primary 1-tap option. Email/password is not needed for phase 1.
- **Email**: Firebase "Trigger Email" extension (SMTP) or Nodemailer in Cloud Functions, for QR tickets and certificates. Batch sends. Watch Gmail daily send caps.
- **Export**: Organizer exports registrations and attendance to Google Sheets. Sheets API call is made from a Cloud Function or the client; auth model is decided at implementation time.
- **Calendar**: "Add to Google Calendar" link on the event page. Optional, low effort.
- **Hosting**: Firebase Hosting for Flutter Web, Vercel for landing (proposal).

## 9. Bootstrap

- First admin is created by a one-off script run with a service account, not through the UI.
- Script: `functions/scripts/set-role.mts` (`npm run set-role`). Works against the emulators (`--emulator`) or a real project (`--project`). See README.

## 10. Open decisions and gaps

Proposal does not cover these. Items 1–6 and 8 are now locked as recorded in §0. Each entry below keeps its original reasoning for history.

1. **Twibbon feature.** The user brief mentions twibbon as a feature. Proposal does not describe it. Need: what it does (profile-picture frame? event-specific overlay?), who uploads templates, and whether it lives in the app or only in marketing. **Default**: event-specific PNG overlay, attendee uploads photo in browser, canvas composites it, result downloads locally. No server storage.
2. **AI proposal generator.** Proposal lists it for organizers. Provider and cost not chosen. Handbook says AI is optional but must be disclosed. **Default**: Gemini API, called from a Cloud Function, behind a feature flag.
3. **Committee scope.** Is a committee member assigned per event, or per org (all events)? **Default**: per event.
4. **Payments.** Event Pass (IDR 149k) and 5–8% commission imply a payment gateway. Not chosen. **Default**: out of scope for phase 1. Free events only.
5. **Offline check-in.** Venues often have bad network. **Default**: online only in phase 1. Document the risk in the proposal.
6. **Personal data.** Attendee name, email, and attendance are personal data under Indonesia's PDP Law (UU 27/2022). Need a privacy notice, retention period, and deletion path. **Default**: 12-month retention, deletable from account page.
7. **Admin bootstrap.** Covered in §9.
8. **Development period mismatch.** Resolved in §0 decision 7. Proposal says "1-week sprint". Handbook timeline runs 10 Nov → 16 Dec. Confirm which applies to the build plan. **Default**: build to M4 by the semifinal, M6 by Final Day.
9. **Declaration of Originality and AI disclosure.** Handbook requires both in the semifinal proposal and the product README. Not yet drafted.
10. **Abstract deadline.** Handbook: 10 Nov 2026 (23:59 WIB). Abstract must be 300–500 words, English, PDF. The existing abstract draft is ~375 words; check it still matches this spec after decisions above.

## 11. Handbook constraints to keep in mind

- English for all written submissions, video, and pitch.
- Team of 3–4 members, one leader.
- Planned features must not be presented as done. Mock or simulated behavior must be labelled.
- Starting repo is kept for Final Day. Do not restart from empty.
- Demo must have reachable deployment or reliable local setup. Web: deployment preferred.
