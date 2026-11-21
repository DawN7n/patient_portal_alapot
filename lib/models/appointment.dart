enum AppointmentStatus {
  pending,
  confirmed,
  rescheduled,
  completed,
  cancelled,
  noShow,
}

/// Appointment fields use the shared Admin/Dentist/Patient portal contract.
class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.dentistId,
    required this.serviceId,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.patientNotes,
    this.patientName,
    this.dentistName,
    this.serviceName,
    this.consultationNote,
    this.diagnosis,
    this.treatmentPlan,
    this.paymentStatus,
    this.amount,
  });

  final String id;
  final String patientId;
  final String dentistId;
  final String serviceId;
  final DateTime scheduledAt;
  final int durationMinutes;
  final AppointmentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? patientNotes;
  final String? patientName;
  final String? dentistName;
  final String? serviceName;
  final String? consultationNote;
  final String? diagnosis;
  final String? treatmentPlan;
  final String? paymentStatus;
  final num? amount;

  Map<String, dynamic> toSharedMap() => {
    'id': id,
    'patient_id': patientId,
    'patient': patientName,
    'dentist_id': dentistId,
    'dentist': dentistName,
    'service_id': serviceId,
    'service': serviceName,
    'date': _date(scheduledAt),
    'time': '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}',
    'duration': durationMinutes,
    'status': _statusValue(status),
    'notes': patientNotes,
    'consultationNote': consultationNote,
    'diagnosis': diagnosis,
    'treatmentPlan': treatmentPlan,
    'paymentStatus': paymentStatus,
    'amount': amount,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _statusValue(AppointmentStatus value) => switch (value) {
    AppointmentStatus.pending => 'Pending',
    AppointmentStatus.confirmed => 'Confirmed',
    AppointmentStatus.rescheduled => 'Rescheduled',
    AppointmentStatus.completed => 'Completed',
    AppointmentStatus.cancelled => 'Cancelled',
    AppointmentStatus.noShow => 'No-show',
  };
}
