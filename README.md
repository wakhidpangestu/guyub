# Guyub

All-in-one operations platform for community and campus event orchestration.
STACK 2026 (GDGoC ITB), Case 2: Stronger Communities and Everyday Services.

Every role (admin, organizer, committee, attendee) uses one Flutter Web app. The backend is Firebase: Auth, Firestore, Storage, and Cloud Functions. Local development runs entirely on the Firebase emulators, so no real Firebase project is needed.

Design and decisions: [`docs/SPEC.md`](docs/SPEC.md). Current state and next steps: [`docs/HANDOFF.md`](docs/HANDOFF.md).

---

## Quick start (Windows)

After the one-time [development setup](#development-setup-one-time):

```powershell
.\scripts\dev.ps1
```

The script builds Cloud Functions, opens the emulators in a second window, creates demo accounts on the first run, and starts the app in Chrome at http://localhost:8090.

In the app, click **Continue with Google** and pick a demo account.

If PowerShell refuses to run scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev.ps1
```

Options: `-Seed` recreates the demo accounts. `-NoApp` starts only the emulators.

### Demo accounts

Created by `npm run seed`. They appear in the emulator's Google account picker. No password needed.

| Account | Role | Organization | Opens |
|---|---|---|---|
| `admin@guyub.test` | admin | none | `/admin` |
| `organizer@guyub.test` | organizer | `himatif` | `/organizer` |
| `committee@guyub.test` | committee | `himatif` | `/committee` |
| `attendee@guyub.test` | attendee | none | `/attendee` |

Any new account you add in the picker starts as an attendee, unless an admin or organizer invited that email first.

The seed also creates demo data for `himatif`: three events (published with registration open, draft, completed) and `committee@guyub.test` assigned to the published one.

---

## Development setup (one time)

| Tool | Version | Why |
|---|---|---|
| Node.js | 22 or newer | Cloud Functions, Firebase CLI, scripts |
| Flutter | 3.47.9 stable | Web app |
| Java (JDK) | 21 or newer | Firestore and Storage emulators |
| Google Chrome | any recent | Running and debugging the web app |

### 1. Install the tools

**Node.js:** install the LTS from https://nodejs.org, or run `winget install OpenJS.NodeJS.LTS`.

**Flutter** (no admin rights needed):

1. Download `flutter_windows_3.47.9-stable.zip` from https://docs.flutter.dev/release/archive.
2. Extract it to `C:\Users\<you>\dev`, so you get `C:\Users\<you>\dev\flutter\bin\flutter.bat`.

**Java** (no admin rights needed):

1. Download the Temurin JDK 21 `.zip` for Windows x64 from https://adoptium.net/temurin/releases/?version=21.
2. Extract it to `C:\Users\<you>\dev`, so you get a folder like `C:\Users\<you>\dev\jdk-21.0.13+9`.

Alternatively, with admin rights: `winget install EclipseAdoptium.Temurin.21.JDK`.

### 2. Add Flutter and Java to your user PATH

Run once in PowerShell. Adjust the two folder names to match what you extracted:

```powershell
$flutter = "$env:USERPROFILE\dev\flutter\bin"
$jdk = "$env:USERPROFILE\dev\jdk-21.0.13+9"
$path = [Environment]::GetEnvironmentVariable('Path', 'User')
[Environment]::SetEnvironmentVariable('Path', "$path;$flutter;$jdk\bin", 'User')
[Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk, 'User')
```

Close and reopen the terminal, then check:

```powershell
node --version      # v22 or newer
flutter --version   # Flutter 3.47.9
java -version       # 21 or newer
```

### 3. Install project dependencies

From the repository root:

```powershell
npm install                     # Firebase CLI and the rules test kit (local, no global install)
npm --prefix functions install  # Cloud Functions dependencies
cd apps/dashboard; flutter pub get; cd ../..
```

---

## Daily development

### Option A: one command (Windows)

```powershell
.\scripts\dev.ps1
```

### Option B: by hand (any OS)

Use three terminals, all starting at the repository root.

1. **Emulators.** Leave this running.

   ```sh
   npm --prefix functions run build
   npm run emulators
   ```

2. **Demo accounts.** Needed only the first time, or after a reset.

   ```sh
   npm run seed
   ```

3. **App.**

   ```sh
   cd apps/dashboard
   flutter run -d chrome --web-port 8090 --dart-define-from-file=env/emulator.json
   ```

   In this terminal, press `r` to hot reload, `R` to hot restart, and `q` to quit.

### While you work

- **Emulator UI:** http://localhost:4000. Shows Auth users and their custom claims, Firestore documents, Storage files, and function logs.
- **Editing Cloud Functions:** run `npm --prefix functions run build:watch` in another terminal. The emulator reloads functions when the build output changes.
- **Editing security rules:** the emulators reload `firestore.rules` and `storage.rules` on save.
- **Saved data:** stop the emulators with **Ctrl+C** to save accounts and documents to `.emulator-data/`. The next `npm run emulators` loads them. Closing the window instead of pressing Ctrl+C does not save.
- **Reset everything:** stop the emulators, delete `.emulator-data/`, start again, and run `npm run seed`.
- **Change a role by hand:**

  ```sh
  npm --prefix functions run set-role -- --emulator --email someone@example.com --role organizer --org himatif
  ```

  Roles: `admin`, `organizer`, `committee`, `attendee`. Organizer and committee need `--org`. A missing org is created.

### Try the M1 flow

1. Start the stack. While signed out, open http://localhost:8090/organizer. You land on the login page.
2. Click **Continue with Google** and pick `organizer@guyub.test`. You land on `/organizer`, the page you asked for.
3. Open the account menu (top right) and choose **Sign out**. You are back on the login page.
4. Sign in as `attendee@guyub.test`. Type `localhost:8090/admin` in the address bar. You see **No access to this area**.
5. **Live role change.** Keep the app open as the attendee and run:

   ```sh
   npm --prefix functions run set-role -- --emulator --email attendee@guyub.test --role committee --org himatif
   ```

   Within a few seconds the app switches to the Committee dashboard without signing out. Undo it with `--role attendee`.

6. In the Google picker, choose **Add new account** and enter any email. The new account lands on the Attendee dashboard.

### Try the M2 flow

Run `npm run seed` first (or `.\scripts\dev.ps1 -Seed`) to get the demo events.

1. **Admin.** Sign in as `admin@guyub.test`. Open **Organizations** and click **New organization**. Type a name; the ID fills in by itself. Click **Create**.
2. On the new organization's page, add an organizer by email. Use an email that has never signed in, for example `new-organizer@example.com`. It appears under **Waiting for first sign-in**.
3. Sign out. Sign in with **Add new account** using that same email. You land straight on the Organizer dashboard: the invite was applied at first sign-in.
4. **Organizer.** Sign in as `organizer@guyub.test`. Open **Events**. You see the three demo events.
5. Click **New event**, fill in a title, and click **Create draft**. On the event page, click **Publish**, then **Open registration**.
6. Under **Committee for this event**, pick **Budi Committee** and click **Assign**.
7. Open **Committee** from the organizer home. Add a committee member by email, then remove them again.
8. **Committee.** Sign in as `committee@guyub.test`. **Your events** lists only the events Budi is assigned to. Opening `localhost:8090/organizer/events` shows **No access to this area**.

Rules to notice while testing:
- New events always start as drafts. Only drafts can be deleted.
- Registration can only be open while an event is published.
- **Mark completed** is final. It closes registration and locks check-in.
- An organizer only sees their own organization. A committee member only sees the events they are assigned to.
- Nobody is emailed about an invite yet. Tell the person to sign in with that Google account.

---

## Tests

| Command | What it checks | Needs |
|---|---|---|
| `npm --prefix functions test` | Role validation, invite and remove decisions (24 tests) | Node |
| `cd apps/dashboard; flutter test` | Routing, auth, every M2 page with a fake backend (85 tests) | Flutter |
| `npm run test:rules` | Firestore and Storage security rules (65 tests) | Java |
| `npm run test:smoke` | End-to-end on the emulators: sign-in, roles, invites, removal (14 tests) | Java |
| `npm test` | Functions, rules, and smoke tests together | Java |

`test:rules` and `test:smoke` start their own emulators from `firebase.test.json` on separate ports (19099, 18080, 15001, 19199). They never touch your dev emulators or their data, so you can run them while `npm run emulators` is up.

---

## Scripts reference

Root `package.json`:

| Script | Does |
|---|---|
| `npm run emulators` | Starts all emulators with saved data from `.emulator-data/` |
| `npm run emulators:fresh` | Starts all emulators with no data |
| `npm run seed` | Creates the demo accounts and the `himatif` organization |
| `npm test` | Runs functions, rules, and smoke tests |
| `npm run test:rules` | Runs security rules tests |
| `npm run test:smoke` | Runs the M1 end-to-end smoke test |

`functions/package.json`:

| Script | Does |
|---|---|
| `npm run build` / `build:watch` | Compiles TypeScript to `lib/` |
| `npm run set-role -- ...` | Sets a user's role (emulator or real project) |
| `npm run seed` | Same as the root `seed` |
| `npm test` | Unit tests |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `java` is not recognized, or the emulators say they could not spawn `java` | Install Java 21 (setup step 1) and open a new terminal. |
| Emulators fail with "port taken" on 8080, 9099, 5001, or 9199 | Another emulator is still running. Close it. To find it: `Get-NetTCPConnection -LocalPort 8080 \| Select-Object OwningProcess`, then `Stop-Process -Id <id>`. |
| App shows **Firebase is not configured** | Run with `--dart-define-from-file=env/emulator.json`. |
| Google popup does not open | Allow popups for `localhost:8090` in Chrome. |
| Blank page right after `flutter run` | The first debug start compiles for about a minute and then loads ~800 scripts. Wait 30 to 60 seconds. Later starts are faster. |
| Signed out after every `flutter run` | Expected. `flutter run -d chrome` opens a fresh Chrome profile each time. Pick the account again. |
| A role change does not show up | Open the account menu and choose **Refresh access**. Check the user's custom claims in the Emulator UI under Authentication. |
| Warnings `MetadataLookupWarning` or `node version "22" doesn't match` | Harmless for local development. |
| `npm run seed` says the Auth emulator is not reachable | Start the emulators first. |
| **Add organizer** or **Add committee member** spins for several seconds | The first call to a Cloud Function in the emulator starts it cold. Later calls are fast. |
| App still shows old screens after pulling new code | In the `flutter run` terminal press `R` (hot restart). The emulators reload rules and functions by themselves. |
| Organizer sees no events after updating | Run `npm run seed` again to add the demo events to existing emulator data. |

---

## Run against a real Firebase project

1. Create a Firebase project. Enable **Authentication > Google**, Firestore, and Storage.
2. Add a Web app in Project settings. Copy `apps/dashboard/env/example.json` to `apps/dashboard/env/dev.json` and fill in the values. Files in `env/` other than `emulator.json` and `example.json` are git-ignored.
3. Run `npx firebase login`, then `npx firebase use --add` and pick the project.
4. Create the first admin with a service account key:

   ```sh
   cd functions
   GOOGLE_APPLICATION_CREDENTIALS=path/to/key.json npm run set-role -- --project <project-id> --email you@example.com --role admin
   ```

5. Build and deploy:

   ```sh
   cd apps/dashboard && flutter build web --dart-define-from-file=env/dev.json
   cd ../.. && npx firebase deploy
   ```

---

## Repository layout

```
apps/dashboard/     Flutter Web app for all roles
  env/              Build-time config (emulator.json and e2e.json committed; real configs ignored)
  lib/auth/         Session state, Google Sign-In, role claims
  lib/data/         Models, the Backend interface, and its Firebase implementation
  lib/routing/      Router and the pure redirect rules
  lib/features/     One folder per role area, plus shared member management
  test/             Unit and widget tests (fake auth and fake backend in test/support)
functions/          Cloud Functions (TypeScript, Node 22, region asia-southeast2)
  scripts/          set-role and seed-emulator
tests/rules/        Security rules tests
tests/smoke/        End-to-end smoke tests on the emulators
scripts/dev.ps1     Windows dev launcher
firestore.rules     Firestore security rules
storage.rules       Storage security rules
firebase.json       Firebase config, emulator ports, hosting
firebase.test.json  Same, on separate ports for tests
docs/               Spec, handoff notes, abstract drafts
```

## Status

Implemented and verified on the emulators:
- Google Sign-In. Role and organization come from Firebase custom claims. New accounts are attendees.
- Role routing. Each role has its own area. Opening another role's area shows a "No access" page. Deep links survive sign-in.
- Live role change. When a role changes server-side, the open app moves to the new dashboard without signing out.
- Admin-only `setUserClaims`, `onUserCreated` profile creation, `set-role` and `seed` scripts.
- Firestore and Storage security rules: deny by default, scoped by organization and by event.
- **M2:** admin creates organizations and adds organizers by email. Organizer creates, edits, publishes, and completes events, opens and closes registration, adds committee members by email, and assigns them per event. Committee members see their assigned events. Invites for people who have not signed in yet apply at their first sign-in.

Not implemented yet (shown as "Planned" cards in the app): attendee registration, QR tickets, check-in, certificates, Sheets export, twibbon, platform metrics, landing page. See `docs/SPEC.md` §7.

Known limitations:
- Invites are not emailed. The organizer tells the person to sign in with that Google account.
- Organizations cannot be disabled yet.
- Event banners are not uploaded from the app yet.

## AI assistance disclosure

Required by the STACK 2026 handbook. Claude Code (Anthropic) was used to scaffold the repository and to write the security rules, Cloud Functions, auth and routing code, tests, dev scripts, and documentation. The team reviews, tests, and is responsible for all code.
