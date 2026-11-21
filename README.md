# Alapot Dental Clinic — Patient Portal (refined)

Responsive Flutter patient portal for Android and Web. The existing visual style and color palette have been retained while the requested patient-side UI and navigation changes were added.

## Run locally

```bash
flutter pub get
flutter run
```

## Changes in this revision

- Registration now includes a calendar date picker, Male/Female dropdown, email-format validation, and a fixed `+63` phone prefix with grouped digits.
- Login and registration headings/buttons were simplified. Switching between the forms clears old validation state.
- Splash routing now chooses onboarding for a first launch and login for returning users.
- Dashboard greeting text was removed while retaining the overview content card and remaining sections.
- Appointment status filters are smaller, fit on one row, and do not show checkmarks.
- Profile now includes editable personal and emergency-contact fields, allergies, dentist-only medical notes, payment-method entry, and security shortcuts.
- My dental records now mirrors the Admin/Dentist patient profile tabs: Overview, Dental Chart, Dental History, and Files.
- Submitted reviews can be opened to view their details; the review-star selector was made narrower.
- Added Messages, a direct Alapot AI sidebar entry, and Firestore-backed support requests.
- Dentist profiles now offer both booking and messaging actions.
- Clinic information now includes the requested clinic description, contact fields, clinic-hours section, and the existing pre-appointment instructions.
- The mobile and Android back actions navigate to the previous portal screen instead of exiting from the root screen.
- Logout now asks for confirmation.
- Top bar now shows the clinic name and notifications only.

## Firebase integration status

This source is configured for the shared Firebase project `alapot-dental-clinic-5ea90`. Firebase Authentication and Firestore are used by the authentication flow and `PatientPortalRepository`. Patient Portal registration requires a permanent Patient ID issued by clinic Admin after identity verification. The patient creates a Firebase email/password account, verifies the email using Firebase’s built-in verification link, and submits a link request. Admin approval connects `users/{uid}` to the existing `patients/{PT-ID}` record. The Patient Portal never creates a clinic patient record or generates a Patient ID.

Existing walk-in patient registration now uses a separate verified-email step. After Firebase confirms the email is verified, the app writes `patientAccountLinkRequests/{uid}`. The Admin Portal reviews and approves the request before the Patient Portal can access the existing clinic record.

Not every feature should be considered production-complete solely because Firebase Auth and Firestore are configured. Support/assistant preview behavior, file-byte storage, and payment processing require their own live backend/provider implementation and security review. GCash and bank payment methods must not be treated as completed transactions, and raw payment credentials must not be stored in the app.

Clinic email, phone, address, social links, website, map link, full opening hours, and official description must be verified by the clinic before release.

## Project structure

Feature screens are grouped under `lib/features/` by feature. The patient navigation shell is in `lib/features/shell/`, startup and onboarding screens are in `lib/features/startup/`, and authentication screens are in `lib/features/auth/`. Shared widgets are in `lib/shared/widgets/`; theme definitions and persistence are in `lib/core/theme/`. Models, sample data, and repository contracts are in `lib/models/` and `lib/data/`.

## Refined patient portal updates
- Added a dedicated patient profile information screen and moved account preferences to the sidebar's bottom Settings item.
- Added a top-bar account menu with profile, persistent light/dark theme switching, and logout.
- Theme definitions and the persisted theme controller are organized in `lib/core/theme/`.
- Messages now keep separate in-memory conversations for each dentist and a separate clinic-support ticket conversation.
- Appointment booking now has five stages, a payment-method selection stage, an approval-gated online-payment option, and a submission loading state.
- Added page transitions, simplified clinic information, compact review stars, and a slimmer sidebar.

Current data policy: live clinic and patient records are read from Firestore. When a collection is empty, screens should display an empty state rather than fabricated sample records. Online payment is not a completed payment gateway integration and must not be presented as paid unless the clinic records a confirmed payment.


## Startup flow and folder cleanup

- `main.dart` initializes Flutter and loads saved preferences before starting the app.
- `app.dart` applies the saved light/dark theme and opens the startup screen.
- `features/startup/startup_screen.dart` displays the splash screen, then routes to onboarding or login based on the saved `onboarded` preference.
- `features/startup/onboarding_screen.dart` saves the same `onboarded` preference before opening authentication.
- Removed unused duplicate startup/authentication flow files and an unused placeholder patient shell to avoid maintaining competing implementations.
- Moved the active patient shell into `features/shell/` so navigation is separate from the dashboard screen.


## Patient-side alignment with Admin and Dentist portals

The latest refinement mirrors the shared clinic record areas used by the Admin and Dentist portals:

- **My dental records** now has Overview, Dental Chart, Dental History, and Files tabs.
- Overview shows medical information, recent appointment activity, and completed treatments.
- Dental Chart shows the 32 permanent-tooth positions and clearly marks them as unrecorded until a dentist saves clinical findings. The patient view is read-only.
- Dental History includes appointment statuses and consultation/treatment-plan area. A read-only prescriptions section is reserved for future use; the current Dentist Portal does not yet have a prescription-entry workflow, so no prescription is fabricated.
- Files includes the patient documents/imaging area and official receipt documents.
- **Payments & receipts** now has a dedicated read-only screen. It displays an honest empty state until the clinic records payments and issues receipts.
- Patient Profile now includes blood type and dentist-maintained medical notes as read-only fields.
- Alapot AI is directly accessible from the sidebar and Help Center. It answers portal questions about appointment status, dental records, prescriptions, payments, clinic services, dentist profiles, clinic information, and general oral-care guidance. It includes safety guidance and cannot diagnose or prescribe.
- Clinic dentist and service preview catalogue values now match the Admin Portal's directory.
- Added a Patient Data Contract covering the shared patient document, appointments, dental chart/history, consultation records, patient files, payments, receipts, announcements, and support tickets.
- Expanded the patient model and repository interfaces for the shared Admin/Dentist/Patient field names.

## Remaining verification and preview limitations

Alapot AI currently provides local, curated FAQ guidance and support-request creation; it is not a remote generative-AI service. Displayed payment methods are clinic-configured options and do not represent completed gateway transactions. Patient file metadata and actual file bytes must be stored through a secure file-storage solution before production file upload is enabled.

Do not seed mock patients, appointments, reviews, clinical notes, payments, or notifications into production. Firestore Security Rules must restrict each patient to their own records. Clinical notes, diagnosis, dental chart, prescriptions, payment confirmation, and Active/Inactive status must remain controlled by authorized clinic roles.
