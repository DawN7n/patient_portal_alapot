# Shared Alapot AI backend

This folder is the single Groq proxy used by the Patient, Dentist, and Admin portals. It is a shared service, not a fourth portal.

## XAMPP folder layout

Place the three PHP folders side-by-side in `C:\xampp\htdocs`:

```text
C:\xampp\htdocs\
  admin_portal\
  dentist_portal\
  shared_backend\
```

Keep the Flutter project separately in `C:\patient_portal_alapot`. The public shared endpoint is:

```text
http://localhost/shared_backend/alapot-ai.php
```

Use HTTPS for a hosted/release deployment.

## Paste the Groq key in Admin

1. Revoke the earlier key shared in chat and create a replacement.
2. Sign in to Admin and open **Alapot AI → Connect Groq**.
3. Paste the replacement key and click **Save & test**.
4. The Admin endpoint validates the key with Groq and stores it server-side at `C:\xampp\alapot_private\groq-config.php`, outside the public `htdocs` directory. It does not save the key in Firestore or in frontend/mobile code.

The Dentist and Patient portals use this same server-side key; do not paste separate keys in those portals. If server file permissions prevent writing the config, configure `ALAPOT_GROQ_API_KEY` in the PHP server environment instead. `ALAPOT_GROQ_MODEL` is optional and defaults to `openai/gpt-oss-20b`.

PHP 8.1+ and the PHP cURL extension are required. The PHP process needs outbound internet access to `api.groq.com`.

## Role restrictions

- Patient AI provides portal and general oral-health education. It can save a support conversation to the existing `supportTickets` collection for staff follow-up.
- Dentist AI is question-and-answer only and cannot read or modify patient records, appointments, charts, consultations, or payments.
- Admin AI is question-and-answer only and cannot execute administrative record changes.

The shared endpoint verifies the Firebase ID token, role, active status, and (for patients) the patient-to-UID link. Do not send passwords, full government ID numbers, payment-card data, or unnecessary clinical details to the AI.

## Patient Flutter endpoint

The Patient app gets the endpoint URL at build time; the key itself is never passed to Flutter. From the Patient project folder:

```powershell
flutter pub get
flutter analyze
flutter build apk --debug --dart-define=ALAPOT_AI_API_URL=http://10.0.2.2/shared_backend/alapot-ai.php
```

`10.0.2.2` is the Android Emulator's route to the host computer. For a physical Android phone connected to the same Wi-Fi as the computer, use the computer's LAN IPv4 address instead, for example `http://192.168.1.20/shared_backend/alapot-ai.php` (replace the example address with the actual computer IP). The Android debug build manifest allows cleartext only for local testing. Do not use plain HTTP for a release/hosted build; use your HTTPS domain:

```powershell
flutter build apk --release --dart-define=ALAPOT_AI_API_URL=https://YOUR-HOST/shared_backend/alapot-ai.php
```

If you use a different XAMPP virtual host or folder path, update the endpoint accordingly. Confirm the shared PHP endpoint opens from the device's browser before testing in the app.

## Costs

The source uses Groq and Firebase's built-in email verification link. It does not integrate paid SMS OTP, Resend, a paid email vendor, Cloud Functions, or a payment gateway. Groq's free tier is subject to Groq's own limits; do not enable paid billing for this project just to make the integration work.
