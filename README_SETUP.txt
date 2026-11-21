ALAPOT DENTAL CLINIC — PATIENT PORTAL SETUP
==========================================

FIREBASE PROJECT
----------------
Project ID: alapot-dental-clinic-5ea90

REGISTRATION
------------
New patients:
- Register with email and password.
- Verify the email using Firebase Authentication's built-in email-verification link.
- The app then creates users/{Firebase UID} and patients/{PT-ID} in one Firestore batch.

Existing walk-in patients:
- Select Existing Patient and enter the permanent clinic Patient ID.
- Verify the email using Firebase Authentication's built-in verification link.
- The app submits patientAccountLinkRequests/{Firebase UID}; it does not create another patient document.
- Admin must verify the patient (or parent/legal guardian where applicable) and approve the link in Admin Portal > Clinic > Account Link Requests.
- After approval, the original patients/{PT-ID} record is linked to users/{Firebase UID}.

EMAIL VERIFICATION COST
-----------------------
This implementation uses Firebase's built-in verification link. It is not a six-digit OTP. Patient registration and account linking do not call Resend or Cloud Functions.

RUN / BUILD
-----------
From this folder:
  flutter pub get
  flutter analyze
  flutter build apk --release

APK:
  build\app\outputs\flutter-apk\app-release.apk

FIRESTORE RULES
---------------
The shared source is firestore.rules. Back up your currently deployed rules, run the included Firestore Emulator tests, review the changes, and only then publish them. Do not deploy a separate candidate rule file. Do not run a full Firebase deployment when you only intend to update rules.

From this folder, after tests and review:
  firebase deploy --only firestore:rules --project alapot-dental-clinic-5ea90

OPTIONAL CLOUD FUNCTION
-----------------------
The active functions/index.js contains only an optional automatic-receipt trigger. It is not needed for registration or account linking. Cloud Functions deployment requires an eligible billing plan; do not deploy it on Spark.

IMPORTANT
---------
No live Firebase rules or patient data are changed by this source package. The Patient Portal build and Firestore Emulator rules tests must be run in your own development environment before production rollout. The other portal features also need their own end-to-end verification.
