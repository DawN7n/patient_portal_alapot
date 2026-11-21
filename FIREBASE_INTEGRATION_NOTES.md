# Patient Portal — shared Firebase integration

Firebase project: `alapot-dental-clinic-5ea90`.

## Registration types

- **New Patient:** Email/password registration; Firebase's built-in email-verification link; after verification, a matching `users/{uid}` and new `patients/{PT-ID}` record are created atomically.
- **Existing Patient:** The patient enters the permanent Patient ID from the walk-in record. Firebase Auth verifies the email first; only after verification does the app submit `patientAccountLinkRequests/{uid}`. It does not create a new patient document.
- **Admin approval:** The Admin Portal checks the PT-ID against the original clinic record and requires the single applicant-identity confirmation checkbox, then links `users/{uid}` to the existing `patients/{PT-ID}`. Patients cannot read the clinic record before approval.

The app preserves interrupted existing-patient registration drafts and can resume an Auth identity that was created before the app closed. A cancelled or legacy rejected request can be resubmitted after correcting information. A mapped patient account must use Login instead of starting another registration.

## Email verification cost choice

This source uses Firebase Authentication's built-in email verification link, not a six-digit OTP. The new registration and account-link flows do not call Resend or Cloud Functions. Firebase email verification is a link, not a one-time numeric code.

## Rules

The shared rules source is `firestore.rules`. Identical copies are stored in the Admin and Dentist portal folders. Link requests require a verified Firebase Auth email claim, an existing unlinked patient record, and the exact Auth email. Do not publish rules without backing up the live rules and running the included rules test suite.

## Rebuild

The Patient Portal version is `1.1.2+4`. From this folder run:

```powershell
flutter pub get
flutter analyze
flutter build apk --release
```

The APK output is `build\app\outputs\flutter-apk\app-release.apk`.

## Current limitations

This account-link workflow has not been tested against the live Firebase project. Flutter build/analyze and Firestore Emulator tests were not run in the package-preparation environment because Flutter/Dart and Firebase CLI/emulators are not installed here. Other portal features such as full appointment, chart, file, messaging, notifications and payment synchronization require their own end-to-end verification. Cloud Storage is not required for this account-link feature.
