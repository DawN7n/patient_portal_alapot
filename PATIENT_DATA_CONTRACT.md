# Patient Portal — Shared Data Contract

The Patient Portal uses the same patient and clinic records as the Admin and Dentist Portals. Firebase is not connected in this phase; these paths and fields are the integration target.

## Shared patient document

`patients/{patientId}`

| Field | Type | Description |
|---|---|---|
| `id` | string | Human-readable patient number such as `PT-001` |
| `name` | string | Full name |
| `initials` | string | Avatar initials |
| `dob` | `YYYY-MM-DD` | Date of birth |
| `age` | number | Derived from DOB |
| `gender` | string | Gender |
| `phone` | string | Contact number |
| `email` | string | Email address |
| `address` | string | Home address |
| `registered` | `YYYY-MM-DD` | Registration date |
| `status` | `Active` / `Inactive` | System-derived by the clinic |
| `last_visit` | `YYYY-MM-DD` or null | Most recent completed clinic visit |
| `blood_type` | string | Blood type, if recorded |
| `allergies` | string | Known allergies |
| `medical_notes` | string | Clinic-maintained medical notes |

The Patient Portal may let a patient edit only approved contact/profile fields. It must not let a patient edit `status`, `last_visit`, `blood_type`, `medical_notes`, dentist notes, diagnosis, dental chart conditions, or consultation records.

## Shared related collections

- `appointments/{appointmentId}` — `id`, `patient_id`, `patient`, `dentist_id`, `dentist`, `service`, `date`, `time`, `duration`, `status`, `notes`.
- `dentalCharts/{patientId}` — tooth-number keys (`11`–`48`) and recorded condition values.
- `dentalChartHistory/{patientId}/teeth/{toothNumber}/entries/{entryId}` — `appointmentId`, `condition`, `date`, `dentistName`, `diagnosis`, `treatmentPlan`, `consultationNote`.
- `patientFiles/{patientId}/files/{fileId}` — `name`, `type`, `format`, `date`, `size`, `storagePath`.
- `consultations/{appointmentId}` — `appointmentId`, `patientId`, `patientName`, `dentistId`, `dentistName`, `date`, `consultationNote`, `diagnosis`, `treatmentPlan`, `dentalChart`, `files`.
- `prescriptions/{prescriptionId}` — `patientId`, `appointmentId`, `dentistId`, `medicationName`, `dosage`, `frequency`, `duration`, `instructions`, `issuedAt`. This is a reserved patient-facing record shape; the current Dentist Portal does not yet provide a prescription-entry workflow.
- `payments/{paymentId}` — `patientId`, `appointmentId`, `amount`, `currency`, `method`, `status`, `paidAt`, `referenceNumber`.
- `receipts/{receiptId}` — `patientId`, `appointmentId`, `receiptNumber`, `issuedAt`, `items`, `subtotal`, `discount`, `total`, `paymentStatus`, `storagePath`.
- `announcements/{announcementId}` — published clinic announcement fields.
- `supportTickets/{ticketId}` and `supportTickets/{ticketId}/messages/{messageId}` — patient support queue and replies.

## Patient-facing permissions

- Patient can read only their own patient document, appointments, chart, history, consultations, files, payments, receipts, and support tickets.
- Patient can request appointment cancellation/rescheduling; the clinic controls the final appointment status.
- Patient can create reviews only for eligible completed appointments. `isAnonymous` determines whether their display name is shown publicly.
- Patient can create support tickets and read/reply only to their own tickets.
- Dentist controls clinical records and dental chart updates.
- Admin controls clinic settings, published services, payment/receipt records, announcements, and patient administration.
- Patient cannot change the system-derived Active/Inactive status.

## Patient activity status

Use the same rule as Admin and Dentist: Active when the latest completed clinic visit is within the previous two calendar months. If there is no completed visit, use registration date as the baseline. Pending, upcoming, cancelled, and no-show appointments do not reset the activity period.

## Chatbot

The Patient Portal's Alapot assistant is currently a local FAQ-style preview. A future `PatientAssistantPortalRepository` should call a secured server-side AI endpoint; the backend must derive patient identity from authentication and retrieve only that patient's authorized records. The Admin support queue should receive support tickets and messages. The chatbot must not diagnose, prescribe, change clinical records, or claim that a ticket/booking/payment was saved unless the backend confirms it.


## Existing walk-in patient account linking

- Existing clinic records remain at `patients/{PT-ID}`; linking must never create a second patient document.
- The patient creates a Firebase Authentication email/password account and verifies the email using Firebase's built-in verification link.
- Only after the Firebase token reports `email_verified == true` may the Patient Portal create `patientAccountLinkRequests/{uid}`.
- A request stores `patient_id`, `requester_uid`, `requester_email`, `requester_name`, `phone`, `email_verified: true`, `verification_method: firebase-email-link`, `status: Pending`, and `createdAt`.
- Admin checks the PT-ID against the original patient record, confirms the applicant identity using the approval checkbox, and records the PT-ID handover method/date and review note.
- Approval creates `users/{uid}` and updates the existing `patients/{PT-ID}` and request document in one atomic Firestore commit with document-version preconditions.
- Approval is blocked if the patient record is already linked, inactive, or not in the `no-app-account` state. If the stored email differs, Admin must explicitly confirm that the identity and email change were verified; the verified request email is then written to the existing record.
