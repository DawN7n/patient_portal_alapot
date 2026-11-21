/// Shared record contracts for the Patient, Dentist, and Admin portals.
/// These are interfaces only; no Firebase connection is enabled in this phase.
library;

abstract interface class PatientPortalRepository {
  Future<Map<String, dynamic>?> getPatient(String patientId);
  Future<void> updatePatient(String patientId, Map<String, dynamic> changes);
}

abstract interface class DentistPortalRepository {
  Future<List<Map<String, dynamic>>> getActiveDentists();
  Future<Map<String, dynamic>?> getDentist(String dentistId);
}

abstract interface class ServicePortalRepository {
  Future<List<Map<String, dynamic>>> getPublishedServices();
}

abstract interface class AppointmentPortalRepository {
  Future<List<Map<String, dynamic>>> getPatientAppointments(String patientId);
  Future<void> submitAppointment(Map<String, dynamic> appointment);
  Future<void> requestCancellation(String appointmentId, String patientId);
  Future<void> requestReschedule(String appointmentId, String patientId, DateTime requestedAt);
}

abstract interface class PatientReviewPortalRepository {
  Future<List<Map<String, dynamic>>> getPatientReviews(String patientId);
  Future<void> submitReview(Map<String, dynamic> review);
}

abstract interface class DentalRecordPortalRepository {
  /// Reads `dentalCharts/{patientId}`.
  Future<Map<String, dynamic>?> getDentalChart(String patientId);

  /// Reads the patient's consultation / tooth history records.
  Future<List<Map<String, dynamic>>> getDentalHistory(String patientId);

  /// Reads `patientFiles/{patientId}/files`.
  Future<List<Map<String, dynamic>>> getPatientFiles(String patientId);
}

abstract interface class PaymentPortalRepository {
  /// Reads payment transactions and official receipts for this patient.
  Future<List<Map<String, dynamic>>> getPatientPayments(String patientId);
  Future<List<Map<String, dynamic>>> getPatientReceipts(String patientId);
}

abstract interface class ClinicPortalRepository {
  Future<Map<String, dynamic>?> getClinicProfile();
  Future<List<Map<String, dynamic>>> getPublishedAnnouncements();
  Future<List<Map<String, dynamic>>> getPublishedServices();
}

abstract interface class PatientSupportPortalRepository {
  Future<String> createSupportTicket(Map<String, dynamic> ticket);
  Future<List<Map<String, dynamic>>> getPatientSupportTickets(String patientId);
  Future<List<Map<String, dynamic>>> getTicketMessages(String ticketId, String patientId);
  Future<void> sendTicketMessage(String ticketId, String patientId, String message);
}

abstract interface class PatientAssistantPortalRepository {
  /// Sends a patient question to the secured assistant service. The backend
  /// must derive patient identity from the authenticated session, not trust a
  /// patientId supplied by the client.
  Future<String> askAssistant(String message);
}
