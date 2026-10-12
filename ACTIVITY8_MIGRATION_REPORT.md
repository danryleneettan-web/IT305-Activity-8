# IT 305 Hands-on Activity 8 — CoopConnect migration report

## Application and migration design

The source system is the PHP/MySQL application in `Coop/`. The member profile is in `members`; related family rows are in `children` through `children.member_id`. Survey data is in `surveys`, `survey_questions`, `survey_choices`, `survey_submissions`, and `survey_answers` (Set B schema). Staff accounts are in `staff`.

The Firebase clients are `web_hosting/` and `coop_mobile/`. Both use Firebase Authentication for sign-in and the Realtime Database under `cooperative_portal/` for shared application data. New members can register with email/password; staff tools remain restricted to staff custom claims. The Android Flutter build is at `coop_mobile/build/app/outputs/flutter-apk/app-release.apk`.

## MySQL to Firebase mapping

| MySQL source | Firebase path / mapping |
| --- | --- |
| `staff` | `cooperative_portal/staff/{username}`; Auth email is `{username}@staff.coop-692bf.firebaseapp.com`, with custom claim `role: staff` |
| `members` | Migrated profiles stay at `cooperative_portal/members/{account_number}` with synthetic Auth emails; self-registered profiles use `cooperative_portal/members/{uid}` with a public account code and `authUid` link |
| `children` | Nested `members/{account_number}/children/child_{id}` |
| `surveys` | `cooperative_portal/surveys/survey_{id}` |
| `survey_questions` and `survey_choices` | Nested under each survey's `questions` map, preserving order, type, required flag, and choices |
| `survey_submissions` and `survey_answers` | `cooperative_portal/survey_submissions/{surveyId}_{memberUid}`; answers are nested by question ID |

`firebase_admin/migrate-mysql.mjs` implements a read-only dry run and an explicit `--apply` path. It ignores SQL password hashes, creates random temporary Firebase Auth passwords for new imported users, marks migrated member profiles for first-login password change, adds the staff custom claim, and writes new credentials to an ignored CSV for private handoff. The apply path merges survey/response data and preserves Firebase-only member profiles while stripping password fields.

## Security and validation

`database.rules.json` is deny-by-default at the root and has been deployed to the live Realtime Database. The staff custom claim grants cooperative administration access. Authenticated members can create/access only their UID-linked profile, read survey definitions, and create a response under their own UID only when the survey is active; a response key and `!data.exists()` prevent a second submission for the same survey. Passwords are never serialized to the Realtime Database by the updated clients.

The web and Flutter forms validate required survey answers; the web client also checks the survey schedule before showing and submitting a survey. These client checks improve the experience; final production verification should include emulator tests for unauthorized profile reads/writes, staff-only changes, and duplicate submissions.

## Verification performed

- Inline JavaScript in `web_hosting/index.html`, the Admin migration script, and the retired seeder pass Node syntax checks.
- `firebase.json` and `database.rules.json` parse as JSON.
- Flutter analysis completes with no errors. It reports existing deprecation and style info notices.
- A release Android APK built successfully (50.9 MB).
- The updated website was deployed to Firebase Hosting at [coop-692bf.web.app](https://coop-692bf.web.app/) and a fresh page load shows the repaired landing page and current sign-in copy.
- Public member registration appears in the live sign-in flow, and password-reset controls are present for email accounts. A live account was not created during verification.
- The release APK builds successfully. Firebase Hosting rejected its public upload because executable files are blocked on this project’s Spark billing plan; Android/iPhone users can install the public PWA from the website.

## External setup and remaining verification

The MySQL migration has not been applied because it needs the actual MySQL connection settings and a Firebase service-account key. New self-registered member accounts can use the live Firebase clients now; the legacy staff account and migrated member profiles still require provisioning. Live end-to-end registration, cross-device profile updates, and survey/report checks remain to be performed. A native public APK download also requires a hosting provider/plan that permits executable files; the PWA is publicly installable from the current site.

Capture the requested evidence after setup: staff and member screens, Firebase Auth users and custom claims, the RTDB tree, a cross-client profile/survey update, report totals, and a short demo video.
