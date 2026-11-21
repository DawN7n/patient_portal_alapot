class Dentist {
  const Dentist({required this.id, required this.name, required this.initials, required this.specialization, required this.experience, required this.education, required this.workingDays, required this.startTime, required this.endTime, this.rating = 0, this.reviewCount = 0, this.photoAsset});
  final String id, name, initials, specialization, experience, education, startTime, endTime;
  final List<String> workingDays;
  final double rating;
  final int reviewCount;
  final String? photoAsset;
}

class DentalService {
  const DentalService({required this.id, required this.name, required this.category, required this.description, required this.price, required this.durationMinutes});
  final String id, name, category, description;
  final double price;
  final int durationMinutes;
}

class ClinicAnnouncement {
  const ClinicAnnouncement({required this.id, required this.title, required this.category, required this.date, required this.content});
  final String id, title, category, date, content;
}
