/// Patient identity fields use the same names as the Admin and Dentist
/// portals' shared `patients/{patientId}` Firestore document.
class Patient {
  const Patient({
    required this.id,
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.phoneNumber,
    this.email,
    this.initials,
    this.age,
    this.registeredAt,
    this.status,
    this.lastVisit,
    this.bloodType,
    this.allergies,
    this.medicalNotes,
  });

  /// Stable patient document ID / patientId shared by all three portals.
  final String id;
  final String fullName;
  final DateTime dateOfBirth;
  final String gender;
  final String address;
  final String phoneNumber;
  final String? email;
  final String? initials;
  final int? age;
  final DateTime? registeredAt;
  final String? status;
  final DateTime? lastVisit;
  final String? bloodType;
  final String? allergies;
  final String? medicalNotes;

  Map<String, dynamic> toSharedMap() => {
    'id': id,
    'name': fullName,
    'initials': initials,
    'dob': _date(dateOfBirth),
    'age': age,
    'gender': gender,
    'phone': phoneNumber,
    'email': email,
    'address': address,
    'registered': registeredAt == null ? null : _date(registeredAt!),
    'status': status,
    'last_visit': lastVisit == null ? null : _date(lastVisit!),
    'blood_type': bloodType,
    'allergies': allergies,
    'medical_notes': medicalNotes,
  };

  factory Patient.fromSharedMap(Map<String, dynamic> data, {required String documentId}) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? fallback;
    }
    final dob = parseDate(data['dob'], DateTime(2000));
    return Patient(
      id: documentId,
      fullName: (data['name'] ?? '').toString(),
      dateOfBirth: dob,
      gender: (data['gender'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      phoneNumber: (data['phone'] ?? '').toString(),
      email: data['email']?.toString(),
      initials: data['initials']?.toString(),
      age: int.tryParse(data['age']?.toString() ?? ''),
      registeredAt: data['registered'] == null ? null : parseDate(data['registered'], dob),
      status: data['status']?.toString(),
      lastVisit: data['last_visit'] == null ? null : parseDate(data['last_visit'], dob),
      bloodType: data['blood_type']?.toString(),
      allergies: data['allergies']?.toString(),
      medicalNotes: data['medical_notes']?.toString(),
    );
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
