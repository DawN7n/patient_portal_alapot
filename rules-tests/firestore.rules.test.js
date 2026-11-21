import { after, test } from "node:test";
import { readFileSync } from "node:fs";

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";

import {
  collection,
  doc,
  setDoc,
  getDoc,
  getDocs,
  query,
  where,
  updateDoc,
  writeBatch,
} from "firebase/firestore";

// Emulator-only project ID. This is never a live Firebase project.
const projectId = "demo-alapot-local";

const testEnv = await initializeTestEnvironment({
  projectId,
  firestore: {
    host: "127.0.0.1",
    port: 8080,
    rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
  },
});

after(async () => testEnv.cleanup());
await testEnv.clearFirestore();

const now = "2026-11-17T08:00:00.000Z";

await testEnv.withSecurityRulesDisabled(async (context) => {
  const db = context.firestore();

  await setDoc(doc(db, "users", "admin-test"), { role: "admin", active: true });
  await setDoc(doc(db, "users", "dentist-test"), {
    role: "dentist", active: true, dentistId: "DEN-001",
  });
  await setDoc(doc(db, "dentists", "DEN-001"), {
    auth_uid: "dentist-test", status: "Active", active: true,
  });
  await setDoc(doc(db, "paymentMethods", "cash-method"), {
    name: "Cash", status: "Active",
  });

  await setDoc(doc(db, "users", "patient-owner"), {
    role: "patient", active: true, patient_id: "PT-OWN00001",
    patient_doc_id: "PT-OWN00001", name: "Patient Owner", email: "owner@example.com",
  });
  await setDoc(doc(db, "patients", "PT-OWN00001"), {
    id: "PT-OWN00001", auth_uid: "patient-owner", name: "Patient Owner",
    email: "owner@example.com", status: "Active", blood_type: "O",
    allergies: "None", assigned_dentist_uids: ["dentist-test"],
    dob: "2000-01-01", identity_verified: true,
  });

  await setDoc(doc(db, "users", "patient-other"), {
    role: "patient", active: true, patient_id: "PT-OTHER001",
    patient_doc_id: "PT-OTHER001", name: "Other Patient", email: "other@example.com",
  });
  await setDoc(doc(db, "patients", "PT-OTHER001"), {
    id: "PT-OTHER001", auth_uid: "patient-other", name: "Other Patient",
    email: "other@example.com", status: "Active", dob: "2000-01-01",
  });

  // Admin-issued, identity-verified walk-in patient. No account is linked yet.
  await setDoc(doc(db, "patients", "PT-LINK0001"), {
    id: "PT-LINK0001", name: "Existing Clinic Patient", status: "Active",
    dob: "1998-02-03", source: "walk-in", identity_verified: true,
    account_status: "no-app-account", phone: "+63 917 123 4567",
  });

  // Record whose Patient ID exists but has not been verified/issued by Admin.
  await setDoc(doc(db, "patients", "PT-UNVER001"), {
    id: "PT-UNVER001", name: "Unverified Clinic Record", status: "Active",
    dob: "1998-02-03", source: "walk-in", identity_verified: false,
    account_status: "no-app-account",
  });
});

function linkRequest(uid, email, patientId = "PT-LINK0001") {
  return {
    patient_id: patientId,
    requester_uid: uid,
    requester_email: email,
    requester_name: "Existing Clinic Patient",
    phone: "+63 917 123 4567",
    email_verified: true,
    verification_method: "firebase-email-link",
    status: "Pending",
    email_verified_at: now,
    account_created_at: now,
    createdAt: now,
  };
}

function patientAccount(uid, email, patientId, name) {
  return {
    role: "patient", active: true, patient_id: patientId,
    patient_doc_id: patientId, name, email, createdAt: now, updatedAt: now,
  };
}

test("Patients cannot create their own clinic Patient ID or user mapping", async () => {
  const uid = "self-register-test";
  const email = "self-register@example.com";
  const db = testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, "users", uid), patientAccount(uid, email, "PT-SELF0001", "Self Register"));
  batch.set(doc(db, "patients", "PT-SELF0001"), {
    id: "PT-SELF0001", auth_uid: uid, name: "Self Register", email,
  });
  await assertFails(batch.commit());
  await assertFails(setDoc(doc(db, "patients", "PT-SELF0002"), {
    id: "PT-SELF0002", name: "Self Register", identity_verified: true,
  }));
});

test("A verified applicant can submit a request for an existing unlinked Patient ID for Admin review", async () => {
  const uid = "link-requester";
  const email = "existing@example.com";
  const db = testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
  await assertSucceeds(setDoc(doc(db, "patientAccountLinkRequests", uid), linkRequest(uid, email)));
  await assertSucceeds(getDoc(doc(db, "patientAccountLinkRequests", uid)));
  await assertFails(getDoc(doc(db, "patients", "PT-LINK0001")));
  await assertFails(updateDoc(doc(db, "patientAccountLinkRequests", uid), { status: "Approved" }));
});

test("Unverified email cannot submit an existing-patient link request", async () => {
  const uid = "unverified-link";
  const email = "unverified@example.com";
  const db = testEnv.authenticatedContext(uid, { email, email_verified: false }).firestore();
  await assertFails(setDoc(doc(db, "patientAccountLinkRequests", uid), linkRequest(uid, email)));
});

test("An existing Patient ID can be submitted for Admin identity verification during approval", async () => {
  const uid = "not-issued-link";
  const email = "not-issued@example.com";
  const db = testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
  await assertSucceeds(setDoc(doc(db, "patientAccountLinkRequests", uid), linkRequest(uid, email, "PT-UNVER001")));
});

test("Applicant cannot submit a request for a nonexistent Patient ID", async () => {
  const uid = "missing-patient-link";
  const email = "missing@example.com";
  const db = testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
  await assertFails(setDoc(doc(db, "patientAccountLinkRequests", uid), linkRequest(uid, email, "PT-NOTFOUND1")));
});

test("Cancelled applicant may resubmit a corrected request, but cannot approve it", async () => {
  const uid = "reapply-link";
  const email = "reapply@example.com";
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "patientAccountLinkRequests", uid), {
      ...linkRequest(uid, email), status: "Cancelled", reviewedAt: now,
    });
  });
  const db = testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
  await assertSucceeds(updateDoc(doc(db, "patientAccountLinkRequests", uid), {
    requester_name: "Existing Clinic Patient Updated",
    phone: "+63 917 123 4567", email_verified: true,
    verification_method: "firebase-email-link", email_verified_at: now,
    account_created_at: now, status: "Pending", updatedAt: new Date(),
  }));
  await assertFails(updateDoc(doc(db, "patientAccountLinkRequests", uid), { status: "Approved" }));
});

test("Admin can atomically link the original patient document to the Auth UID", async () => {
  const uid = "admin-approved-link";
  const email = "approved@example.com";
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "patientAccountLinkRequests", uid), linkRequest(uid, email));
  });
  const db = testEnv.authenticatedContext("admin-test").firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, "users", uid), patientAccount(uid, email, "PT-LINK0001", "Existing Clinic Patient"));
  batch.update(doc(db, "patients", "PT-LINK0001"), {
    auth_uid: uid, email, account_status: "linked", updatedAt: now,
  });
  batch.update(doc(db, "patientAccountLinkRequests", uid), {
    status: "Approved", reviewedAt: now, reviewNote: "Identity checked in clinic.",
  });
  await assertSucceeds(batch.commit());
  const patientDb = testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
  await assertSucceeds(getDoc(doc(patientDb, "patients", "PT-LINK0001")));
  await assertFails(getDoc(doc(patientDb, "patients", "PT-OTHER001")));
});

test("Patient can read only their own clinic record and update contact fields only", async () => {
  const db = testEnv.authenticatedContext("patient-owner", { email: "owner@example.com" }).firestore();
  await assertSucceeds(getDoc(doc(db, "patients", "PT-OWN00001")));
  await assertFails(getDoc(doc(db, "patients", "PT-OTHER001")));
  await assertSucceeds(updateDoc(doc(db, "patients", "PT-OWN00001"), {
    phone: "+63 918 111 2222", updatedAt: now,
  }));
  await assertFails(updateDoc(doc(db, "patients", "PT-OWN00001"), { blood_type: "AB" }));
  await assertFails(updateDoc(doc(db, "patients", "PT-OWN00001"), { auth_uid: "another-account" }));
});

test("Dentist can read an assigned patient but not an unassigned patient", async () => {
  const db = testEnv.authenticatedContext("dentist-test").firestore();
  await assertSucceeds(getDoc(doc(db, "patients", "PT-OWN00001")));
  await assertFails(getDoc(doc(db, "patients", "PT-OTHER001")));
});

test("Admin can read all clinic patient records", async () => {
  const db = testEnv.authenticatedContext("admin-test").firestore();
  await assertSucceeds(getDoc(doc(db, "patients", "PT-OWN00001")));
  await assertSucceeds(getDoc(doc(db, "patients", "PT-OTHER001")));
});

test("Patient cannot read another account's link request", async () => {
  const db = testEnv.authenticatedContext("patient-owner", { email: "owner@example.com" }).firestore();
  await assertFails(getDoc(doc(db, "patientAccountLinkRequests", "link-requester")));
});

test("Appointment creation requires clinic patient identity, an active dentist and active payment method", async () => {
  const db = testEnv.authenticatedContext("patient-owner", { email: "owner@example.com", email_verified: true }).firestore();
  const appointment = (id, overrides = {}) => ({
    id,
    patient_id: "PT-OWN00001", patient_uid: "patient-owner", patient_doc_id: "PT-OWN00001",
    patient: "Patient Owner", patient_name: "Patient Owner",
    patient_snapshot: { name: "Patient Owner", phone: "+63 917 000 0000", email: "owner@example.com" },
    dentist_id: "dentist-test", dentist: "Test Dentist",
    service_id: "SRV-001", service_ids: ["SRV-001"], service: "Consultation",
    date: "2026-11-20", time: "9:00 AM", time_24h: "09:00", duration: 30,
    status: "Pending", payment_method: "Cash", payment_method_id: "cash-method",
    payment_status: "Unpaid", payment_provider: "Manual", notes: "", amount: 450,
    source: "patient-app", booking_source: "patient-app", createdAt: now, updatedAt: now,
    ...overrides,
  });
  await assertSucceeds(setDoc(doc(db, "appointments", "APT-VALID-001"), appointment("APT-VALID-001")));
  await assertFails(setDoc(doc(db, "appointments", "APT-BAD-ID"), appointment("APT-BAD-ID", { patient_doc_id: "patient-owner" })));
  await assertFails(setDoc(doc(db, "appointments", "APT-BAD-OWNER"), appointment("APT-BAD-OWNER", { patient_uid: "patient-other" })));
  await assertFails(setDoc(doc(db, "appointments", "APT-BAD-PAYMENT"), appointment("APT-BAD-PAYMENT", { payment_method_id: "inactive-method" })));
  await assertFails(setDoc(doc(db, "appointments", "APT-PAID"), appointment("APT-PAID", { payment_status: "Paid" })));
  await assertFails(setDoc(doc(db, "appointments", "APT-ADMIN-FIELDS"), appointment("APT-ADMIN-FIELDS", { admin_approved: true })));
});


test("Patient appointment history must filter by both Firebase UID and permanent PT-ID", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "appointments", "APT-OWNER-READ"), {
      id: "APT-OWNER-READ", patient_uid: "patient-owner",
      patient_id: "PT-OWN00001", dentist_id: "dentist-test", status: "Pending",
    });
    await setDoc(doc(db, "appointments", "APT-OTHER-READ"), {
      id: "APT-OTHER-READ", patient_uid: "patient-other",
      patient_id: "PT-OTHER001", dentist_id: "dentist-test", status: "Pending",
    });
  });

  const db = testEnv.authenticatedContext("patient-owner", {
    email: "owner@example.com", email_verified: true,
  }).firestore();
  const ownQuery = query(
    collection(db, "appointments"),
    where("patient_id", "==", "PT-OWN00001"),
    where("patient_uid", "==", "patient-owner"),
  );
  const ownResults = await assertSucceeds(getDocs(ownQuery));
  if (ownResults.size !== 1 || ownResults.docs[0].id !== "APT-OWNER-READ") {
    throw new Error("Patient appointment query returned an unexpected result.");
  }

  const incompleteQuery = query(
    collection(db, "appointments"),
    where("patient_id", "==", "PT-OWN00001"),
  );
  await assertFails(getDocs(incompleteQuery));
});

test("Assigned dentist can read a Pending appointment, but an unassigned dentist cannot", async () => {
  const ownerDb = testEnv.authenticatedContext("patient-owner", { email: "owner@example.com", email_verified: true }).firestore();
  const appointment = {
    id: "APT-PENDING-READ", patient_id: "PT-OWN00001", patient_uid: "patient-owner",
    dentist_id: "dentist-test", status: "Pending", date: "2026-11-20", time: "9:00 AM",
  };
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "appointments", "APT-PENDING-READ"), appointment);
    await setDoc(doc(context.firestore(), "users", "other-dentist"), { role: "dentist", active: true });
  });
  const assignedDb = testEnv.authenticatedContext("dentist-test").firestore();
  const unassignedDb = testEnv.authenticatedContext("other-dentist").firestore();
  await assertSucceeds(getDoc(doc(assignedDb, "appointments", "APT-PENDING-READ")));
  await assertFails(getDoc(doc(unassignedDb, "appointments", "APT-PENDING-READ")));
});
