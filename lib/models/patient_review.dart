enum ReviewModerationStatus { pending, approved, rejected }

class PatientReview {
  const PatientReview({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.dentistId,
    required this.rating,
    required this.comment,
    required this.moderationStatus,
    required this.createdAt,
    this.updatedAt,
  });

  /// One review per completed appointment. Admin moderation controls public display.
  final String id;
  final String appointmentId;
  final String patientId;
  final String dentistId;
  final int rating;
  final String comment;
  final ReviewModerationStatus moderationStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
}
