# CoopConnect Firebase setup and migration

This repository contains the original PHP/MySQL portal in `Coop/`, the Firebase-hosted web app in `web_hosting/`, and the Flutter client in `coop_mobile/`. The hosted site and Flutter app use the same Firebase Authentication accounts and Realtime Database project (`coop-692bf`).

## Firebase data layout

All application data is under `/cooperative_portal`:

```text
cooperative_portal/
  staff/{username}                 staff display profile (no password)
  members/{uid or accountNumber}    member profile, authUid, forcePasswordChange
  surveys/{surveyId}                survey metadata and question definitions
  survey_submissions/{surveyId_uid} one response per member and survey
```

Passwords belong to Firebase Authentication only. Publicly self-registered member profiles are stored under their Firebase UID and retain a `PUBLIC-...` cooperative account number; migrated legacy member profiles stay under their existing account number. Staff accounts require the Firebase custom claim `role: "staff"`; the migration utility assigns that claim through the Admin SDK. Members can read active survey definitions and only their own profile and responses. Staff can manage cooperative data and view aggregate reports.

## One-time setup

1. In Firebase Console for `coop-692bf`, enable **Authentication → Sign-in method → Email/Password** and verify Realtime Database is provisioned at the URL configured in `firebase.json` and the web/mobile clients. Visitors can then select **Create a member account** and register with their email; staff access remains staff-only.
2. Create a Firebase service account with permission to manage Authentication users and Realtime Database. Store its JSON key outside this repository and set `GOOGLE_APPLICATION_CREDENTIALS` to that file path. Never commit the key.
3. Start the original MySQL database and configure environment variables in the terminal (do not put the password in source control): `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_DATABASE`, `MYSQL_USER`, and `MYSQL_PASSWORD`.
4. From `firebase_admin/`, install the package dependencies with `npm install`.
5. Run `node migrate-mysql.mjs` first. This is a read-only dry run and prints source row counts. Review the source counts and ensure the MySQL database is the correct activity database.
6. Run `node migrate-mysql.mjs --apply` when ready to import the legacy records and provision staff. It creates Firebase Auth users for source records that do not already have accounts, applies the staff custom claim, imports profiles/surveys/responses, and writes generated first-login credentials to the ignored `firebase_admin/migration-credentials.csv`. Deliver those credentials privately, then securely delete the file. Existing Firebase-only profiles are preserved, with password fields removed, but need UID/account provisioning before members can sign in.
7. New members can register themselves from the web or Flutter app with an email/password and can use that email to sign in from other devices. The rules are already deployed to allow each signed-in member to access only their linked profile. Members migrated from MySQL use staff-issued account codes and must change their generated temporary password at first sign-in.
8. After the legacy import, confirm staff can sign in to both clients and migrated member accounts are linked to their profiles. The site is deployed with `firebase deploy --only hosting`; re-deploy database rules only if you intentionally change `database.rules.json`.

The migration uses Admin SDK credentials and does not rely on open/test-mode database rules. The legacy `seed_to_firebase.js` public-write seeder has been retired. Do not use an unauthenticated JSON import to replace the production data tree. Email/Password authentication is required for registration; enable it in the Firebase Console if sign-up reports `OPERATION_NOT_ALLOWED`.

## Run and build

- Web: `firebase emulators:start --only hosting,database,auth` for local integration work where the Firebase emulators are configured; hosted production URL is `https://coop-692bf.web.app/`.
- Flutter: from `coop_mobile/`, run `flutter pub get`, then `flutter run`; Android package builds with `flutter build apk --release`. iOS builds require macOS and Xcode.
- PHP/MySQL legacy: follow `Coop/README.md`; it remains the migration source, not the Firebase-hosted client.

## Verification checklist for the activity

- Staff sign-in works on web and mobile; a non-staff account cannot open staff tools.
- A visitor self-registers on web and mobile with email/password, signs in on another device, and receives only their own member profile.
- Create/edit a member, survey, and question in one client, then sign in to the other client and confirm the same data appears.
- Submit a survey as a member; confirm it appears in staff Reports with response totals and percentages.
- Confirm members cannot read another member profile or another member's response, and cannot write staff/survey records.
- Confirm missing required answers are rejected by the clients; document the database rule/emulator checks used for security.
- Capture screenshots of both clients, Firebase Authentication users and the Realtime Database structure. Record a short screen video showing cross-client update and report refresh.

## Activity report template

Document the original MySQL tables and relationships; Firebase tree and field mappings; Auth/RTDB architecture; the tested staff/member flows; security rule results; screenshots/video links; and any remaining Firebase Console setup. Do not report tests as passed until performed against the emulator or deployed project.
