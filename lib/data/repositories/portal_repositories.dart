import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../models/patient_review.dart';

/// Contracts only: no backend implementation is connected in Phase 1.
/// A later Firebase or API implementation can satisfy these same interfaces,
/// keeping presentation screens independent from the data provider.
abstract interface class PatientRepository {
  Future<Patient?> getPatient(String patientId);
  Future<void> updatePatient(Patient patient);
}

abstract interface class AppointmentRepository {
  Future<List<Appointment>> getPatientAppointments(String patientId);
  Future<Appointment> submitAppointment(Appointment appointment);
  Future<void> requestCancellation(String appointmentId, String patientId);
  Future<void> requestReschedule(String appointmentId, String patientId, DateTime requestedTime);
}

abstract interface class PatientReviewRepository {
  Future<List<PatientReview>> getPatientReviews(String patientId);
  Future<PatientReview> submitReview(PatientReview review);
  Future<void> updateReview(PatientReview review);
}
