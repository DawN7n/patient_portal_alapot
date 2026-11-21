// Optional Cloud Function: automatic receipts for Patient Portal appointments.
// Patient registration and existing-patient linking do NOT use Cloud Functions.
// The free Firebase email-verification link is handled directly by Firebase Auth.

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

initializeApp();
const db = getFirestore();
const REGION = "asia-southeast1";

// ============================================================
// AUTOMATIC RECEIPT FOR PATIENT-APP APPOINTMENTS
// ============================================================

exports.createReceiptForPatientAppointment = onDocumentCreated(
  {
    document: "appointments/{appointmentId}",
    region: REGION,
  },
  async (event) => {
    const appointmentId = event.params.appointmentId;
    const appointment = event.data?.data();

    if (!appointment) {
      console.warn("Appointment data is missing:", appointmentId);
      return;
    }

    // Only Patient Portal bookings generate automatic receipts.
    if (
      appointment.source !== "patient-app" &&
      appointment.booking_source !== "patient-app"
    ) {
      return;
    }

    const patient = String(
      appointment.patient || appointment.patient_name || ""
    ).trim();

    const patientId = String(appointment.patient_id || "").trim();
    const patientUid = String(appointment.patient_uid || "").trim();
    const patientDocId = String(appointment.patient_doc_id || "").trim();
    const service = String(appointment.service || "").trim();
    const dentist = String(appointment.dentist || "").trim();
    const method = String(appointment.payment_method || "").trim();
    const amount = Number(appointment.amount);
    const date = String(appointment.date || "").trim();

    if (
      !patient ||
      !patientId ||
      !patientUid ||
      !patientDocId ||
      !service ||
      !dentist ||
      !date ||
      !Number.isFinite(amount) ||
      amount <= 0 ||
      !["Cash", "GCash", "Bank Transfer", "Card"].includes(method)
    ) {
      console.error(
        "Patient appointment is missing valid receipt information:",
        appointmentId
      );
      return;
    }

    const receiptId = `RCT-${appointmentId}`;
    const appointmentRef = db.collection("appointments").doc(appointmentId);
    const receiptRef = db.collection("receipts").doc(receiptId);

    await db.runTransaction(async (transaction) => {
      const [appointmentSnapshot, receiptSnapshot] = await Promise.all([
        transaction.get(appointmentRef),
        transaction.get(receiptRef),
      ]);

      if (!appointmentSnapshot.exists) {
        return;
      }

      // Never overwrite an existing receipt or its payment status.
      if (receiptSnapshot.exists) {
        const existingReceipt = receiptSnapshot.data();

        transaction.update(appointmentRef, {
          receipt_id: receiptId,
          receipt_status: existingReceipt.status || "Pending",
          receipt_updated_at: FieldValue.serverTimestamp(),
        });

        return;
      }

      const now = FieldValue.serverTimestamp();

      transaction.create(receiptRef, {
        id: receiptId,
        appointment: appointmentId,
        appointment_id: appointmentId,

        patient,
        patient_id: patientId,
        patient_uid: patientUid,
        patient_doc_id: patientDocId,

        service,
        dentist,
        amount,
        date,
        method,

        status: "Pending",
        reference: "",
        notes: String(appointment.notes || ""),

        source: "patient-app",
        auto_generated: true,
        payment_method_id: String(
          appointment.payment_method_id || ""
        ),

        createdAt: now,
        updatedAt: now,
      });

      transaction.update(appointmentRef, {
        receipt_id: receiptId,
        receipt_status: "Pending",
        receipt_updated_at: now,
        updatedAt: now,
      });
    });

    console.log(
      `Automatic Pending receipt processed for appointment ${appointmentId}`
    );
  }
);
